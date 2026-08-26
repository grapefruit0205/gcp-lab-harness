#!/usr/bin/env bash
set -Eeuo pipefail
project_id="$1"
zone="$2"
instance_name="$3"
deadline=$((SECONDS + 600))
while (( SECONDS < deadline )); do
  if serial="$(gcloud compute instances get-serial-port-output "$instance_name" --zone="$zone" --project="$project_id" --port=1 --start=0 2>/dev/null)" && grep -Fq HARNESS_IMAGE_READY <<<"$serial"; then
    gcloud compute instances stop "$instance_name" --zone="$zone" --project="$project_id" --quiet >/dev/null
    exit 0
  fi
  sleep 10
done
printf 'builder readiness timeout: %s\n' "$instance_name" >&2
exit 1
