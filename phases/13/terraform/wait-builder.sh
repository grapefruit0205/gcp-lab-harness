#!/usr/bin/env bash
set -Eeuo pipefail
project_id="$1"
zone="$2"
instance_name="$3"
receipt_path="${4:-$(dirname "$0")/builder-readiness.json}"
recovered_after_image="${5:-false}"
[[ "$recovered_after_image" == true || "$recovered_after_image" == false ]] || exit 2
umask 077
wait_ready() {
  local previous="${1:-}" serial boot_id deadline=$((SECONDS + 600))
  while (( SECONDS < deadline )); do
    serial="$(gcloud compute instances get-serial-port-output "$instance_name" --zone="$zone" --project="$project_id" --port=1 --start=0 2>/dev/null)" || serial=''
    boot_id="$(sed -n 's/.*HARNESS_IMAGE_READY boot_id=\([a-f0-9-]*\).*/\1/p' <<<"$serial" | tail -n1)"
    if [[ "$boot_id" =~ ^[a-f0-9-]{36}$ && "$boot_id" != "$previous" ]]; then
      printf '%s' "$boot_id"; return 0
    fi
    sleep 10
  done
  printf 'builder readiness/reset timeout: %s\n' "$instance_name" >&2
  return 1
}
first_boot="$(wait_ready)"
gcloud compute instances reset "$instance_name" --zone="$zone" --project="$project_id" --quiet >/dev/null
second_boot="$(wait_ready "$first_boot")"
# getSerialPortOutput은 RUNNING VM만 지원하므로 stop 전에 필요한 값만 보존한다.
serial="$(gcloud compute instances get-serial-port-output "$instance_name" --zone="$zone" --project="$project_id" --port=1 --start=0)"
apache_version="$(sed -n 's/.*HARNESS_APACHE_VERSION=\([^[:space:]]*\).*/\1/p' <<<"$serial" | tail -n1)"
[[ -n "$apache_version" ]] || { printf 'Apache version evidence 누락\n' >&2; exit 1; }
instance_id="$(gcloud compute instances describe "$instance_name" --zone="$zone" --project="$project_id" --format='value(id)')"
[[ "$instance_id" =~ ^[0-9]+$ ]] || { printf 'builder Cloud identity 누락\n' >&2; exit 1; }
receipt_tmp="$(mktemp "$receipt_path.tmp.XXXXXX")"
jq -n --arg project "$project_id" --arg zone "$zone" --arg instance "$instance_name" --arg instance_id "$instance_id" \
  --arg first_boot "$first_boot" --arg second_boot "$second_boot" --arg apache_version "$apache_version" --argjson recovered "$recovered_after_image" \
  '{project:$project,zone:$zone,instance:$instance,instance_id:$instance_id,first_boot:$first_boot,second_boot:$second_boot,
    apache_package_version:$apache_version,captured_before_stop:true,reset_autostart_verified:true,recovered_after_image:$recovered}' >"$receipt_tmp"
if [[ -f "$receipt_path" ]]; then mv "$receipt_path" "$receipt_path.previous.$(date +%s%N)"; fi
mv "$receipt_tmp" "$receipt_path"
gcloud compute instances stop "$instance_name" --zone="$zone" --project="$project_id" --quiet >/dev/null
