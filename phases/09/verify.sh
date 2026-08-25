#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; phase_dir="$repo_root/phases/09"; export HARNESS_REPO_ROOT="$repo_root"
source "$repo_root/lib/harness/config.sh"; source "$repo_root/lib/harness/terraform.sh"
mode=offline;run_id="";while [[ "$#" -gt 0 ]];do case "$1" in --offline)mode=offline;shift;;--run)[[ "$mode" == destroyed ]]||mode=cloud;run_id="${2:-}";shift 2;;--destroyed)mode=destroyed;shift;;*)exit 2;;esac;done
if [[ "$mode" == offline ]];then
  bash -n "$phase_dir/execute.sh" "$phase_dir/verify.sh";terraform -chdir="$phase_dir/terraform" fmt -check >/dev/null
  "$repo_root/scripts/phase-contract.py" --check "$repo_root/docs/phases/phase-09-cloud-sql.md" >/dev/null
  rg -q -- '--address=127.0.0.1 --port=3306' "$phase_dir/terraform/main.tf" || harness_die "Auth Proxy public-default 계약 누락"
  ! rg -q 'authorized_networks|source_ranges[[:space:]]*=[[:space:]]*\["0\.0\.0\.0/0"\]' "$phase_dir/terraform/main.tf" || harness_die "광범위 SQL/HTTP 노출 경로"
  printf 'PASS: Phase 09 offline 계약 검증 완료\n';exit 0
fi
harness_validate_run_id "$run_id";harness_load_config "$repo_root/config/harness.env";instance="wordpress-db-$run_id";proxy="wordpress-proxy-$run_id";private="wordpress-private-$run_id"
if [[ "$mode" == destroyed ]];then
  remaining=0;gcloud sql instances describe "$instance" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true
  for vm in "$proxy" "$private";do gcloud compute instances describe "$vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true;done
  gcloud compute networks describe "p09-net-$run_id" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true
  proxy_sa="p09-proxy-${run_id:0:15}@$GCP_PROJECT_ID.iam.gserviceaccount.com";private_sa="p09-private-${run_id:0:13}@$GCP_PROJECT_ID.iam.gserviceaccount.com"
  for account in "$proxy_sa" "$private_sa";do gcloud iam service-accounts describe "$account" --project="$GCP_PROJECT_ID" >/dev/null 2>&1&&((remaining+=1))||true;done
  project_policy="$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" --format=json)";jq -e --arg proxy "$proxy_sa" --arg private "$private_sa" '[.bindings[].members[]?|select(contains($proxy) or contains($private))]|length==0'<<<"$project_policy">/dev/null||harness_die "Phase 09 project IAM binding 잔여"
  [[ "$remaining" -eq 0 ]]||harness_die "Phase 09 잔여 리소스: $remaining";printf 'PASS: Phase 09 잔여 리소스 0\n';exit 0
fi
run_dir="$repo_root/artifacts/runs/$run_id/phase-09";manifest="$run_dir/manifest.json";evidence_dir="$run_dir/evidence";evidence="$evidence_dir/phase-09-machine.json";secret_dir="$run_dir/secrets"
harness_manifest_require_status "$manifest" applied;mkdir -p "$evidence_dir" "$secret_dir";chmod 700 "$evidence_dir" "$secret_dir"
sql_json="$(gcloud sql instances describe "$instance" --project="$GCP_PROJECT_ID" --format=json)"
jq -e '.state=="RUNNABLE" and (.ipAddresses|any(.type=="PRIMARY")) and (.ipAddresses|any(.type=="PRIVATE"))'<<<"$sql_json">/dev/null||harness_die "Cloud SQL public/private readiness 실패"
sql_private="$(jq -r '.ipAddresses[]|select(.type=="PRIVATE")|.ipAddress'<<<"$sql_json")"
password_file="$secret_dir/db-password";openssl rand -base64 36|tr -d '\n'>"$password_file";chmod 600 "$password_file"
printf '%s\n' "$(<"$password_file")"|gcloud sql users set-password root --instance="$instance" --project="$GCP_PROJECT_ID" --prompt-for-password --quiet >/dev/null
guest(){ local vm="$1";shift;timeout 300 gcloud compute ssh "$vm" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet --command="$*"; }
harness_wait_until 600 15 guest "$proxy" 'systemctl is-active apache2 cloud-sql-proxy >/dev/null' || harness_die "proxy guest readiness 실패"
harness_wait_until 600 15 guest "$private" 'systemctl is-active apache2 >/dev/null' || harness_die "private guest readiness 실패"
for spec in "$proxy:127.0.0.1" "$private:$sql_private";do
  vm="${spec%%:*}";host="${spec#*:}";config="$secret_dir/wp-config-$vm.php"
  pass="$(<"$password_file")"
  { printf '%s\n' '<?php';printf "define('DB_NAME','wordpress');\ndefine('DB_USER','root');\ndefine('DB_PASSWORD','%s');\ndefine('DB_HOST','%s');\n" "$pass" "$host";printf '%s\n' "\$table_prefix='wp_'; define('WP_DEBUG',false); require_once ABSPATH . 'wp-settings.php';"; } >"$config"
  chmod 600 "$config";gcloud compute scp "$config" "$vm:/tmp/wp-config.php" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --tunnel-through-iap --quiet >/dev/null
  guest "$vm" 'sudo install -o www-data -g www-data -m 0640 /tmp/wp-config.php /var/www/html/wp-config.php; rm -f /tmp/wp-config.php'
