#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
phase_dir="$repo_root/phases/07"
export HARNESS_REPO_ROOT="$repo_root" CLOUDSDK_CORE_DISABLE_FILE_LOGGING=1
source "$repo_root/lib/harness/config.sh"
source "$repo_root/lib/harness/terraform.sh"
source "$phase_dir/support.sh"
mode=offline; run_id=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --offline) mode=offline; shift ;;
    --applied) mode=applied; shift ;;
    --destroyed) mode=destroyed; shift ;;
    --run) [[ "$mode" == applied || "$mode" == destroyed ]] || mode=cloud; run_id="${2:-}"; shift 2 ;;
    *) printf '사용법: %s [--offline|--applied --run <id>|--run <id>|--destroyed --run <id>]\n' "$0" >&2; exit 2 ;;
  esac
done
if [[ "$mode" == offline ]]; then
  for script in "$phase_dir"/{execute,verify,support,auth}.sh; do bash -n "$script"; done
  terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-07-iam.md" >/dev/null
  python3 "$repo_root/tests/test-phase-07.py"
  ! rg -q 'google_project_iam_(policy|binding)|google_service_account_key|serviceAccountTokenCreator|runner_impersonation' "$phase_dir/terraform/main.tf" || harness_die "원문과 다른 가장/authoritative IAM 경로"
  printf 'PASS: Phase 07 실제 두 사용자 offline 계약 검증 완료\n'; exit 0
fi
harness_load_config "$repo_root/config/harness.env"
p07_context "$run_id"
p07_provider_identity "$tfvars"
"$repo_root/scripts/preflight-gcp.sh" >/dev/null
evidence_dir="$run_dir/evidence"; mkdir -p "$evidence_dir"; chmod 700 "$evidence_dir"
if [[ "$mode" == destroyed ]]; then
  remaining=0
  for kind in instances disks networks subnetworks firewall-rules; do
    inventory="$(p07_compute_inventory "$kind")"
    count="$(jq --arg run "$run_id" '[.[] | select(.name==("p07-probe-"+$run) or .name==("p07-net-"+$run) or .name==("p07-subnet-"+$run) or .name==("p07-iap-ssh-"+$run))] | length' <<<"$inventory")"
    remaining=$((remaining + count))
  done
  inventory="$(gcloud iam service-accounts list --account="$user1" --project="$p07_project" --format=json)"
  count="$(jq --arg w "$workload" '[.[] | select(.email==$w)] | length' <<<"$inventory")"; remaining=$((remaining + count))
  inventory="$(gcloud storage buckets list --account="$user1" --project="$p07_project" --format=json)"
  count="$(jq --arg b "$bucket" '[.[] | select(.name==$b or .name==("gs://"+$b))] | length' <<<"$inventory")"; remaining=$((remaining + count))
  policy="$(p07_policy project)"
  jq -e --arg w "$workload" '[.bindings[]?.members[]? | select(contains($w))] | length==0' <<<"$policy" >/dev/null || harness_die "workload project IAM 잔여"
  if [[ -f "$journal" ]]; then
    jq -e --arg u "user:$user2" '[.bindings[]? | select(.role=="roles/viewer" or .role=="roles/storage.objectViewer" or .role=="roles/compute.instanceAdmin.v1") | .members[]? | select(.==$u)] | length==0' <<<"$policy" >/dev/null || harness_die "임시 User2 IAM 잔여"
  fi
  [[ "$remaining" == 0 ]] || harness_die "Phase 07 활성 잔여: $remaining"
  printf 'PASS: Phase 07 소유 리소스·임시 사용자 권한 잔여 0\n'; exit 0
