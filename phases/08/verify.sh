#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; phase_dir="$repo_root/phases/08"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"; source "$repo_root/lib/harness/terraform.sh"
mode=offline; run_id=""
while [[ "$#" -gt 0 ]]; do case "$1" in --offline) mode=offline;shift;; --run) [[ "$mode" == destroyed ]] || mode=cloud;run_id="${2:-}";shift 2;; --destroyed) mode=destroyed;shift;; *) exit 2;; esac; done
if [[ "$mode" == offline ]]; then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh"; terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-08-cloud-storage.md" >/dev/null
  ! rg -n 'CSEK_[12]=|encryption_key:[[:space:]]+[A-Za-z0-9+/=]{20,}' "$phase_dir" || harness_die "CSEK 값이 코드에 있습니다."
  printf 'PASS: Phase 08 offline 계약 검증 완료\n'; exit 0
fi
harness_validate_run_id "$run_id"; harness_load_config "$repo_root/config/harness.env"; bucket="gcp-lab-p08-$run_id"
if [[ "$mode" == destroyed ]]; then
  ! gcloud storage buckets describe "gs://$bucket" >/dev/null 2>&1 || harness_die "Phase 08 bucket 잔여"
  printf 'PASS: Phase 08 잔여 리소스 0\n'; exit 0
fi
run_dir="$repo_root/artifacts/runs/$run_id/phase-08"; manifest="$run_dir/manifest.json"; evidence_dir="$run_dir/evidence"; evidence="$evidence_dir/phase-08-machine.json"
harness_manifest_require_status "$manifest" applied; mkdir -p "$evidence_dir" "$run_dir/secrets" "$run_dir/fixture/firstlevel/secondlevel"; chmod 700 "$evidence_dir" "$run_dir/secrets"
printf 'phase-08-original\n' >"$run_dir/fixture/setup.html"; cp "$run_dir/fixture/setup.html" "$run_dir/fixture/setup2.html"; cp "$run_dir/fixture/setup.html" "$run_dir/fixture/setup3.html"
cp "$run_dir/fixture/setup.html" "$run_dir/fixture/firstlevel/setup.html"; cp "$run_dir/fixture/setup.html" "$run_dir/fixture/firstlevel/secondlevel/setup.html"
fixture_hash="$(sha256sum "$run_dir/fixture/setup.html"|awk '{print $1}')"
gcloud storage cp "$run_dir/fixture/setup.html" "gs://$bucket/setup.html" >/dev/null
gcloud storage objects update "gs://$bucket/setup.html" --predefined-acl=private >/dev/null
if curl --fail --silent --max-time 10 "https://storage.googleapis.com/$bucket/setup.html" >/dev/null; then harness_die "private ACL 객체가 익명 다운로드됐습니다."; fi
public_acl="policy-prevented"
public_acl_active=false
cleanup_public_acl(){
  [[ "$public_acl_active" == true ]] || return 0
  gcloud storage objects update "gs://$bucket/setup.html" --remove-acl-grant=entity=allUsers >/dev/null 2>&1 || true
}
trap cleanup_public_acl EXIT
if gcloud storage objects update "gs://$bucket/setup.html" --add-acl-grant=entity=allUsers,role=READER >"$run_dir/public-acl.log" 2>&1; then
  public_acl_active=true
  curl --fail --silent --max-time 20 "https://storage.googleapis.com/$bucket/setup.html" >/dev/null || harness_die "public ACL 익명 GET 실패"
  gcloud storage objects update "gs://$bucket/setup.html" --remove-acl-grant=entity=allUsers >/dev/null
  public_acl_active=false
  public_acl="created-tested-revoked"
else
  rg -qi '412|public access prevention|organization policy|not supported' "$run_dir/public-acl.log" || harness_die "public ACL 실패가 예상 정책 거부가 아닙니다."
fi
trap - EXIT

