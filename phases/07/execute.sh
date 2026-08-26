#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
export HARNESS_PHASE=07
export HARNESS_PHASE_RESOURCE_LIMIT=8
export HARNESS_PHASE_ALLOWED_TYPES_JSON='["google_project_service","google_compute_network","google_compute_subnetwork","google_compute_firewall","google_service_account","google_storage_bucket","google_storage_bucket_object","google_project_iam_member"]'
export CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1

phase_preflight() {
  local creation_policy member_policy services project_policy
  python3 "$repo_root/phases/07/auth.py" --config "$repo_root/config/phase-07-users.json" --project "$GCP_PROJECT_ID" >/dev/null
  project_policy="$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" --account="$user1" --format=json)"
  jq -e --arg member "user:$user2" '[.bindings[]?.members[]? | select(.==$member)] | length==0' <<<"$project_policy" >/dev/null ||
    { printf 'FAIL: User2의 기존 프로젝트 IAM을 자동 회수하지 않습니다. 전용 실습 계정이 필요합니다.\n' >&2; return 1; }
  services="$(gcloud services list --enabled --account="$user1" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e ' [.[] | .config.name] as $enabled |
    ["compute.googleapis.com","iam.googleapis.com","storage.googleapis.com","oslogin.googleapis.com"] |
    all(. as $name | $enabled | index($name) != null)' <<<"$services" >/dev/null ||
    { printf 'FAIL: Phase 07 필수 API가 비활성입니다. 자동 enable하지 않습니다.\n' >&2; return 1; }
  creation_policy="$(gcloud resource-manager org-policies describe constraints/iam.disableServiceAccountCreation --account="$user1" --project="$GCP_PROJECT_ID" --effective --format=json)"
  member_policy="$(gcloud resource-manager org-policies describe constraints/iam.allowedPolicyMemberDomains --account="$user1" --project="$GCP_PROJECT_ID" --effective --format=json)"
  jq -e '.booleanPolicy.enforced != true' <<<"$creation_policy" >/dev/null ||
    { printf 'FAIL: 조직 정책이 SA 생성을 금지합니다.\n' >&2; return 1; }
  jq -e '.listPolicy.allValues == "ALLOW"' <<<"$member_policy" >/dev/null ||
    { printf 'FAIL: 제한된 IAM domain 정책은 관리자 사전 검토가 필요합니다. 자동 완화하지 않습니다.\n' >&2; return 1; }
  P07_DEBIAN_IMAGE="$(gcloud compute images describe-from-family debian-12 --account="$user1" --project=debian-cloud --format='value(selfLink)')"
  [[ "$P07_DEBIAN_IMAGE" =~ ^https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-12-[a-z0-9-]+$ ]] ||
    { printf 'FAIL: immutable Debian image 조회 실패\n' >&2; return 1; }
  local accounts vms
  accounts="$(gcloud iam service-accounts list --account="$user1" --project="$GCP_PROJECT_ID" --format=json)"
  jq -e --arg run "$1" --arg project "$GCP_PROJECT_ID" '
    [.[] | select(.email == ("p07-w-"+$run+"@"+$project+".iam.gserviceaccount.com"))] | length==0
  ' <<<"$accounts" >/dev/null || { printf 'FAIL: 기존 test SA와 이름 충돌\n' >&2; return 1; }
  vms="$(gcloud compute instances list --account="$user1" --project="$GCP_PROJECT_ID" --filter="name=p07-probe-$1" --format=json)"
  [[ "$(jq length <<<"$vms")" == 0 ]] || { printf 'FAIL: 기존 probe VM과 이름 충돌\n' >&2; return 1; }
}

phase_write_tfvars() {
  local path="$1" run_id="$2"
  jq -n --arg project_id "$GCP_PROJECT_ID" --arg run_id "$run_id" --arg region "$GCP_REGION" \
    --arg zone "$GCP_ZONE" --arg user1 "$user1" --arg user2 "$user2" \
    '{identity_mode:"two-users",project_id:$project_id,run_id:$run_id,region:$region,zone:$zone,user1:$user1,user2:$user2}' >"$path"
}

