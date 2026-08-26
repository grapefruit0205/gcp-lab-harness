#!/usr/bin/env python3
"""BigQuery 원본 SQL의 구조화 dry-run, 실제 job/총행수/결과 의미 검사."""
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import urllib.parse
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib/harness"))
from advanced import API, write_json

MAX_BYTES = 1073741824
REQUIRED_SCHEMA = {"billing_account_id": "STRING", "project": "RECORD", "service": "RECORD",
                   "sku": "RECORD", "location": "RECORD", "cost": "FLOAT", "currency": "STRING",
                   "usage": "RECORD", "usage_end_time": "TIMESTAMP"}


def check_table(table):
    if int(table.get("numRows", -1)) != 415602:
        raise ValueError("원문 fixture 415602행 불일치")
    fields = {f["name"]: f["type"] for f in table.get("schema", {}).get("fields", [])}
    mismatches = [f"{name}: expected={expected}, actual={fields.get(name, 'missing')}"
                  for name, expected in REQUIRED_SCHEMA.items() if fields.get(name) != expected]
    if mismatches:
        raise ValueError("필수 schema/type 불일치: " + "; ".join(mismatches))


def check_result(index, data):
    if data.get("jobComplete") is not True or data.get("errors"):
        raise ValueError("query 미완료/오류")
    total = int(data.get("totalRows", -1))
    if total <= 0 or (index == 2 and total != 415602) or (index == 3 and total != 100):
        raise ValueError("query 전체 결과 행 수 불일치")
    rows = data.get("rows", [])
    fields = [f["name"] for f in data.get("schema", {}).get("fields", [])]
    decoded = [{k: v["v"] for k, v in zip(fields, row["f"])} for row in rows]
    if not decoded:
        raise ValueError("query sample 없음")
    if index in (1, 3, 4) and not all(float(r.get("cost", "nan")) > (10 if index == 4 else 0) for r in decoded):
        raise ValueError("cost 필터 결과 불일치")
    if index >= 5:
        values = [float(r["total_cost" if index == 8 else "billing_records"]) for r in decoded]
        if values != sorted(values, reverse=True):
            raise ValueError("집계 내림차순 불일치")
    return {"id": f"query-{index}", "total_rows": total, "sample_rows": len(rows),
            "result_sha256": hashlib.sha256(json.dumps(rows, sort_keys=True).encode()).hexdigest()}


def wait_job(api, base, job):
    end = time.monotonic() + 900
    while time.monotonic() < end:
        data = api.request("GET", f"{base}/jobs/{job}?location=US")
        if data.get("status", {}).get("state") == "DONE":
            if data["status"].get("errorResult") or data["status"].get("errors"):
                raise ValueError(f"BigQuery job 실패: {job}; 콘솔 작업 기록 확인")
            return data
        time.sleep(5)
    raise ValueError(f"BigQuery job timeout: {job}; 작업·리소스 보존")


def run(run_dir, project):
    run_id = run_dir.parent.name
    api = API()
    base = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project}"
    dataset = "billing_" + run_id.replace("-", "_")
    table_id = f"{project}.{dataset}.sampleinfotable"
    actions = json.loads((run_dir / "action-plan.json").read_text())["actions"]
    target = next(a["target"] for a in actions if a["id"] == "fixture-load")
    uri, pin = target.split("#", 1)
    generation, crc = pin.split(" crc32c=", 1)
    bucket, name = uri.removeprefix("gs://").split("/", 1)
    metadata_url = f"https://storage.googleapis.com/storage/v1/b/{bucket}/o/{urllib.parse.quote(name, safe='')}"
    def fixture_unchanged():
        current = api.request("GET", metadata_url)
        if str(current.get("generation")) != generation or current.get("crc32c") != crc:
            raise ValueError("승인 fixture generation/CRC32C 변경; 새 plan 필요")
    fixture_unchanged()
    attempt = uuid.uuid4().hex[:12]
    receipt = {"phase": "10", "run_id": run_id, "jobs": []}
    receipt_path = run_dir / "evidence" / f"billing-jobs-{attempt}.json"
    def submit(config, suffix):
        job = f"p10_{run_id.replace('-', '_')}_{attempt}_{suffix}"
        receipt["jobs"].append({"job_id": job, "stage": suffix, "status": "submitted"})
        write_json(receipt_path, receipt)
        api.request("POST", f"{base}/jobs", {"jobReference": {"projectId": project, "jobId": job, "location": "US"}, "configuration": config})
        data = wait_job(api, base, job)
        receipt["jobs"][-1]["status"] = "DONE"
        write_json(receipt_path, receipt)
        return job, data
    submit({"load": {"sourceUris": [uri], "sourceFormat": "AVRO", "useAvroLogicalTypes": True,
                      "writeDisposition": "WRITE_TRUNCATE",
                      "destinationTable": {"projectId": project, "datasetId": dataset, "tableId": "sampleinfotable"}}}, "load")
    fixture_unchanged()
    check_table(api.request("GET", f"{base}/datasets/{dataset}/tables/sampleinfotable"))
    summaries = []
    for index, sql in enumerate(sorted((Path(__file__).parent / "sql").glob("*.sql")), 1):
        query = {"query": sql.read_text().replace("__TABLE__", table_id), "useLegacySql": False,
                 "maximumBytesBilled": str(MAX_BYTES), "useQueryCache": False}
        dry = api.request("POST", f"{base}/jobs", {"jobReference": {"projectId": project, "location": "US"},
                                                    "configuration": {"dryRun": True, "query": query}})
        estimate = int(dry.get("statistics", {}).get("query", {}).get("totalBytesProcessed", -1))
        if not 0 < estimate <= MAX_BYTES or dry.get("status", {}).get("errorResult"):
            raise ValueError("dry-run bytes 누락/상한 초과/SQL 오류")
        job, result = submit({"query": query}, f"query{index}")
        billed = int(result["statistics"]["query"].get("totalBytesBilled", MAX_BYTES + 1))
        if billed > MAX_BYTES:
            raise ValueError("실제 billed bytes 상한 초과")
        summary = check_result(index, api.request("GET", f"{base}/queries/{job}?location=US&maxResults=100"))
        summary.update(job_id=job, estimated_bytes=estimate, billed_bytes=billed)
        summaries.append(summary)
    tasks = {f"task-{i}": {"status": "passed", "detail": detail} for i, detail in enumerate([
        "승인 fixture 적재 전후 일치·load DONE·415602행", "필수 schema/type·행 수 확인",
        "Cost>0 작업·전체 결과행 수·sample 의미 검사", "분석 SQL7개 작업·총행수/집계순서·1GiB 상한",
        "8개 job ID·통계·정제 hash 검토"], 1)}
    write_json(run_dir / "evidence/phase-10-machine.json", {"phase": "10", "run_id": run_id, "tasks": tasks,
               "queries": summaries, "risks": ["고정 golden 정답 전체 비교 아님; sample 의미·원문 행 수·작업 통계 검사", "실제 Billing export 미변경"]})


if __name__ == "__main__":
    try:
        run(Path(sys.argv[1]), os.environ["GCP_PROJECT_ID"])
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
