#!/usr/bin/env python3
"""SSH stdin 비밀 전달·guest 설치. 출력은 고정 stage/reason/code JSON만 허용한다."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

WEBROOT = Path('/var/www/html')
CONFIG_MARKER = Path('/var/lib/p09-managed-config.json')
STAGES = {'input', 'privilege', 'php', 'config', 'config-lint', 'db-ready',
          'wp-cli', 'wp-install', 'wp-installed', 'complete'}
REASONS = {'ok', 'invalid-input', 'privilege-required', 'file-exists', 'permission',
           'missing-command', 'timeout', 'command-failed', 'php-fatal', 'db-access-denied',
           'db-missing', 'db-connect', 'db-query', 'db-privilege-denied', 'config-drift', 'internal'}

# DB 비밀번호는 php argv/env가 아니라 stdin으로만 전달한다.
# mysqli 옵션은 connect 이전에 설정한다. 오류 메시지/입력은 출력하지 않는다.
DB_CHECK = r'''
mysqli_report(MYSQLI_REPORT_OFF);
$p=json_decode(stream_get_contents(STDIN),true);
$db=mysqli_init();
$db->options(MYSQLI_OPT_CONNECT_TIMEOUT,5);
$db->options(MYSQLI_OPT_READ_TIMEOUT,5);
if (!@$db->real_connect($p['db_host'],'root',$p['db_password'],'wordpress',3306)) {
    echo json_encode(array('mysql_errno'=>$db->connect_errno));
    exit($db->connect_errno===1044 ? 35 : ($db->connect_errno===1045 ? 32 : ($db->connect_errno===1049 ? 33 : 31)));
}
$result=@$db->query('SELECT 1');
if (!$result || $result->fetch_row()[0] != '1') { echo json_encode(array('mysql_errno'=>$db->errno)); exit(34); }
$db->close();
'''


class InstallError(Exception):
    def __init__(self, reason, code=None, mysql_errno=None):
        self.reason, self.code, self.mysql_errno = reason, code, mysql_errno


def command(arguments, data=None, timeout=30, allowed=(0,)):
    try:
        result = subprocess.run(arguments, input=data, text=True, capture_output=True,
                                cwd=WEBROOT, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        raise InstallError('timeout') from None
    except FileNotFoundError:
        raise InstallError('missing-command') from None
    if result.returncode not in allowed:
        # 분류에만 사용하며 child stdout/stderr 원문은 어떤 경우에도 출력하지 않는다.
        error = (result.stderr + result.stdout).lower()
        reason = 'command-failed'
        for needle, label in (('access denied for user', 'db-access-denied'),
                              ('error establishing a database connection', 'db-connect'),
                              ('permission denied', 'permission'), ('fatal error', 'php-fatal')):
            if needle in error:
                reason = label
                break
        mysql_errno = None
        if DB_CHECK in arguments:
            try:
                value = json.loads(result.stdout)
                if (set(value) == {'mysql_errno'} and type(value['mysql_errno']) is int and
                        0 <= value['mysql_errno'] <= 65535):
                    mysql_errno = value['mysql_errno']
            except (ValueError, TypeError):
                pass
        raise InstallError(reason, result.returncode, mysql_errno)
    return result.returncode


def managed_config(payload, gid):
    path = WEBROOT / 'wp-config.php'
    digest = lambda data: hashlib.sha256(data).hexdigest()
    content = payload['config'].encode()
    hashes = [digest(content)]
    if path.is_symlink() or CONFIG_MARKER.is_symlink():
        raise InstallError('config-drift')
    if path.exists():
        if not CONFIG_MARKER.exists():
            raise InstallError('file-exists')
        marker = json.loads(CONFIG_MARKER.read_text())
        old_hash = digest(path.read_bytes())
        if (marker.get('run_id') != payload['run_id'] or old_hash not in marker.get('hashes', []) or
                path.stat().st_nlink != 1):
            raise InstallError('config-drift')
        hashes.append(old_hash)
    elif CONFIG_MARKER.exists():
        if json.loads(CONFIG_MARKER.read_text()).get('run_id') != payload['run_id']:
            raise InstallError('config-drift')
    def marker_write(values):
        fd, temporary = tempfile.mkstemp(dir=CONFIG_MARKER.parent, prefix='.p09-config-')
        try:
            with os.fdopen(fd, 'w') as stream:
                json.dump({'run_id': payload['run_id'], 'hashes': values}, stream)
            os.replace(temporary, CONFIG_MARKER)
        finally:
            Path(temporary).unlink(missing_ok=True)
    # 두 파일 교체 사이 중단되더라도 이전/새 hash를 인식하며, 관리 밖 파일은 거부한다.
    marker_write(hashes)
    fd, temporary = tempfile.mkstemp(dir=WEBROOT, prefix='.p09-config-')
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(content)
        os.chown(temporary, 0, gid)
        os.chmod(temporary, 0o640)
        os.replace(temporary, path)
        marker_write(hashes[:1])
    finally:
        Path(temporary).unlink(missing_ok=True)


def install(payload):
    import pwd  # Linux guest 전용; 호스트의 계획/검증 import는 Windows에서도 가능하게 유지한다.
    stage = 'input'
    try:
        if (not isinstance(payload, dict) or type(payload.get('install')) is not bool or
                not all(isinstance(payload.get(key), str) and payload[key]
                        for key in ('run_id', 'config', 'url', 'admin_password', 'db_host', 'db_password'))):
            raise InstallError('invalid-input')
        stage = 'privilege'
        if os.geteuid() != 0:
            raise InstallError('privilege-required')
        stage = 'php'
        command(['php', '-r', 'exit(extension_loaded("mysqli") ? 0 : 1);'])
        stage = 'config'
        path = WEBROOT / 'wp-config.php'
        managed_config(payload, pwd.getpwnam('www-data').pw_gid)
        prefix = ['sudo', '-n', '-H', '-u', 'www-data']
        stage = 'config-lint'
        command(prefix + ['php', '-l', str(path)])
        stage = 'db-ready'
        deadline = time.monotonic() + 120
        db_input = json.dumps({key: payload[key] for key in ('db_host', 'db_password')})
        while True:
            try:
                command(prefix + ['php', '-r', DB_CHECK], db_input, timeout=15)
                break
            except InstallError as error:
                reason = {31: 'db-connect', 32: 'db-access-denied', 33: 'db-missing',
                          34: 'db-query', 35: 'db-privilege-denied'}.get(error.code, error.reason)
                if reason not in {'db-connect', 'db-access-denied', 'timeout'} or time.monotonic() >= deadline:
                    raise InstallError(reason, error.code, error.mysql_errno) from None
                time.sleep(5)
        wp = prefix + ['wp', '--path=' + str(WEBROOT)]
        stage = 'wp-cli'
        command(wp + ['--version'])
        installed = command(wp + ['core', 'is-installed'], allowed=(0, 1)) == 0
        if payload['install'] and not installed:
            stage = 'wp-install'
            command(wp + ['core', 'install', '--url=' + payload['url'], '--title=GCP Lab',
                          '--admin_user=labadmin', '--admin_email=lab@example.invalid',
                          '--skip-email', '--prompt=admin_password'], payload['admin_password'] + '\n', timeout=90)
        stage = 'wp-installed'
        command(wp + ['core', 'is-installed'])
        return {'stage': 'complete', 'reason': 'ok', 'exit_code': 0}
    except InstallError as error:
        result = {'stage': stage, 'reason': error.reason, 'exit_code': error.code}
        if error.mysql_errno is not None:
            result['mysql_errno'] = error.mysql_errno
        return result
    except FileExistsError:
        return {'stage': stage, 'reason': 'file-exists', 'exit_code': None}
    except PermissionError:
        return {'stage': stage, 'reason': 'permission', 'exit_code': None}
    except Exception:
        return {'stage': stage, 'reason': 'internal', 'exit_code': None}


def main():
    os.umask(0o077)
    import resource
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        result = {'stage': 'input', 'reason': 'invalid-input', 'exit_code': None}
    else:
        result = install(payload)
    # guest 동작 성공 여부는 JSON으로 전송하고 호출자가 fail-closed 검증한다.
    print(json.dumps(result))


if __name__ == '__main__':
    main()