phase_write_action_plan() {
  local path="$1" run_id="$2"
  local inputs="$(dirname "$path")/work/phase-07.auto.tfvars.json"
  jq -n --arg run_id "$run_id" --arg image "$P07_DEBIAN_IMAGE" --arg project "$GCP_PROJECT_ID" \
    --arg zone "$GCP_ZONE" --arg user1 "$user1" --arg user2 "$user2" --arg code_sha "$(p07_source_sha)" --arg inputs_sha "$(harness_sha256_file "$inputs")" '{
    schema_version:1,phase:"07",run_id:$run_id,
    actions:[
      {id:"implementation",kind:"local",target:$code_sha,mutation:"실행 코드 SHA-256 대조",rollback:"none; read-only",timeout_seconds:30,contains_secret:false},
      {id:"saved-inputs",kind:"local",target:$inputs_sha,mutation:"saved run/project/location/runner SHA-256 check",rollback:"none; read-only",timeout_seconds:30,contains_secret:false},
      {id:"user-identities",kind:"local",target:("user1="+$user1+" user2="+$user2),mutation:"separate real-user OAuth and userinfo identity checks; no service-account impersonation",rollback:"no credential or active-account changes",timeout_seconds:120,contains_secret:false},
      {id:"viewer-grant-revoke",kind:"gcloud",target:("projects/"+$project+" member=user:"+$user2),mutation:"User1 grants project roles/viewer to authenticated User2; User2 reads IAM/project/buckets but cannot edit IAM; then revoke and verify denial",rollback:"remove only exact temporary User2 Viewer tuple; preserve User1 and all existing principals",timeout_seconds:1800,contains_secret:false},
      {id:"storage-viewer",kind:"gcloud",target:("projects/"+$project+" member=user:"+$user2),mutation:"project-level roles/storage.objectViewer gives User2 read access to ALL project bucket objects, including existing buckets; verify run fixture list/read and deny write/Compute/IAM edit",rollback:"remove exact temporary User2 project objectViewer tuple",timeout_seconds:1800,contains_secret:false},
      {id:"user2-vm-permissions",kind:"gcloud",target:("projects/"+$project+" member=user:"+$user2+" workload=p07-w-"+$run_id+"@"+$project+".iam.gserviceaccount.com"),mutation:"User1 grants User2 workload-only roles/iam.serviceAccountUser and project roles/compute.instanceAdmin.v1; Compute role covers ALL project VMs including existing ones; retain project Object Viewer; verify absent -> allowed permissions",rollback:"remove exact temporary User2 Compute role and workload actAs; preserve User1 and existing principals",timeout_seconds:1200,contains_secret:false},
      {id:"probe-vm",kind:"http",target:("projects/"+$project+"/zones/"+$zone+"/instances/p07-probe-"+$run_id+" image="+$image),mutation:("User2="+$user2+" (not administrator User1) creates one private e2-micro VM with workload SA; immutable Debian12, 10GB pd-standard auto-delete disk, cloud-platform scope, OS Login/IAP; verify operation actor and final RUNNING identity, not HTTP acceptance"),rollback:"User1 deletes exact run-labeled VM on failure/destroy; never touch other VMs",timeout_seconds:1200,contains_secret:false},
      {id:"guest-permission-matrix",kind:"guest",target:("p07-probe-"+$run_id),mutation:"metadata identity+scope check; compute.instances.list HTTP403, fixture read success, storage.objects.create HTTP403; runner OS Login public SSH key registration for IAP connection",rollback:"no private key/token copied; exact run sample2 object removed with bucket cleanup",timeout_seconds:1800,contains_secret:false},
      {id:"viewer-to-creator",kind:"gcloud",target:("projects/"+$project+" member=serviceAccount:p07-w-"+$run_id+"@"+$project+".iam.gserviceaccount.com"),mutation:"project-level workload Viewer -> Creator (all project buckets scope); guest writes only run sample2.txt with ifGenerationMatch=0 AND cannot read existing sample.txt",rollback:"remove Creator, restore Terraform project Viewer; revoke User2 Viewer/Object Viewer/Compute/actAs and verify denial while fixture still exists",timeout_seconds:1200,contains_secret:false}
    ]
  }' >"$path"
}

phase_plan_guard() {
  local path="$1" inputs="$(dirname "$1")/work/phase-07.auto.tfvars.json"
  # provider가 fixture content도 sensitive로 표시한다. 원문 plan은 파일로 쓰지 않고 검사기에만 pipe한다.
  terraform -chdir="$(dirname "$path")/work" show -json "$(dirname "$path")/phase-07.tfplan" |
    python3 "$repo_root/phases/07/plan-guard.py" - --project "$GCP_PROJECT_ID" \
    --run "$(jq -r .run_id "$inputs")" --region "$GCP_REGION" --user1 "$user1" --user2 "$user2"
}

phase_before_apply() {
  p07_context "$1" || return
  p07_assert_runner || return
  p07_assert_approved_context || return
  python3 "$repo_root/phases/07/auth.py" --config "$tfvars" --project "$p07_project" >/dev/null
}

phase_before_destroy() {
  p07_context "$1" || return
  p07_rollback || return
  p07_delete_probe
}

source "$repo_root/lib/harness/phase-adapter.sh"
source "$repo_root/phases/07/support.sh"
# provider에 사용할 User1은 plan에는 로컬 설정, 이후에는 SHA 고정 saved inputs에서 읽는다.
action="${1:-}"; selected_run=""; arguments=("$@")
for ((i=1; i<${#arguments[@]}; i++)); do
  if [[ "${arguments[$i]}" == --run ]]; then selected_run="${arguments[$((i+1))]:-}"; fi
done
[[ "$action" == plan || "$action" == apply || "$action" == verify || "$action" == destroy ]] || { harness_phase_adapter_usage >&2; exit 2; }
harness_validate_run_id "$selected_run"
identity_config="$repo_root/config/phase-07-users.json"
if [[ "$action" == plan ]]; then
  # 실제 터미널에서는 누락 계정 입력/로그인을 연결한다. CI/AI pipe에서는 안내 후 중단한다.
  "$repo_root/phases/07/auth.sh" --ensure
fi
[[ "$action" == plan ]] || identity_config="$repo_root/artifacts/runs/$selected_run/phase-07/work/phase-07.auto.tfvars.json"
p07_provider_identity "$identity_config"
harness_phase_adapter_main "$@"
