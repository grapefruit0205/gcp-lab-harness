#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."&&pwd)";phase_dir="$repo_root/phases/10";export HARNESS_REPO_ROOT="$repo_root";source "$repo_root/lib/harness/config.sh";source "$repo_root/lib/harness/terraform.sh"
mode=offline;run_id="";while [[ "$#" -gt 0 ]];do case "$1" in --offline)mode=offline;shift;;--run)[[ "$mode" == destroyed ]]||mode=cloud;run_id="${2:-}";shift 2;;--destroyed)mode=destroyed;shift;;*)exit 2;;esac;done
if [[ "$mode" == offline ]];then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh";terraform -chdir="$phase_dir/terraform" fmt -check>/dev/null
  [[ "$(find "$phase_dir/sql" -type f -name '*.sql'|wc -l)" -eq 8 ]]||harness_die "원본 SQL 8개가 필요합니다."
  for sql in "$phase_dir"/sql/*.sql;do rg -q '__TABLE__' "$sql"||harness_die "table placeholder 누락: $sql";done
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-10-bigquery-billing.md">/dev/null
  printf 'PASS: Phase 10 offline 계약 검증 완료\n';exit 0
fi
harness_validate_run_id "$run_id";harness_load_config "$repo_root/config/harness.env";dataset="billing_${run_id//-/_}";table="$GCP_PROJECT_ID.$dataset.sampleinfotable"
if [[ "$mode" == destroyed ]];then ! bq show --format=prettyjson "$GCP_PROJECT_ID:$dataset">/dev/null 2>&1||harness_die "Phase 10 dataset 잔여";printf 'PASS: Phase 10 잔여 리소스 0\n';exit 0;fi
run_dir="$repo_root/artifacts/runs/$run_id/phase-10";manifest="$run_dir/manifest.json";evidence_dir="$run_dir/evidence";evidence="$evidence_dir/phase-10-machine.json";harness_manifest_require_status "$manifest" applied;mkdir -p "$evidence_dir" "$run_dir/query-results";chmod 700 "$evidence_dir" "$run_dir/query-results"
target="$(jq -r '.actions[]|select(.id=="fixture-load")|.target' "$run_dir/action-plan.json")";uri="${target%%#*}";expected_generation="${target#*#}";expected_generation="${expected_generation%% *}";expected_crc="${target##*crc32c=}"
metadata="$(gcloud storage objects describe "$uri" --format=json)";actual_crc="$(jq -r '.crc32c_hash // .crc32c // .metadata.crc32c // empty'<<<"$metadata")";[[ "$(jq -r .generation<<<"$metadata")" == "$expected_generation" && -n "$actual_crc" && "$actual_crc" == "$expected_crc" ]]||harness_die "승인 후 fixture generation/checksum 변경"
timeout 900 bq --location=US load --replace --source_format=AVRO "$table" "$uri" >/dev/null
table_json="$(bq show --format=prettyjson "$table")";[[ "$(jq -r .numRows<<<"$table_json")" == 415602 ]]||harness_die "원본 billing fixture 행 수 415602 불일치"
query_summary='[]';max_bytes=1073741824;index=0
for sql_file in "$phase_dir"/sql/*.sql;do
  ((index+=1));query_file="$run_dir/query-$index.sql";sed "s#__TABLE__#$table#g" "$sql_file">"$query_file"
  dry_json="$(bq query --use_legacy_sql=false --dry_run --format=prettyjson "$(<"$query_file")")";bytes="$(jq -r '.statistics.query.totalBytesProcessed // .totalBytesProcessed // empty'<<<"$dry_json")";[[ "$bytes" =~ ^[0-9]+$ && "$bytes" -gt 0 && "$bytes" -le "$max_bytes" ]]||harness_die "query $index dry-run bytes 누락 또는 상한 초과"
  result="$run_dir/query-results/$index.json";timeout 300 bq query --use_legacy_sql=false --maximum_bytes_billed="$max_bytes" --format=prettyjson --max_rows=100 "$(<"$query_file")">"$result"
  result_hash="$(jq -S . "$result"|sha256sum|awk '{print $1}')";rows="$(jq 'length' "$result")"
  safe_top="";if (( index>=5 ));then safe_top="$(jq -r '.[0] | to_entries[0].value // ""' "$result")";fi
  query_summary="$(jq --arg id "query-$index" --arg sha "$result_hash" --argjson bytes "$bytes" --argjson rows "$rows" --arg top "$safe_top" '.+[{id:$id,processed_bytes:$bytes,result_rows_captured:$rows,result_sha256:$sha,safe_top_value:$top}]'<<<"$query_summary")"
done
rm -f "$run_dir"/query-*.sql;rm -rf "$run_dir/query-results"
jq -n --arg phase 10 --arg run_id "$run_id" --arg fixture_generation_hash "$(printf %s "$expected_generation"|sha256sum|awk '{print $1}')" --argjson queries "$query_summary" '{phase:$phase,run_id:$run_id,tasks:{
 "task-1":{status:"passed",detail:"승인 generation/CRC32C AVRO load와 415602행 확인"},
 "task-2":{status:"passed",detail:"schema와 numRows 구조화 조회"},
 "task-3":{status:"passed",detail:"Cost>0 단순 query dry-run·실행"},
 "task-4":{status:"passed",detail:"원본 대규모 분석 SQL 7개를 각각 byte 제한으로 실행"},
 "task-5":{status:"passed",detail:"8개 query 결과 hash·처리 bytes·안전한 top value 검토"}},fixture_generation_sha256:$fixture_generation_hash,queries:$queries,risks:[]}' >"$evidence";chmod 600 "$evidence"
printf 'PASS: Phase 10 AVRO 415602행과 원본 SQL 8개 검증 완료\n'
