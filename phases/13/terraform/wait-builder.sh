#!/usr/bin/env bash
set -Eeuo pipefail
project_id="$1"
zone="$2"
instance_name="$3"
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
wait_ready "$first_boot" >/dev/null
gcloud compute instances stop "$instance_name" --zone="$zone" --project="$project_id" --quiet >/dev/null
