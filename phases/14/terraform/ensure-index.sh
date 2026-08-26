#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
conf=/etc/apache2/conf-available/p14-php-index.conf
[[ -f /var/www/html/index.php && -f /etc/apache2/conf-available/p14-index.conf ]]
# 같은 server context의 DirectoryIndex는 누적되므로 기존 기본 index.html을 명시적으로 해제한다.
# 기존 startup이 p14-index.conf를 다시 써도 영향을 받지 않는, 뒤에 읽히는 별도 drop-in이다.
# 이미 생성된 immutable template/VM은 교체하지 않고 현재 실습의 Apache 설정만 수렴시킨다.
temporary="$(mktemp /etc/apache2/conf-available/p14-php-index.XXXXXX)"
trap 'rm -f "$temporary"' EXIT
printf '%s\n' 'DirectoryIndex disabled' 'DirectoryIndex index.php' >"$temporary"
chmod 644 "$temporary"
if ! cmp -s "$temporary" "$conf"; then mv "$temporary" "$conf"; fi
a2enconf p14-php-index
apache2ctl configtest
systemctl reload apache2
curl -fsS --max-time 10 http://127.0.0.1/ | grep -Fq "backend=$(hostname)"
printf 'PASS: Phase14 PHP directory index repaired without VM replacement\n'