fi
harness_manifest_require_status "$manifest" applied
p07_assert_approved_context
success=false
finish() {
  local original="$?" rollback_status=0
  trap - EXIT
  [[ "$success" != true || "$original" != 0 ]] || return 0
  p07_rollback || rollback_status=1
  harness_manifest_set_status "$manifest" cleanup_required
  printf 'FAIL: Phase 07 중단; 임시 IAM rollback=%s, 소유 리소스 cleanup\n' "$rollback_status" >&2
  if [[ "${GCP_CLEANUP_ON_FAILURE:-}" == true ]]; then
    "$phase_dir/execute.sh" destroy --run "$run_id" >"$run_dir/verification-cleanup.log" 2>&1 || printf 'FAIL: cleanup 미완료; manifest 확인 필요\n' >&2
  fi
  [[ "$original" != 0 ]] || original=1
  exit "$original"
}
[[ "$mode" != cloud ]] || trap finish EXIT
p07_assert_runner
services="$(gcloud services list --enabled --account="$user1" --project="$p07_project" --format=json)"
jq -e '[.[] | .config.name] | index("cloudresourcemanager.googleapis.com")!=null' <<<"$services" >/dev/null
network="$(gcloud compute networks describe "p07-net-$run_id" --account="$user1" --project="$p07_project" --format=json)"
subnet="$(gcloud compute networks subnets describe "p07-subnet-$run_id" --account="$user1" --region="$p07_region" --project="$p07_project" --format=json)"
firewall="$(gcloud compute firewall-rules describe "p07-iap-ssh-$run_id" --account="$user1" --project="$p07_project" --format=json)"
bucket_info="$(gcloud storage buckets describe "gs://$bucket" --account="$user1" --format=json)"
jq -e '.autoCreateSubnetworks==false' <<<"$network" >/dev/null
jq -e --arg run "$run_id" '.privateIpGoogleAccess==true and .ipCidrRange=="10.27.0.0/24" and (.network|endswith("/p07-net-"+$run))' <<<"$subnet" >/dev/null
jq -e --arg run "$run_id" '.direction=="INGRESS" and .disabled==false and .sourceRanges==["35.235.240.0/20"] and .targetTags==["p07-iam-probe"] and .allowed==[{IPProtocol:"tcp",ports:["22"]}] and (.network|endswith("/p07-net-"+$run))' <<<"$firewall" >/dev/null
jq -e '.public_access_prevention=="enforced" and .uniform_bucket_level_access==true' <<<"$bucket_info" >/dev/null
sa="$(gcloud iam service-accounts describe "$workload" --account="$user1" --project="$p07_project" --format=json)"
jq -e --arg w "$workload" '.email==$w and .disabled!=true and (.uniqueId|type)=="string"' <<<"$sa" >/dev/null
policy="$(p07_policy workload)"
jq -e '[.bindings[]?] | length==0' <<<"$policy" >/dev/null || harness_die "새 workload SA의 기존 권한은 자동 변경하지 않습니다."
policy="$(p07_policy project)"
jq -e --arg w "serviceAccount:$workload" '[.bindings[]? | . as $b | .members[]? | select(.==$w) | {role:$b.role,condition:($b.condition // null)}] == [{role:"roles/storage.objectViewer",condition:null}]' <<<"$policy" >/dev/null
[[ "$(gcloud storage cat "gs://$bucket/sample.txt" --account="$user1")" == "Phase 07 IAM fixture $run_id" ]] || harness_die "fixture 불일치"
jq -n --arg run "$run_id" '{phase:"07",run_id:$run,identity_mode:"two-users",status:"applied-topology-checked",workload_accounts:1,iam_transition_verified:false}' >"$evidence_dir/phase-07-applied.json"
if [[ "$mode" == applied ]]; then printf 'PASS: Phase 07 실제 사용자·배포 read-only 검사\n'; exit 0; fi
[[ ! -e "$journal" ]] || harness_die "이미 실습한 run입니다. 재실행 대신 cleanup과 새 plan이 필요합니다."
# 기존/상속 User2 권한이 있으면 한 개도 제거하지 않고 중단한다.
python3 "$phase_dir/auth.py" --config "$tfvars" --project "$p07_project" --bucket "$bucket" >"$evidence_dir/user-identities.json"
jq -e --arg u "user:$user2" '[.bindings[]?.members[]? | select(.==$u)] | length==0' <<<"$policy" >/dev/null || harness_die "User2 기존 IAM 발견"
for scope in project workload bucket; do p07_policy "$scope" >"$run_dir/iam-baseline-$scope.json"; done
jq -n --arg run "$run_id" --arg project "$p07_project" --arg u1 "$user1" --arg u2 "$user2" --arg uid "$(jq -r .uniqueId <<<"$sa")" '{run_id:$run,project:$project,user1:$u1,user2:$u2,user2_baseline_empty:true,user2_workload_baseline_empty:true,identities:{workload:$uid}}' >"$journal"
for role in roles/viewer roles/storage.objectViewer roles/storage.objectCreator roles/iam.serviceAccountUser roles/compute.instanceAdmin.v1; do
  gcloud iam roles describe "$role" --account="$user1" --format=json | jq '{name,permissions:.includedPermissions}' >"$evidence_dir/role-${role##*/}.json"
done
probe() {
  local id="$1" actor="$2" operation="$3" expect="$4"; shift 4
  python3 "$phase_dir/iam-probe.py" --project "$p07_project" --run "$run_id" --zone "$p07_zone" --region "$p07_region" --actor "$actor" --operation "$operation" --expect "$expect" "$@" >"$evidence_dir/$id.json"
  printf 'PASS: %s\n' "$id"
}
guest_probe() {
  local id="$1" operation="$2" expect="$3"
  timeout 660 gcloud compute ssh "$vm" --account="$user1" --zone="$p07_zone" --project="$p07_project" --tunnel-through-iap --quiet \
    --command="python3 - --guest --project '$p07_project' --run '$run_id' --zone '$p07_zone' --region '$p07_region' --actor '$workload' --operation '$operation' --expect '$expect'" \
    <"$phase_dir/iam-probe.py" >"$evidence_dir/$id.json"
  jq -e '.token_source=="metadata" and (.http_status==200 or .http_status==201 or .http_status==403)' "$evidence_dir/$id.json" >/dev/null
  printf 'PASS: %s\n' "$id"
}
probe user2-api-ready "$user2" api-ready allow
probe user2-actas-baseline-deny "$user2" actas deny
probe user2-compute-baseline-deny "$user2" compute-create-permission deny
p07_binding add project "user:$user2" roles/viewer
probe user2-iam-read "$user2" policy-read allow
probe user2-iam-edit-deny "$user2" policy-edit-permission deny
probe baseline-project "$user2" project allow
probe baseline-buckets "$user2" bucket-list allow
p07_binding remove project "user:$user2" roles/viewer
probe revoked-project "$user2" project deny
probe revoked-buckets "$user2" bucket-list deny
probe revoked-storage-read "$user2" read deny
p07_binding add project "user:$user2" roles/storage.objectViewer
probe storage-list "$user2" object-list allow
probe storage-read "$user2" read allow
probe storage-write-deny "$user2" write deny
probe storage-compute-deny "$user2" compute deny
probe storage-iam-edit-deny "$user2" policy-edit-permission deny
# 최신 project-level Object Viewer는 project get/list를 포함할 수 있다. 역할과 실제 응답을 대조한다.
project_expect=deny
jq -e '.permissions | index("resourcemanager.projects.get")!=null' "$evidence_dir/role-storage.objectViewer.json" >/dev/null && project_expect=allow
probe storage-project-role-boundary "$user2" project "$project_expect"
p07_binding add workload "user:$user2" roles/iam.serviceAccountUser
p07_binding add project "user:$user2" roles/compute.instanceAdmin.v1
probe user2-actas "$user2" actas allow
probe user2-compute-create-permission "$user2" compute-create-permission allow
probe user2-create-vm "$user2" create-vm allow --image "$debian_image"
probe user2-vm-running "$user2" vm-status allow
ssh_ready() { timeout 30 gcloud compute ssh "$vm" --account="$user1" --zone="$p07_zone" --project="$p07_project" --tunnel-through-iap --quiet --command='command -v python3 >/dev/null'; }
harness_wait_until 300 10 ssh_ready || harness_die "IAP/guest Python 준비 실패"
guest_probe guest-compute-deny compute deny
guest_probe guest-object-read read allow
guest_probe guest-object-write-deny write deny
p07_binding remove project "serviceAccount:$workload" roles/storage.objectViewer
p07_binding add project "serviceAccount:$workload" roles/storage.objectCreator
guest_probe guest-creator-write write allow
guest_probe guest-creator-read-deny read deny
[[ "$(gcloud storage cat "gs://$bucket/sample2.txt" --account="$user1")" == "Phase 07 IAM fixture $run_id" ]] || harness_die "guest 업로드 내용 불일치"
p07_rollback
for scope in project workload bucket; do
  [[ "$(p07_policy "$scope" | p07_policy_hash)" == "$(p07_policy_hash <"$run_dir/iam-baseline-$scope.json")" ]] || harness_die "$scope IAM baseline 불일치; 다른 변경을 덮어쓰지 않습니다."
done
probe rollback-project-deny "$user2" project deny
probe rollback-storage-deny "$user2" read deny
probe rollback-compute-deny "$user2" compute-create-permission deny
probe rollback-actas-deny "$user2" actas deny
probe rollback-admin-preserved "$user1" policy-edit-permission allow
guest_probe restored-viewer-read read allow
jq -n --arg run "$run_id" '{phase:"07",run_id:$run,identity_mode:"two-users",tasks:{
  "task-1":{status:"passed",detail:"서로 다른 실제 사용자 OAuth 두 개와 userinfo identity 확인; SA 가장 없음"},
  "task-2":{status:"passed",detail:"User1 IAM/role 조회, User2 Viewer IAM 조회와 setIamPolicy 권한 부재 확인; 콘솔 UI는 별도"},
  "task-3":{status:"passed",detail:"private bucket/fixture 및 실제 User2 project Viewer baseline"},
  "task-4":{status:"passed",detail:"User2 project Viewer 회수 후 프로젝트/버킷 목록 및 존재하는 sample.txt 읽기 거부"},
  "task-5":{status:"passed",detail:"원문 project-level Object Viewer: User2 객체 목록/읽기 성공, 쓰기/Compute/IAM 변경 거부; 최신 project get 역할 경계 대조"},
  "task-6":{status:"passed",detail:"Notion Task 6: 실제 User2에 workload-only actAs 및 project Compute 권한 부여 후 User2 OAuth로 VM 생성; operation actor와 RUNNING/private/workload 확인; SSH는 User1"},
  "task-7":{status:"passed",detail:"VM metadata workload identity·scope, Compute 거부/read 성공/write 거부→project Creator write 성공/read 거부"},
  "task-8":{status:"passed",detail:"IAM 검토: User2 Viewer/Object Viewer/Compute/actAs 회수, workload Viewer 복구, 3개 IAM baseline과 관리자 권한 보존; 최종 리소스 정리는 별도 destroy"}},
  notion_source:"3c76d458853781ecbcf3d1c5e12f28dd",
  lab_completion:{iam_verified:true,resource_cleanup:"pending-approved-destroy",complete:false},
  risks:["일반 창 A/시크릿 창 B UI와 인증된 브라우저 다운로드는 API 등가 경로이며 실제 UI 자동 검사 아님","project-level Storage 역할은 기존 bucket 객체에도 적용됨; API 요청은 run fixture로 제한","User2의 임시 Compute Instance Admin은 기존 VM에도 적용됨; 생성/삭제 요청은 run VM만 대상","User2 기존/상속 권한 발견 시 자동 삭제하지 않고 중단","VM/bucket/workload는 최종 cleanup 승인까지 유지; 비용 발생; Notion 전체 종료 완료는 아님"]}' >"$evidence_dir/phase-07-machine.json"
success=true
printf 'PASS: Phase 07 실제 두 사용자 IAM·workload·rollback 검증 완료\n'
