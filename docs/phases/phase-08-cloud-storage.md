# Phase 08 — Cloud Storage

- 원본: `references/google-cloud-labs-ko/labs/08.Cloud Storage_KR.md`
- 비용 위험: 중간
- 주요 서비스: Cloud Storage ACL/IAM, CSEK, lifecycle, versioning, rsync

## 목적

객체 ACL, 고객 제공 암호화 키(CSEK), 키 순환, lifecycle, versioning, 디렉터리 동기화를 비밀정보 노출 없이 재현하고 데이터 무결성까지 검증한다.

## 범위와 원본 매핑

| 원본 Task | 분류 | 자동화·증거 |
|---|---|---|
| Task 1. 준비하기 | automated | 버킷과 checksum이 고정된 sample fixture 준비 |
| Task 2. 접근 제어 목록(ACLs) | automated | 객체 ACL 적용·조회·다운로드 success/denial |
| Task 3. 고객 제공 암호화 키(CSEK) | automated | 메모리/권한 제한 임시 파일의 키로 암호화·복호화 |
| Task 4. CSEK 키 순환하기 | automated | rewrite, 구키 실패·신키 성공, 임시 구성 제거 |
| Task 5. 라이프사이클 관리 사용 설정하기 | automated | versioned JSON policy apply·describe |
| Task 6. 버전 관리 사용 설정하기 | automated | 세대 생성·목록·오래된 세대 복구와 hash 확인 |
| Task 7. 디렉터리를 버킷과 동기화하기 | automated | nested tree sync와 object set/hash 비교 |
| Task 8. Review | cli-equivalent | 보안·정책·세대·동기화 결과 검토 |

## 구현 작업

1. uniform bucket-level access와 ACL 실습의 호환성을 preflight해 명시적 모드를 선택한다.
2. sample fixture 출처·checksum과 모든 객체 동작을 plan에 고정한다.
3. CSEK는 프로세스 수명 또는 권한 제한 임시 파일에만 만들고 trap에서 지운다.
4. 구키·신키의 성공/실패 matrix로 rewrite 완료를 검증한다.
5. lifecycle, versioning, sync 결과를 API JSON과 local manifest로 비교한다.

## 실행 계약

Command Code `cmd`는 모델 override 없이 Cloud Storage 동작을 수행한다. CSEK 값은 prompt, events, shell trace, Git 파일에 출력하지 않는다. 기계 검증 결과에는 키 fingerprint도 원문 대신 불가역 hash prefix만 사용한다.

## 검증 게이트

- ACL의 허용·거부 결과와 객체 metadata가 기대와 일치한다.
- 키 순환 뒤 구키 접근은 실패하고 신키 복호화·hash 비교는 성공한다.
- lifecycle JSON, versioning 상태, generation count가 plan과 일치한다.
- sync 대상 object set과 각 hash가 local tree와 일치한다.
- Extension은 Storage read-only 조회와 secret scan 후 사용자에게 판정을 보고한다.

## 안전·비용 가드레일

- public ACL을 만들지 않으며 test principal 범위만 사용한다.
- CSEK·키 구성·복호화 header를 원시 로그와 Git에서 제외한다.
- lifecycle 삭제 동작은 run bucket에만 적용하고 시간 의존 삭제를 완료 증거로 삼지 않는다.
- 모든 version을 포함해 object를 삭제한 뒤 bucket을 정리한다.

## 완료 조건

- Task 1–8 coverage와 ACL·CSEK·lifecycle·versioning·sync 증거가 있다.
- Extension secret scan과 read-only 검증이 통과하고 사용자가 승인했다.
- cleanup 후 bucket/object generation/test binding이 0이다.

## Command Code·Extension handoff 지시

Command Code는 비밀 값을 redaction한 구조화 결과만 반환한다. Extension은 키 자체를 요청하거나 출력하지 않고 metadata, success/denial, hash 증거로만 검증하며 사용자 승인 전 cleanup을 지시하지 않는다.

## Git 종료 조건

`Phase 08: Cloud Storage 보안과 수명주기 자동화 및 검증 완료` 커밋·push 확인 후 Phase 09를 시작한다.
