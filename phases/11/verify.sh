#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."&&pwd)";phase_dir="$repo_root/phases/11";export HARNESS_REPO_ROOT="$repo_root";source "$repo_root/lib/harness/config.sh";source "$repo_root/lib/harness/terraform.sh"
mode=offline;run_id="";while [[ "$#" -gt 0 ]];do case "$1" in --offline)mode=offline;shift;;--run)[[ "$mode" == destroyed ]]||mode=cloud;run_id="${2:-}";shift 2;;--destroyed)mode=destroyed;shift;;*)exit 2;;esac;done
if [[ "$mode" == offline ]];then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh" "$repo_root/scripts/setup-gcp-mcp.sh";terraform -chdir="$phase_dir/terraform" fmt -check>/dev/null
  [[ "$(grep -Ec '^[[:space:]]*conditions \{' "$phase_dir/terraform/main.tf")" -eq 2 ]]||harness_die "alert 조건 2개 필요"
  grep -Eq 'combiner[[:space:]]*=[[:space:]]*"AND"' "$phase_dir/terraform/main.tf"||harness_die "AND combiner 누락"
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-11-monitoring.md">/dev/null
  printf 'PASS: Phase 11 offline 계약 검증 완료\n';exit 0
fi
harness_validate_run_id "$run_id";harness_load_config "$repo_root/config/harness.env"
if [[ "$mode" == destroyed ]];then
  remaining="$(gcloud compute instances list --project="$GCP_PROJECT_ID" --filter="labels.run=$run_id AND labels.phase=11" --format='value(name)'|wc -l)"
  gcloud compute networks describe "p11-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true
  fixture_sa="p11-${run_id:0:20}@$GCP_PROJECT_ID.iam.gserviceaccount.com";gcloud iam service-accounts describe "$fixture_sa" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true
  base="https://monitoring.googleapis.com/v3/projects/$GCP_PROJECT_ID"
  dashboard_json="$($repo_root/scripts/gcp-rest.py GET "$base/dashboards?pageSize=1000")";policy_json="$($repo_root/scripts/gcp-rest.py GET "$base/alertPolicies?pageSize=1000")";group_json="$($repo_root/scripts/gcp-rest.py GET "$base/groups?pageSize=1000")";uptime_json="$($repo_root/scripts/gcp-rest.py GET "$base/uptimeCheckConfigs?pageSize=1000")"
  monitoring_remaining="$(jq -n --arg run "$run_id" --argjson dashboards "$dashboard_json" --argjson policies "$policy_json" --argjson groups "$group_json" --argjson uptimes "$uptime_json" '([$dashboards.dashboards[]?|select(.displayName==("Phase 11 "+$run))]|length)+([$policies.alertPolicies[]?|select(.displayName==("Phase 11 CPU "+$run))]|length)+([($groups.group//$groups.groups//[])[]?|select(.displayName==("Phase 11 nginx "+$run))]|length)+([$uptimes.uptimeCheckConfigs[]?|select(.displayName==("Phase 11 uptime "+$run))]|length)')"
  ((remaining+=monitoring_remaining))||true
  [[ "$remaining" -eq 0 ]]||harness_die "Phase 11 Compute/Monitoring 잔여 리소스: $remaining";printf 'PASS: Phase 11 잔여 리소스 0\n';exit 0
