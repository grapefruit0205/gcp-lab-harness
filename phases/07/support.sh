#!/usr/bin/env bash
# Phase 07 전용 identity·승인·정확한 IAM tuple rollback.

p07_source_sha() {
  (
    cd "$repo_root"
    sha256sum phases/07/{execute.sh,verify.sh,support.sh,iam-probe.py,plan-guard.py,auth.py,auth.sh} \
      lib/harness/{phase-adapter.sh,terraform.sh,config.sh,common.sh} | sha256sum | awk '{print $1}'
  )
}

p07_context() {
  run_id="$1"
  harness_validate_run_id "$run_id" || return
  run_dir="$repo_root/artifacts/runs/$run_id/phase-07"
  tfvars="$run_dir/work/phase-07.auto.tfvars.json"
  manifest="$run_dir/manifest.json"
  harness_require_file "$tfvars" "Phase 07 saved inputs" || return
  jq -e --arg run "$run_id" --arg project "$GCP_PROJECT_ID" \
    '.run_id == $run and .project_id == $project' "$tfvars" >/dev/null ||
    { harness_die "Phase 07 저장 입력의 run/project가 현재 allowlist와 다릅니다."; return 1; }
  p07_project="$(jq -r .project_id "$tfvars")"
  p07_region="$(jq -r .region "$tfvars")"
  p07_zone="$(jq -r .zone "$tfvars")"
  python3 "$repo_root/phases/07/auth.py" --config "$tfvars" --validate-only >/dev/null || return
  user1="$(jq -r .user1 "$tfvars")"
  user2="$(jq -r .user2 "$tfvars")"
  workload="p07-w-$run_id@$p07_project.iam.gserviceaccount.com"
  bucket="gcp-lab-p07-$run_id"; vm="p07-probe-$run_id"
  journal="$run_dir/iam-rollback.json"
}

p07_assert_approved_context() {
  local bundle="$run_dir/plan-bundle.json" actions="$run_dir/action-plan.json"
  [[ "$(harness_sha256_file "$bundle")" == "$(jq -r .plan.bundle_sha256 "$manifest")" &&
     "$(harness_sha256_file "$actions")" == "$(jq -r .action_plan.sha256 "$bundle")" ]] ||
    { harness_die "Phase 07 bundle/action plan이 manifest와 다릅니다."; return 1; }
  jq -e --arg run "$run_id" --arg sha "$(p07_source_sha)" \
    --arg inputs "$(harness_sha256_file "$tfvars")" '
      .phase == "07" and .run_id == $run and
      ([.actions[] | select(.id=="implementation") | .target] == [$sha]) and
      ([.actions[] | select(.id=="saved-inputs") | .target] == [$inputs])
    ' "$actions" >/dev/null || { harness_die "Phase 07 실행 코드 또는 saved inputs가 승인 시점과 다릅니다. 새 plan이 필요합니다."; return 1; }
  debian_image="$(jq -r '.actions[] | select(.id=="probe-vm") | .target | split(" image=")[1]' "$actions")"
  [[ "$debian_image" =~ ^https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-12-[a-z0-9-]+$ ]] ||
    { harness_die "승인된 immutable Debian 12 image가 없습니다."; return 1; }
}

p07_assert_runner() {
  python3 "$repo_root/phases/07/auth.py" --config "$tfvars" >/dev/null
}

p07_provider_identity() {
  local config_path="$1"
  python3 "$repo_root/phases/07/auth.py" --config "$config_path" --only user1 >/dev/null || return
  user1="$(jq -r .user1 "$config_path")"
  user2="$(jq -r .user2 "$config_path")"
  export CLOUDSDK_CORE_ACCOUNT="$user1"
  # Terraform도 명시적 User1 OAuth token으로 고정한다. ADC/가장 fallback은 사용하지 않는다.
  unset GOOGLE_APPLICATION_CREDENTIALS GOOGLE_CREDENTIALS GOOGLE_CLOUD_KEYFILE_JSON GCLOUD_KEYFILE_JSON GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
  GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token --account="$user1" --quiet)" || return
  export GOOGLE_OAUTH_ACCESS_TOKEN
}

p07_compute_inventory() {
  case "$1" in
    subnetworks) gcloud compute networks subnets list --account="$user1" --project="$p07_project" --format=json ;;
    instances|disks|networks|firewall-rules) gcloud compute "$1" list --account="$user1" --project="$p07_project" --format=json ;;
    *) harness_die "Phase 07 inventory 종류가 허용되지 않습니다."; return 1 ;;
  esac
}

p07_policy() {
  case "$1" in
    project) gcloud projects get-iam-policy "$p07_project" --account="$user1" --format=json ;;
    workload) gcloud iam service-accounts get-iam-policy "$workload" --account="$user1" --project="$p07_project" --format=json ;;
    bucket) gcloud storage buckets get-iam-policy "gs://$bucket" --account="$user1" --format=json ;;
    *) return 2 ;;
  esac
}

