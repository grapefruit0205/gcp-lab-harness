#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"

usage() {
  printf '사용법: %s plan|apply|verify|destroy --run <id> [--confirm-plan-sha <sha256>]\n' "$0" >&2
}

action="${1:-}"
[[ "$action" == "plan" || "$action" == "apply" || "$action" == "verify" || "$action" == "destroy" ]] || {
  usage
  exit 2
}
shift

run_id=""
confirmed_sha=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --run) run_id="${2:-}"; shift 2 ;;
    --confirm-plan-sha) confirmed_sha="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[[ "$run_id" =~ ^[a-z0-9][a-z0-9-]{7,19}$ ]] || {
  printf 'FAIL: run ID는 8~20자의 소문자·숫자·하이픈이어야 합니다.\n' >&2
  exit 2
}

"$repo_root/scripts/preflight-gcp.sh" >/dev/null
harness_load_config "$repo_root/config/harness.env"

module_dir="$repo_root/foundation/terraform/apply-canary"
run_dir="$repo_root/artifacts/runs/foundation-canary-$run_id"
work_dir="$run_dir/work"
plan_file="$run_dir/canary.tfplan"
plan_json="$run_dir/canary-plan.json"
manifest_file="$run_dir/canary-manifest.json"
export TF_DATA_DIR="$run_dir/.terraform"

prepare_work_dir() {
  mkdir -p "$work_dir"
  chmod 700 "$run_dir" "$work_dir"
  cp "$module_dir/main.tf" "$work_dir/main.tf"
  cp "$module_dir/.terraform.lock.hcl" "$work_dir/.terraform.lock.hcl"
}

case "$action" in
  plan)
    [[ ! -e "$run_dir" ]] || {
      printf 'FAIL: 이미 존재하는 canary run입니다: %s\n' "$run_id" >&2
      exit 1
    }
    prepare_work_dir
    terraform -chdir="$work_dir" init -backend=false -input=false >/dev/null
    terraform -chdir="$work_dir" plan \
      -input=false \
      -lock=false \
      -var="project_id=$GCP_PROJECT_ID" \
      -var="run_id=$run_id" \
      -out="$plan_file"
    terraform -chdir="$work_dir" show -json "$plan_file" >"$plan_json"
    jq -e '
      [.resource_changes[] | select(.type == "google_compute_network" and .change.actions == ["create"])] | length == 1
    ' "$plan_json" >/dev/null
    jq -e '
      [.resource_changes[] | select(.type != "google_compute_network")] | length == 0
    ' "$plan_json" >/dev/null
    plan_sha="$(sha256sum "$plan_file" | awk '{print $1}')"
    project_hash="$(printf '%s' "$GCP_PROJECT_ID" | sha256sum | awk '{print $1}')"
    jq -n \
      --arg run_id "$run_id" \
      --arg plan_sha "$plan_sha" \
      --arg project_hash "$project_hash" \
      --arg created_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      '{
        run_id: $run_id,
        status: "planned",
        plan_sha256: $plan_sha,
        project_id_hash: $project_hash,
        resource: {type: "google_compute_network", count: 1, subnet_count: 0},
        created_at: $created_at
      }' >"$manifest_file"
    chmod 600 "$plan_file" "$plan_json" "$manifest_file"
    printf 'PASS: canary 저장 plan 생성 완료\n'
    printf 'run_id=%s\n' "$run_id"
    printf 'resource=google_compute_network (1개, subnet 0개)\n'
    printf 'plan_sha256=%s\n' "$plan_sha"
    ;;
  apply)
    [[ "$confirmed_sha" =~ ^[a-f0-9]{64}$ ]] || { usage; exit 2; }
    [[ -f "$plan_file" && -f "$manifest_file" ]] || {
      printf 'FAIL: 저장 plan 또는 manifest가 없습니다.\n' >&2
      exit 1
    }
    actual_sha="$(sha256sum "$plan_file" | awk '{print $1}')"
    expected_sha="$(jq -r '.plan_sha256' "$manifest_file")"
    [[ "$confirmed_sha" == "$actual_sha" && "$actual_sha" == "$expected_sha" ]] || {
      printf 'FAIL: 승인 hash와 저장 plan hash가 일치하지 않습니다.\n' >&2
      exit 1
    }
    terraform -chdir="$work_dir" apply -input=false "$plan_file"
    ;;
  verify)
    network_name="$(terraform -chdir="$work_dir" output -raw network_name)"
    network_json="$(gcloud compute networks describe "$network_name" --project="$GCP_PROJECT_ID" --format=json)"
    [[ "$(jq -r '.autoCreateSubnetworks' <<<"$network_json")" == "false" ]] || exit 1
    subnet_count="$(gcloud compute networks subnets list --project="$GCP_PROJECT_ID" --network="$network_name" --format=json | jq 'length')"
    [[ "$subnet_count" -eq 0 ]] || exit 1
    printf 'PASS: canary VPC와 subnet 0개를 확인했습니다.\n'
    ;;
  destroy)
    terraform -chdir="$work_dir" destroy \
      -auto-approve \
      -input=false \
      -var="project_id=$GCP_PROJECT_ID" \
      -var="run_id=$run_id"
    network_name="gcp-lab-canary-$run_id"
    if gcloud compute networks describe "$network_name" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
      printf 'FAIL: canary VPC가 남아 있습니다.\n' >&2
      exit 1
    fi
    [[ -z "$(terraform -chdir="$work_dir" state list)" ]] || {
      printf 'FAIL: Terraform state에 canary 리소스가 남아 있습니다.\n' >&2
      exit 1
    }
    printf 'PASS: canary destroy와 활성 잔여 리소스 0을 확인했습니다.\n'
    ;;
esac