fi
run_dir="$repo_root/artifacts/runs/$run_id/phase-11";manifest="$run_dir/manifest.json";evidence_dir="$run_dir/evidence";evidence="$evidence_dir/phase-11-machine.json";harness_manifest_require_status "$manifest" applied;mkdir -p "$evidence_dir";chmod 700 "$evidence_dir"
guest(){ timeout 180 gcloud compute ssh "$1" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="$2"; }
for n in 1 2 3;do vm="nginxstack-$n-$run_id";harness_wait_until 300 10 guest "$vm" 'systemctl is-active nginx >/dev/null'||harness_die "$vm nginx readiness 실패";guest "$vm" 'timeout 90 stress-ng --cpu 1 --timeout 60s >/dev/null 2>&1 & for i in $(seq 1 30); do curl -fsS http://127.0.0.1/ >/dev/null; done';done
base="https://monitoring.googleapis.com/v3/projects/$GCP_PROJECT_ID"
dashboard_json="$($repo_root/scripts/gcp-rest.py GET "$base/dashboards")"
policy_json="$($repo_root/scripts/gcp-rest.py GET "$base/alertPolicies")"
group_json="$($repo_root/scripts/gcp-rest.py GET "$base/groups")"
uptime_json="$($repo_root/scripts/gcp-rest.py GET "$base/uptimeCheckConfigs")"
dashboard_name="$(jq -r --arg run "$run_id" '.dashboards[]? | select(.displayName==("Phase 11 "+$run)) | .name'<<<"$dashboard_json")"
policy_name="$(jq -r --arg run "$run_id" '.alertPolicies[]? | select(.displayName==("Phase 11 CPU "+$run)) | .name'<<<"$policy_json")"
group_name="$(jq -r --arg run "$run_id" '(.group // .groups // [])[] | select(.displayName==("Phase 11 nginx "+$run)) | .name'<<<"$group_json")"
uptime_name="$(jq -r --arg run "$run_id" '.uptimeCheckConfigs[]? | select(.displayName==("Phase 11 uptime "+$run)) | .name'<<<"$uptime_json")"
[[ -n "$dashboard_name" && -n "$policy_name" && -n "$group_name" && -n "$uptime_name" ]]||harness_die "Monitoring 구성 readback 누락"
jq -e --arg run "$run_id" '.alertPolicies[]|select(.displayName==("Phase 11 CPU "+$run))|(.combiner=="AND" and .enabled==true and (.conditions|length)==2)'<<<"$policy_json">/dev/null||harness_die "alert policy 구조 불일치"
members_json="$($repo_root/scripts/gcp-rest.py GET "https://monitoring.googleapis.com/v3/$group_name/members")"
[[ "$(jq '(.members // []) | length'<<<"$members_json")" -eq 3 ]]||harness_die "Monitoring group membership 3개가 아님"
start="$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)";end="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
metric_query="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.urlencode({"filter":f"metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\" AND metadata.user_labels.run=\"{sys.argv[3]}\"","interval.startTime":sys.argv[1],"interval.endTime":sys.argv[2]}))' "$start" "$end" "$run_id")"
uptime_id="${uptime_name##*/}"
uptime_query="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.urlencode({"filter":f"metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id=\"{sys.argv[3]}\"","interval.startTime":sys.argv[1],"interval.endTime":sys.argv[2]}))' "$start" "$end" "$uptime_id")"
metric_json="";uptime_metric_json=""
for _ in $(seq 1 20);do
  metric_json="$($repo_root/scripts/gcp-rest.py GET "$base/timeSeries?$metric_query")"
  uptime_metric_json="$($repo_root/scripts/gcp-rest.py GET "$base/timeSeries?$uptime_query")"
  if [[ "$(jq '[.timeSeries[]?.resource.labels.instance_id]|unique|length'<<<"$metric_json")" -eq 3 && "$(jq '(.timeSeries // []) | length'<<<"$uptime_metric_json")" -ge 1 ]];then break;fi
  sleep 15
done
[[ "$(jq '[.timeSeries[]?.resource.labels.instance_id]|unique|length'<<<"$metric_json")" -eq 3 ]]||harness_die "현재 run VM 3개의 실제 CPU time series 미도착"
[[ "$(jq '(.timeSeries // []) | length'<<<"$uptime_metric_json")" -ge 1 ]]||harness_die "현재 uptime check의 실제 time series 미도착"
patch_file="$run_dir/disable-alert.json";printf '{"enabled":false}\n'>"$patch_file";$repo_root/scripts/gcp-rest.py PATCH "https://monitoring.googleapis.com/v3/$policy_name?updateMask=enabled" --body "$patch_file">/dev/null;rm -f "$patch_file"
policy_after="$($repo_root/scripts/gcp-rest.py GET "https://monitoring.googleapis.com/v3/$policy_name")";jq -e '.enabled==false'<<<"$policy_after">/dev/null||harness_die "alert disable 전이 실패"
jq -n --arg phase 11 --arg run_id "$run_id" --arg dashboard_hash "$(printf %s "$dashboard_name"|sha256sum|awk '{print $1}')" --arg policy_hash "$(printf %s "$policy_name"|sha256sum|awk '{print $1}')" --arg group_hash "$(printf %s "$group_name"|sha256sum|awk '{print $1}')" --arg uptime_hash "$(printf %s "$uptime_name"|sha256sum|awk '{print $1}')" --argjson series_count "$(jq '(.timeSeries // [])|length'<<<"$metric_json")" --argjson uptime_series_count "$(jq '(.timeSeries // [])|length'<<<"$uptime_metric_json")" '{phase:$phase,run_id:$run_id,tasks:{
 "task-1":{status:"passed",detail:"nginx fixture VM 3개와 CPU time series 확인"},
 "task-2":{status:"passed",detail:"CPU chart dashboard JSON readback"},
 "task-3":{status:"passed",detail:"두 조건 AND alert; notification 전송은 안전 opt-in 경계"},
 "task-4":{status:"passed",detail:"run label group과 membership 대상 확인"},
 "task-5":{status:"passed",detail:"group 1분 HTTP uptime config와 실제 Monitoring resource 연결"},
 "task-6":{status:"passed",detail:"alert enabled true에서 false API 전이"},
 "task-7":{status:"passed",detail:"dashboard·policy·group membership·uptime·time series 검토"}},resource_name_sha256:[$dashboard_hash,$policy_hash,$group_hash,$uptime_hash],time_series_count:$series_count,uptime_series_count:$uptime_series_count,risks:["notification channel은 명시 opt-in 없이는 연결하지 않음","Extension에서 MCP OAuth connected 상태를 별도 확인"]}' >"$evidence";chmod 600 "$evidence"
printf 'PASS: Phase 11 Monitoring 구성·metric·alert disable 검증 완료\n'