p07_binding() {
  local operation="$1" scope="$2" member="$3" role="$4"
  case "$scope:$member:$role" in
    "project:user:$user2:roles/viewer"|\
    "project:user:$user2:roles/storage.objectViewer"|\
    "project:user:$user2:roles/compute.instanceAdmin.v1"|\
    "workload:user:$user2:roles/iam.serviceAccountUser"|\
    "project:serviceAccount:$workload:roles/storage.objectViewer"|\
    "project:serviceAccount:$workload:roles/storage.objectCreator") ;;
    *) harness_die "Phase 07 IAM tuple allowlist 밖 변경입니다."; return 1 ;;
  esac
  [[ "$operation" == add || "$operation" == remove ]] || return 2
  [[ "$scope" != workload ]] || p07_assert_identities || return 1
  local policy present
  policy="$(p07_policy "$scope")" || return
  present="$(jq --arg role "$role" --arg member "$member" \
    '[.bindings[]? | select(.role==$role and (.condition // null)==null) | .members[]? | select(.==$member)] | length' <<<"$policy")"
  if [[ "$operation" == remove && "$present" == 0 || "$operation" == add && "$present" == 1 ]]; then return 0; fi
  [[ "$user1" != "$user2" && "$member" != "user:$user1" ]] || { harness_die "관리자 계정의 권한 변경은 허용하지 않습니다."; return 1; }
  local options=("--member=$member" "--role=$role" --condition=None --quiet "--account=$user1")
  case "$scope" in
    project) gcloud projects "$operation-iam-policy-binding" "$p07_project" "${options[@]}" >/dev/null ;;
    workload) gcloud iam service-accounts "$operation-iam-policy-binding" "$workload" --project="$p07_project" "${options[@]}" >/dev/null ;;
    bucket) gcloud storage buckets "$operation-iam-policy-binding" "gs://$bucket" "${options[@]}" >/dev/null ;;
  esac
}

p07_policy_hash() {
  # etag/version 변경은 내용 drift가 아니다. 다른 principal의 binding은 보존한다.
  jq -Sc '[.bindings[]? | {role, members:(.members|sort), condition:(.condition // null)}] | sort_by(.role, .condition|tostring)' |
    sha256sum | awk '{print $1}'
}

p07_assert_identities() {
  local actual
  actual="$(gcloud iam service-accounts describe "$workload" --account="$user1" --project="$p07_project" --format='value(uniqueId)')" || return
  [[ -n "$actual" && "$actual" == "$(jq -r .identities.workload "$journal")" ]] ||
    { harness_die "Phase 07 workload SA 재생성/소유권 변경 감지"; return 1; }
  jq -e --arg user1 "$user1" --arg user2 "$user2" '.user1==$user1 and .user2==$user2' "$journal" >/dev/null || return
}

p07_rollback() {
  # Terraform apply만 수행한 run에는 imperative IAM 변경이 없다.
  [[ -f "$journal" ]] || return 0
  jq -e --arg run "$run_id" --arg project "$p07_project" \
    '.run_id==$run and .project==$project' "$journal" >/dev/null || return 1
  jq -e --arg u1 "$user1" --arg u2 "$user2" '.user1==$u1 and .user2==$u2 and .user2_baseline_empty==true' "$journal" >/dev/null || return 1
  local failed=0
  # journal 작성 전 User2의 기존 project binding이 없음을 확인한 run만 회수한다.
  p07_binding remove project "user:$user2" roles/viewer || failed=1
  p07_binding remove project "user:$user2" roles/storage.objectViewer || failed=1
  p07_binding remove project "user:$user2" roles/compute.instanceAdmin.v1 || failed=1
  # workload 재생성/삭제가 있어도 실제 User2의 임시 grant부터 회수한다.
  p07_assert_identities || return 1
  # User2의 기존 workload binding이 없던 run만 해당 tuple을 회수한다.
  [[ "$(jq -r '.user2_workload_baseline_empty // false' "$journal")" == true ]] || return 1
  p07_binding remove workload "user:$user2" roles/iam.serviceAccountUser || failed=1
  p07_binding remove project "serviceAccount:$workload" roles/storage.objectCreator || failed=1
  p07_binding add project "serviceAccount:$workload" roles/storage.objectViewer || failed=1
  return "$failed"
}

p07_delete_probe() {
  [[ -f "$journal" ]] || return 0
  local inventory count
  inventory="$(gcloud compute instances list --account="$user1" --project="$p07_project" --filter="name=$vm" --format=json)" || return
  count="$(jq length <<<"$inventory")"
  if [[ "$count" != 0 ]]; then
    jq -e --arg run "$run_id" --arg zone "$p07_zone" --arg vm "$vm" '
      length==1 and .[0].name==$vm and .[0].labels.harness=="gcp-lab-harness" and
      .[0].labels.phase=="07" and .[0].labels.run==$run and (.[0].zone|endswith("/"+$zone))
    ' <<<"$inventory" >/dev/null || { harness_die "probe VM 소유권을 확인하지 못해 삭제하지 않습니다."; return 1; }
    gcloud compute instances delete "$vm" --account="$user1" --zone="$p07_zone" --project="$p07_project" --quiet >/dev/null || return
  fi
  inventory="$(gcloud compute disks list --account="$user1" --project="$p07_project" --filter="name=$vm" --format=json)" || return
  [[ "$(jq length <<<"$inventory")" != 0 ]] || return 0
  jq -e --arg run "$run_id" --arg zone "$p07_zone" --arg vm "$vm" '
    length==1 and .[0].name==$vm and .[0].labels.harness=="gcp-lab-harness" and
    .[0].labels.phase=="07" and .[0].labels.run==$run and (.[0].users // [] | length)==0 and
    (.[0].zone|endswith("/"+$zone))
  ' <<<"$inventory" >/dev/null || { harness_die "orphan boot disk 소유권을 확인하지 못해 삭제하지 않습니다."; return 1; }
  gcloud compute disks delete "$vm" --account="$user1" --zone="$p07_zone" --project="$p07_project" --quiet >/dev/null
}