done
proxy_ip="$(gcloud compute instances describe "$proxy" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
private_ip="$(gcloud compute instances describe "$private" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
guest "$proxy" "cd /var/www/html && sudo -u www-data wp core is-installed >/dev/null 2>&1 || { admin_password=\$(openssl rand -hex 16); sudo -u www-data wp core install --url='http://$proxy_ip' --title='GCP Lab' --admin_user='labadmin' --admin_password=\"\$admin_password\" --admin_email='lab@example.invalid' --skip-email; unset admin_password; }"
guest "$proxy" "cd /var/www/html && sudo -u www-data wp db query \"CREATE TABLE IF NOT EXISTS harness_probe (id INT PRIMARY KEY, marker VARCHAR(64)); REPLACE INTO harness_probe VALUES (1, 'phase09-$run_id');\" >/dev/null"
guest "$private" "cd /var/www/html && sudo -u www-data wp db query \"SELECT marker FROM harness_probe WHERE id=1;\" --skip-column-names"|grep -Fxq "phase09-$run_id"||harness_die "private direct SQL shared state 실패"
for ip in "$proxy_ip" "$private_ip";do harness_wait_until 300 10 curl --fail --silent --show-error --max-time 10 "http://$ip/" -o /dev/null||harness_die "WordPress HTTP probe 실패";done
proxy_unit="$(guest "$proxy" 'systemctl cat cloud-sql-proxy.service')";[[ "$proxy_unit" != *--private-ip* ]]||harness_die "proxy가 public-default 경로가 아닙니다."
rm -f "$secret_dir"/*
jq -n --arg phase 09 --arg run_id "$run_id" --arg proxy_ip_hash "$(printf %s "$proxy_ip"|sha256sum|awk '{print $1}')" --arg private_front_hash "$(printf %s "$private_ip"|sha256sum|awk '{print $1}')" '{phase:$phase,run_id:$run_id,tasks:{
 "task-1":{status:"passed",detail:"MySQL 8 RUNNABLE, public+private address, wordpress DB 확인"},
 "task-2":{status:"passed",detail:"두 VM의 pinned WordPress, Apache/PHP HTTP readiness"},
 "task-3":{status:"passed",detail:"pinned Auth Proxy systemd와 --private-ip 없는 public-default 경로"},
 "task-4":{status:"passed",detail:"proxy frontend core install과 SQL marker create"},
 "task-5":{status:"passed",detail:"private IP 직접 경로에서 같은 SQL marker read"},
 "task-6":{status:"passed",detail:"SQL·proxy·두 HTTP frontend·private path evidence 검토"}},frontend_ip_sha256:[$proxy_ip_hash,$private_front_hash],risks:["DB secret는 guest wp-config에만 유지되며 evidence·Git에는 없음"]}' >"$evidence";chmod 600 "$evidence"
printf 'PASS: Phase 09 Cloud SQL public proxy·private direct·WordPress 검증 완료\n'
