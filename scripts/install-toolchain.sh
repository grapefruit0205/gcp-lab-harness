#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/config/toolchain.lock.env"

task_data_home="${XDG_DATA_HOME:-${HOME:?HOME is required}/.local/share}"
task_install_root="$task_data_home/gcp-lab-harness/toolchains"
task_bin_dir="${HOME:?HOME is required}/.local/bin"

case "$(uname -s):$(uname -m)" in
  Linux:x86_64) ;;
  *)
    printf 'FAIL: 현재 lock은 Linux x86_64만 지원합니다: %s/%s\n' "$(uname -s)" "$(uname -m)" >&2
    exit 1
    ;;
esac

for required_value in \
  "$GCLOUD_VERSION" "$GCLOUD_ARCHIVE" "$GCLOUD_DOWNLOAD_URL" "$GCLOUD_SHA256" \
  "$TERRAFORM_VERSION" "$TERRAFORM_ARCHIVE" "$TERRAFORM_DOWNLOAD_URL" "$TERRAFORM_SHA256"; do
  [[ -n "$required_value" ]] || {
    printf 'FAIL: config/toolchain.lock.env에 빈 값이 있습니다.\n' >&2
    exit 1
  }
done
[[ "$GCLOUD_SHA256" =~ ^[a-f0-9]{64}$ && "$TERRAFORM_SHA256" =~ ^[a-f0-9]{64}$ ]] || {
  printf 'FAIL: toolchain SHA-256 lock 형식이 올바르지 않습니다.\n' >&2
  exit 1
}

mkdir -p "$task_install_root" "$task_bin_dir"
task_staging_dir="$(mktemp -d "$task_install_root/.install.XXXXXX")"
trap 'rm -rf -- "$task_staging_dir"' EXIT

download_and_verify() {
  local url="$1"
  local expected_sha="$2"
  local output="$3"

  curl --fail --location --retry 3 --output "$output" "$url"
  printf '%s  %s\n' "$expected_sha" "$output" | sha256sum --check --status || {
    printf 'FAIL: 다운로드 SHA-256이 lock과 다릅니다: %s\n' "$url" >&2
    exit 1
  }
}

gcloud_target="$task_install_root/google-cloud-cli/$GCLOUD_VERSION/google-cloud-sdk"
if [[ ! -x "$gcloud_target/bin/gcloud" ]]; then
  [[ ! -e "$gcloud_target" ]] || {
    printf 'FAIL: 불완전한 gcloud 설치 경로가 있습니다: %s\n' "$gcloud_target" >&2
    exit 1
  }
  gcloud_archive_path="$task_staging_dir/$GCLOUD_ARCHIVE"
  download_and_verify "$GCLOUD_DOWNLOAD_URL" "$GCLOUD_SHA256" "$gcloud_archive_path"
  mkdir -p "$task_staging_dir/gcloud" "$(dirname "$gcloud_target")"
  tar -xzf "$gcloud_archive_path" -C "$task_staging_dir/gcloud"
  [[ -x "$task_staging_dir/gcloud/google-cloud-sdk/bin/gcloud" ]] || {
    printf 'FAIL: Google Cloud CLI archive 구조를 확인할 수 없습니다.\n' >&2
    exit 1
  }
  mv "$task_staging_dir/gcloud/google-cloud-sdk" "$gcloud_target"
fi

terraform_target="$task_install_root/terraform/$TERRAFORM_VERSION/terraform"
if [[ ! -x "$terraform_target" ]]; then
  [[ ! -e "$terraform_target" ]] || {
    printf 'FAIL: 불완전한 Terraform 설치 파일이 있습니다: %s\n' "$terraform_target" >&2
    exit 1
  }
  terraform_archive_path="$task_staging_dir/$TERRAFORM_ARCHIVE"
  download_and_verify "$TERRAFORM_DOWNLOAD_URL" "$TERRAFORM_SHA256" "$terraform_archive_path"
  mkdir -p "$task_staging_dir/terraform" "$(dirname "$terraform_target")"
  unzip -q "$terraform_archive_path" -d "$task_staging_dir/terraform"
  [[ -f "$task_staging_dir/terraform/terraform" ]] || {
    printf 'FAIL: Terraform archive 구조를 확인할 수 없습니다.\n' >&2
    exit 1
  }
  chmod 755 "$task_staging_dir/terraform/terraform"
  mv "$task_staging_dir/terraform/terraform" "$terraform_target"
fi

ln -sfn "$gcloud_target/bin/gcloud" "$task_bin_dir/gcloud"
ln -sfn "$gcloud_target/bin/bq" "$task_bin_dir/bq"
ln -sfn "$gcloud_target/bin/gsutil" "$task_bin_dir/gsutil"
ln -sfn "$terraform_target" "$task_bin_dir/terraform"

installed_gcloud_version="$("$task_bin_dir/gcloud" version --format=json | jq -r '."Google Cloud SDK"')"
installed_terraform_version="$("$task_bin_dir/terraform" version -json | jq -r '.terraform_version')"
[[ "$installed_gcloud_version" == "$GCLOUD_VERSION" ]] || {
  printf 'FAIL: gcloud 설치 버전이 lock과 다릅니다: %s\n' "$installed_gcloud_version" >&2
  exit 1
}
[[ "$installed_terraform_version" == "$TERRAFORM_VERSION" ]] || {
  printf 'FAIL: Terraform 설치 버전이 lock과 다릅니다: %s\n' "$installed_terraform_version" >&2
  exit 1
}

printf 'PASS: Google Cloud CLI %s 설치: %s\n' "$installed_gcloud_version" "$task_bin_dir/gcloud"
printf 'PASS: Terraform %s 설치: %s\n' "$installed_terraform_version" "$task_bin_dir/terraform"
