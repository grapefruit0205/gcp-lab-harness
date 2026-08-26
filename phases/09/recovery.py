#!/usr/bin/env python3
"""Phase09 로컬 승인·재계획·실패 보존 기록. Cloud 변경 명령을 실행하지 않는다."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

import sql_lab as lab


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def state_sha(run):
    path = run / 'work/terraform.tfstate'
    return sha(path) if path.exists() else None


def archive(run, category, names):
    parent = run / category
    parent.mkdir(mode=0o700, exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-'), dir=parent))
    for name in names:
        path = run / name
        if path.is_file():
            target = destination / name
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            shutil.copy2(path, target)
    # terraform.tfstate는 여기로 복사/이동하지 않는다. 동일 work 경로에서 그대로 사용한다.
    return destination


def baseline(run, inputs):
    if (run / 'resource-identities.json').exists():
        rows = lab.owned(inputs, run)
    else:
        enabled = lab.cloud(inputs, 'services', 'list', '--enabled')
        rows = lab.inventory(inputs, sql_enabled=any(r['config']['name'] == 'sqladmin.googleapis.com' for r in enabled))
        lab.require(not any(rows.values()), '초기 계획과 동명 Cloud 리소스 충돌')
    plan = lab.read_json(run / 'phase-09-plan.json')
    lab.guard_plan(plan, inputs)
    created = lab.planned_created_keys(plan, inputs)
    current = lab.identities(rows, inputs)
    lab.require(not (set(current) & set(created)), 'create 계획과 기존 Cloud identity 충돌')
    lab.write_json(run / 'plan-baseline.json', {
        'phase': '09', 'run_id': inputs['run_id'], 'state_sha256': state_sha(run),
        'identities': current, 'created_keys': sorted(created), 'plan_json_sha256': sha(run / 'phase-09-plan.json'),
    })


def bundle(run):
    manifest = lab.read_json(run / 'manifest.json')
    action_hash, terraform_hash = sha(run / 'action-plan.json'), sha(run / 'phase-09.tfplan')
    value = {'schema_version': 1, 'phase': '09', 'run_id': manifest['run_id'],
             'terraform': {'path': 'phase-09.tfplan', 'sha256': terraform_hash},
             'action_plan': {'path': 'action-plan.json', 'sha256': action_hash}}
    lab.write_json(run / 'plan-bundle.json', value)
    manifest['status'] = 'planned'
    manifest['plan'] = {'terraform_sha256': terraform_hash, 'action_plan_sha256': action_hash,
                        'bundle_sha256': sha(run / 'plan-bundle.json')}
    for check in manifest['checks']:
        check['status'] = 'pending'
    # 과거 cleanup_required는 history에 남기고 새 승인에는 삭제 계약을 넣지 않는다.
    manifest['cleanup'] = {'status': 'not_started', 'remaining_resource_count': 0}
    lab.write_json(run / 'manifest.json', manifest)


def before_apply(run, inputs):
    value = lab.read_json(run / 'plan-bundle.json')
    lab.require(value['terraform']['sha256'] == sha(run / 'phase-09.tfplan'), '저장 Terraform plan SHA 불일치')
    saved = lab.read_json(run / 'plan-baseline.json')
    lab.require(saved['plan_json_sha256'] == sha(run / 'phase-09-plan.json'), 'plan JSON SHA 불일치')
    lab.require(saved['state_sha256'] == state_sha(run), '계획 이후 state 변경; 같은 run replan 필요')
    lab.guard_plan(lab.read_json(run / 'phase-09-plan.json'), inputs)
    # 존재하던 resource가 바뀌거나, create 대상 이름이 선점돼도 apply 전에 중단한다.
    enabled = lab.cloud(inputs, 'services', 'list', '--enabled')
    rows = lab.inventory(inputs, sql_enabled=any(r['config']['name'] == 'sqladmin.googleapis.com' for r in enabled))
    lab.require(lab.identities(rows, inputs) == saved['identities'], '계획 이후 Cloud identity 변경; replan 필요')


def require_apply(run):
    receipt = lab.read_json(run / 'apply-completed.json')
    lab.require(receipt['bundle_sha256'] == sha(run / 'plan-bundle.json') and
                receipt['state_sha256'] == state_sha(run), '현재 계획 apply 완료 기록/state 불일치; replan/apply 필요')


def verified(run):
    evidence = lab.read_json(run / 'evidence/phase-09-machine.json')
    contract = lab.read_json(run / 'source-contract.json')
    lab.require(evidence['phase'] == '09' and all(evidence['tasks'].get(task['id'], {}).get('status') == 'passed'
                for task in contract['source_tasks']), 'Task 전체 통과 증거 없음')
    manifest = lab.read_json(run / 'manifest.json')
    lab.require(evidence['run_id'] == manifest['run_id'], '다른 run 증거')
    manifest['status'] = 'verified'
    for check in manifest['checks']:
        check.update(status='passed', evidence=evidence['tasks'][check['id']]['detail'])
    lab.write_json(run / 'manifest.json', manifest)
    lab.write_json(run / 'command-code-result.json', {
        'phase': 'phase-09', 'status': 'waiting_extension_review',
        'summary': 'Phase09 Task1–6 machine verification 완료; 리소스 유지',
        'session_id': 'gcp-harness-' + manifest['run_id'] + '-phase-09',
        'commands_run': ['terraform apply saved plan', 'phases/09/verify.sh --run'],
        'checks': [{'name': task['id'] + ': ' + task['title'], 'status': 'passed',
                    'detail': evidence['tasks'][task['id']]['detail']} for task in contract['source_tasks']],
        'risks': evidence.get('risks', []), 'next_action': 'extension_review',
    })


def diagnose(run, inputs):
    # 읽기 실패는 목록0으로 바꾸지 않는다. 비밀번호/원시 serial/log/config는 수집하지 않는다.
    rows = lab.owned(inputs, run)
    summary = {'phase': '09', 'run_id': inputs['run_id'], 'read_only': True,
               'counts': {kind: len(items) for kind, items in rows.items()},
               'identities': lab.identities(rows, inputs), 'guests': {}, 'sql': []}
    for sql in rows['sql']:
        settings = sql.get('settings', {})
        summary['sql'].append({key: sql.get(key) for key in ('name', 'state', 'databaseVersion', 'region')})
        summary['sql'][-1].update(tier=settings.get('tier'), ssl_mode=settings.get('ipConfiguration', {}).get('sslMode'),
                                  connector_enforcement=settings.get('connectorEnforcement'))
    for vm in rows['vm']:
        name = vm['name']
        checks = {'startup-ready': 'test -f /var/lib/p09-wordpress-ready',
                  'apache-active': 'systemctl is-active apache2 >/dev/null',
                  'php-mysqli': "php -r 'exit(extension_loaded(\"mysqli\") ? 0 : 1);'"}
        if name.startswith('wordpress-proxy-'):
            checks['proxy-active'] = 'systemctl is-active cloud-sql-proxy >/dev/null'
        summary['guests'][name] = {'status': vm.get('status'), 'checks': {}}
        for key, command in checks.items():
            try:
                lab.guest(inputs, name, command)
                result = 'passed'
            except lab.LabError:
                result = 'failed-or-unreachable'
            summary['guests'][name]['checks'][key] = result
    lab.write_json(run / 'evidence/diagnosis.json', summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['archive', 'baseline', 'bundle', 'before-apply', 'start-apply',
                                              'applied', 'require-apply', 'verified', 'failure', 'diagnose'])
    parser.add_argument('--run-dir', required=True)
    parser.add_argument('--stage', choices=['apply', 'initialization', 'verify'])
    parser.add_argument('--code', type=int)
    args = parser.parse_args()
    run = Path(args.run_dir)
    inputs = lab.read_json(run / 'work/phase-09.auto.tfvars.json')
    lab.validate_inputs(inputs)
    operation = args.operation
    if operation == 'archive':
        archive(run, 'revisions', ['manifest.json', 'action-plan.json', 'plan-bundle.json', 'plan-baseline.json',
                                  'phase-09.tfplan', 'phase-09-plan.json', 'apply-started.json', 'apply-completed.json',
                                  'resource-identities.json', 'recovery.json', 'work/main.tf', 'work/.terraform.lock.hcl'])
    elif operation == 'baseline':
        baseline(run, inputs)
    elif operation == 'bundle':
        bundle(run)
    elif operation == 'before-apply':
        before_apply(run, inputs)
    elif operation in {'start-apply', 'applied'}:
        filename = 'apply-started.json' if operation == 'start-apply' else 'apply-completed.json'
        lab.write_json(run / filename, {'bundle_sha256': sha(run / 'plan-bundle.json'), 'state_sha256': state_sha(run)})
    elif operation == 'require-apply':
        require_apply(run)
    elif operation == 'verified':
        verified(run)
    elif operation == 'failure':
        lab.write_json(run / 'recovery.json', {'phase': '09', 'run_id': inputs['run_id'], 'stage': args.stage,
                                             'exit_code': args.code, 'state_preserved': True, 'automatic_destroy': False,
                                             'next': 'diagnose → repair → replan → approval → apply/verify'})
    else:
        diagnose(run, inputs)


if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except (lab.LabError, OSError, ValueError, KeyError, TypeError) as error:
        print('FAIL: ' + (str(error) if isinstance(error, lab.LabError) else '복구 기록/입력 오류; 원문 생략'), file=sys.stderr)
        sys.exit(1)