key1="$(openssl rand -base64 32 | tr -d '\n')"; key2="$(openssl rand -base64 32 | tr -d '\n')"
key_file="$run_dir/secrets/csek-keys.yaml"; config_name="harness-p08-$run_id"; active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)'|head -n1)"
printf 'encryption_key: %s\ndecryption_keys: []\n' "$key1" >"$key_file"; chmod 600 "$key_file"
gcloud config configurations create "$config_name" --no-activate >/dev/null
gcloud config set account "$active_account" --configuration="$config_name" >/dev/null
gcloud config set project "$GCP_PROJECT_ID" --configuration="$config_name" >/dev/null
gcloud config set storage/key_store_path "$key_file" --configuration="$config_name" >/dev/null
cleanup_config(){ gcloud config configurations delete "$config_name" --quiet >/dev/null 2>&1 || true; rm -f "$key_file"; }
trap cleanup_config EXIT
for file in setup2.html setup3.html; do gcloud --configuration="$config_name" storage cp "$run_dir/fixture/$file" "gs://$bucket/$file" >/dev/null; done
printf 'encryption_key: %s\ndecryption_keys:\n- %s\n' "$key2" "$key1" >"$key_file"
gcloud --configuration="$config_name" storage objects update "gs://$bucket/setup2.html" >/dev/null
printf 'encryption_key: %s\ndecryption_keys: []\n' "$key2" >"$key_file"
gcloud --configuration="$config_name" storage cp "gs://$bucket/setup2.html" "$run_dir/fixture/recover2.html" >/dev/null
if gcloud --configuration="$config_name" storage cp "gs://$bucket/setup3.html" "$run_dir/fixture/recover3-denied.html" >"$run_dir/csek-denial.log" 2>&1; then harness_die "구키 제거 후 setup3 복호화가 성공했습니다."; fi
printf 'encryption_key: %s\ndecryption_keys:\n- %s\n' "$key2" "$key1" >"$key_file"
gcloud --configuration="$config_name" storage objects update "gs://$bucket/setup3.html" >/dev/null
gcloud --configuration="$config_name" storage cp "gs://$bucket/setup3.html" "$run_dir/fixture/recover3.html" >/dev/null
[[ "$(sha256sum "$run_dir/fixture/recover2.html"|awk '{print $1}')" == "$fixture_hash" && "$(sha256sum "$run_dir/fixture/recover3.html"|awk '{print $1}')" == "$fixture_hash" ]] || harness_die "CSEK rotation hash 불일치"
cleanup_config; trap - EXIT

original_generation="$(gcloud storage objects describe "gs://$bucket/setup.html" --format='value(generation)')"
printf 'phase-08-v2\n' >"$run_dir/fixture/setup.html"; gcloud storage cp "$run_dir/fixture/setup.html" "gs://$bucket/setup.html" >/dev/null
printf 'phase-08-v3\n' >"$run_dir/fixture/setup.html"; gcloud storage cp "$run_dir/fixture/setup.html" "gs://$bucket/setup.html" >/dev/null
gcloud storage cp "gs://$bucket/setup.html#$original_generation" "$run_dir/fixture/recovered-original.html" >/dev/null
[[ "$(sha256sum "$run_dir/fixture/recovered-original.html"|awk '{print $1}')" == "$fixture_hash" ]] || harness_die "저장 generation 복구 hash 불일치"
gcloud storage rsync "$run_dir/fixture/firstlevel" "gs://$bucket/firstlevel" --recursive >/dev/null
object_set="$(gcloud storage ls -r "gs://$bucket/firstlevel/**" | sed "s#gs://$bucket/##" | sed '/\/$/d' | sort)"
[[ "$object_set" == $'firstlevel/secondlevel/setup.html\nfirstlevel/setup.html' ]] || harness_die "recursive sync object set 불일치"
bucket_json="$(gcloud storage buckets describe "gs://$bucket" --format=json)"
jq -e '.versioning.enabled == true and (.lifecycle.rule | any(.action.type=="Delete" and .condition.age==31))' <<<"$bucket_json" >/dev/null || harness_die "lifecycle/versioning 불일치"
jq -n --arg phase 08 --arg run_id "$run_id" --arg public_acl "$public_acl" --arg fixture_hash "$fixture_hash" '{phase:$phase,run_id:$run_id,tasks:{
  "task-1":{status:"passed",detail:"checksum 고정 fixture와 run 전용 bucket 준비"},
  "task-2":{status:"passed",detail:("private ACL과 public ACL 조건부 경계 검증: "+$public_acl)},
  "task-3":{status:"passed",detail:"원문 비노출 CSEK 암호화·복호화 hash 확인"},
  "task-4":{status:"passed",detail:"setup2 신키 성공·setup3 구키 부재 실패 후 전체 rotation"},
  "task-5":{status:"passed",detail:"31일 Delete lifecycle API readback"},
  "task-6":{status:"passed",detail:"3세대 생성과 저장 generation 원본 hash 복구"},
  "task-7":{status:"passed",detail:"중첩 tree recursive sync object set 일치"},
  "task-8":{status:"passed",detail:"ACL·CSEK·lifecycle·versioning·sync 검토"}},fixture_sha256:$fixture_hash,risks:[]}' >"$evidence"
chmod 600 "$evidence" "$run_dir/public-acl.log" "$run_dir/csek-denial.log"
printf 'PASS: Phase 08 Storage ACL·CSEK·lifecycle·versioning·sync 검증 완료\n'
