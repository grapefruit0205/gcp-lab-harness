# OPEN QUESTIONS — registered, not remembered

Rule: anything unresolved gets a row here the moment it surfaces. A question is closed only by linking the decision (or finding) that resolved it — never by silently disappearing.

| ID | Question | Opened | Status |
|---|---|---|---|
| Q-001 | GitHub 저장소 이름과 공개 범위(public/private)는 무엇으로 할까? | 2026-08-25 | closed — D-015 |
| Q-002 | 자동화 실행에 사용할 Google Cloud 프로젝트와 연결된 결제 계정은 무엇인가? | 2026-08-25 | observed — 유일한 ACTIVE project와 billing 연결 확인, 실제 apply 대상 확정은 A-003 |
| Q-003 | 공유 저장소에 적용할 라이선스는 무엇인가? | 2026-08-25 | open |
| Q-004 | 제안한 `codex-extension-verifier` 프로젝트 pin을 ballast 규칙 카탈로그에 기록할까? | 2026-08-25 | closed — D-007 및 `.claude/ballast.rules.json` |
| Q-005 | 제안한 `command-code-runner-fixed-model` 프로젝트 pin을 ballast 규칙 카탈로그에 기록할까? | 2026-08-25 | open |
| Q-006 | 로컬·GitHub 커밋에 사용할 Git 작성자 이름과 이메일은 무엇인가? | 2026-08-25 | closed — 사용자 소유 기존 로컬 저장소 3곳의 일치 설정 사용 |
| Q-007 | Phase 07을 원문처럼 실제 사용자 두 계정으로 진행할 것인가? | 2026-08-26 | closed — D-024, 사용자 계정 2 지정. 실제 인증·새 plan 승인은 실행 전 별도 확인 |
| Q-008 | Terraform 밖 `junseok-lab` bucket·기존 `mynet-us-vm-…` snapshot·`lampstack`/`read-bucket-objects` SA·`privatenet-allow-ssh` firewall도 이전 실습 삭제 대상인가? | 2026-08-26 | closed — D-029, 사용자가 남은 5개도 전부 삭제하라고 명시 |
| Q-009 | Phase08 수정본 run `p08-260826-c924`, bundle SHA `1222d79e290b309f117390ff457b5da1aa2577fef1a30bec32aa770ef575450a`를 apply·실습 재검증할까? | 2026-08-26 | closed — D-031, 사용자가 새 exact SHA의 재apply·실습 검증에 “ㅇㅇ”로 승인 |
| Q-010 | Phase09 run `p09-260826-5d82`, bundle SHA `d418a5b7ed219126889882f2e1e296b1e34dcea26b256dc329774119fb561cf4`의 Terraform16개 create와 SQL·WordPress 검증을 실행할까? API3개 유지·실패 cleanup·PSA 최대4일 지연·자동 만료 없음 포함 | 2026-08-26 | closed — D-033, 사용자가 해당 exact plan의 apply·검증에 “ㄱ”으로 승인 |
| Q-011 | Phase09 WordPress 설정 단계 CLI/guest 실패의 구체 원인은 무엇인가? | 2026-08-26 | resolved-current-run — 실제 root USAGE/DB1044를 진단하고 D-041의type 명시·역할/비밀번호 분리 요청 후 실제Task1–6/SQL/HTTP가통과했다. 근거: PRODUCT-TRUTH.md의 Phase09 실제검증성공 항목·run evidence/phase-09-machine.json. 과거미보관errno와400의단일backend원인까지동일하다고확정하지않음 |
| Q-012 | Phase09 PSA producer가 연결을 해제해 남은 전용 VPC/range/connection3개를 정리할 수 있는가? | 2026-08-26 | open — 실제 삭제 Error9/producer 사용 중. VM/disk/SQL/SA/IAM0 확인, state·승인 소스 유지 |
| Q-013 | 새 Phase09 run `p09-260826-eb03`, bundle SHA `bc763bc4bec0092bdbd0a1fd8efc3e564df8a2ed6c0952bb43762fce102fb7ab`의 16create/0change/0destroy와 보완된 SQL·WordPress 검증을 실행할까? API3개 유지·실패 cleanup·PSA 지연·자동 만료 없음 포함 | 2026-08-26 | closed — D-035, exact 계획 apply·실제 검증에 사용자가 “ㄱㄱㄱ”으로 승인 |
| Q-014 | D-036의 보존·진단·수정·재apply 원칙을 실제 자동화의 모든 실행/실패 경로에 어떻게 이관할까? | 2026-08-26 | partial — Phase09 전용 recovery의 실제 보존 관측은 기존 기록과 같다. 추가로 Phase10–15를 별도 safe adapter로 이관하고40개 회귀·TF mock6개·gate로 검증했다(Cloud 미검증). Phase01–08과 기존 shared adapter/config의 auto-destroy 경로는 미이관이므로 실행 금지 유지. Phase08/09 승인 소스는 보존했다 |
| Q-015 | `terraform-repair-before-destroy` 규칙안을 프로젝트 `.claude/ballast.rules.json`에 pin할까? | 2026-08-26 | closed — D-037, 사용자가 표시된 exact entry에 “ㅇㅇㅇ ㄱㄱ”으로 승인하여 catalog에 저장 |
| Q-016 | Phase09 기존 run `p09-260826-eb03` 복구 bundle SHA `3d8e72d72c34a5b2b97097490959b0ed9d4b2a55d42ddcdbb5020d170f9483e2`의 10create/0update/0delete/6no-op와 실제 SQL/WordPress 검증을 실행할까? 실패 보존·기존 state 재사용·과금 지속·Phase08 유지 포함 | 2026-08-26 | closed — D-039, 사용자가 “ㅇㅇ apply ㄱㄱ”으로 exact 계획 apply·실제 검증 승인 |
| Q-017 | 같은 Phase09 run `p09-260826-eb03`, bundle SHA `7ce28fea77bfd9f4e1eb8076c848c489411a9494bed7208a4f7e44345d6d758d`의16no-op/추가·변경·삭제·교체0과 root@%의 cloudsqlsuperuser DB 관리자 역할 추가·난수 교체·SQL/WordPress 재검증을 실행할까? 기존 역할 회수 없음·기존 state/환경 보존·과금 지속·Phase08 유지 포함 | 2026-08-26 | closed — D-040, 사용자가 리소스 삭제 없이 DB 권한 보완 적용·실제 동작 확인을 명시적으로 승인 |
| Q-018 | Phase09 동일 run `p09-260826-eb03`, bundle SHA `e701120a9f6d8ef03a5df23bf41f8d0e056d6238cd7d7ca3dee37ce14658e707`의16no-op·BUILT_IN 명시/비밀번호 없는 역할 요청 후 별도 비밀번호 갱신·실제 SQL/WordPress 검증을 적용할까? 같은 root 관리자 역할 범위·삭제/교체 없음·실패 보존·과금 지속·Phase08 유지 | 2026-08-26 | closed — D-041, exact 수정 계획 적용·검증 제안에 사용자가 “400 으로 실패하지 않게 해줘”라고 수정 실행 요청 |
| Q-019 | 제시한 `phase-task-console-check` exact catalog entry를 저장할까? | 2026-08-26 | open — D-043의 완료 보고 요구는 AGENTS·문서·prompt·출력 경로에 반영했다. ballast:pin의 id/title/8개 keywords/body를 제시했으며 catalog 저장만 확인 대기. 기존2개 규칙 보존 |
| Q-020 | 현재 Phase09 `p09-260826-eb03`의 종료 잔여 PSA를 정리할 수 있는가? | 2026-08-26 | open — D-042 명시적 destroy 후 SQL/VM/disk/subnet/firewall/SA0, producer 사용 중 Error9로 VPC·할당 범위·연결3개 잔여. state/로그 보존, 해제 후 같은 run 정리 필요. 이전 run의 Q-012와 구분하며 강제 peering 삭제/state 제거 금지 |
| Q-021 | Phase10–15 새 보존형 구현의 실제 Cloud E2E와 원문 대비 남은 차이는 무엇인가? | 2026-08-26 | partial — D047 후 Phase10/11/12 실제 검증 통과. Phase12는 단일 터널 장애 실험 후 잔여 경로 정상, Task8 정리 별도. Phase13 25개 생성 후 중지VM 직렬로그 수집 실패를 보완해49회귀 통과, 25no-op/2fc9f4… 동일run 재apply 중. Phase14/15 실기 전·승인 대기 아님. 전체golden/UI·builder삭제 등의 경계는 감사 문서 참조 |
| Q-022 | Phase10 run `p10-260826-2106`, bundle SHA `da21cf4a35d39146664507e7b2545b07945f3389fb0a04a8d818a844c4efd5d9`의 US dataset1create·fixture 적재·8쿼리 검증을 실행할까? 기존 변경/삭제/교체0, 실패 보존, 쿼리1GiB/개 상한·저장/전송 별도 비용·테이블 기본 만료1일 포함 | 2026-08-26 | closed — D-046: 사용자가 제시된 exact 계획의 apply·실제 검증에 “ㄱㄱ”으로 승인 |
| Q-023 | Phase10 동일 run `p10-260826-2106`, 수정 bundle SHA `eb50a9f987064e100984e7b79e2b9f552ade151eeba51451423f1d9784dbf106`를 재apply·검증할까? Terraform dataset1no-op·삭제/교체0, 같은 sampleinfotable만 useAvroLogicalTypes=true/WRITE_TRUNCATE로 원본 데이터·스키마 재적재하고8쿼리 검증 | 2026-08-26 | closed — D-047: 사용자가 Phase15까지 구현/apply/오류수정을 재질문 없이 명시 위임. 기술적 저장계획/SHA/소유권/비용 검사는 유지 |

## Readings in force — assumed, not decided

Rule: when work proceeds on a reading the user never confirmed (silence, a subject change, an "ok" that could mean anything), it is registered here with the user's words quoted — never in DECISIONS.md. One-way-door actions wait while a row is open. A row closes into a `D-` entry on confirmation, or is dropped — and what was built on it swept — on contradiction. (Protocol: ballast decision-ledger skill, *Provisional readings*.)

| ID | User's words (verbatim) | Our reading (`assumed`) | Breaks if wrong | Ends when | Relied on in |
|---|---|---|---|---|---|
| A-001 | "repo 를 만들고 git 에 각 과정이 완료될때마다 commit" — 2026-08-25 | 로컬 저장소 이름은 임시로 `gcp-lab-harness`를 사용한다 | 사용자가 원하는 최종 GitHub 저장소명과 다를 수 있다 | closed — D-011 | 로컬 저장소 및 설계 문서 |
| A-002 | "gcp monitoring이랑 logging mcp 도 필요하지?" — 2026-08-25 | 공식 Cloud Monitoring·Logging remote MCP를 VS Code Codex Extension의 read-only 보조 검증 계층으로 포함한다 | 사용자가 local observability MCP 또는 MCP 미사용을 원할 수 있다 | MCP 실제 등록 직전 | MCP 연동 설계와 Phase 04·07·11·13 검증 |
| A-003 | "gcp 계정 연동으로 cloud apply 하는 것이 목적이야" — 2026-08-25 | 로그인 후 유일하게 조회된 ACTIVE 프로젝트 `kdt5-05`를 실습 apply 대상으로 사용한다 | 다른 프로젝트를 원하면 실제 Cloud 리소스를 잘못된 프로젝트에 만들 수 있다 | closed — D-013 | 전용 gcloud configuration, local allowlist, Terraform account-check |
| A-004 | "ㄱㄱ" — 2026-08-26, Phase 08 구현 완료·apply/commit/push 미실행 보고 직후 | Phase 08의 실제 실행·검증과 관련 변경 게시까지 진행하려는 의도로 읽고 새 계획을 준비한다 | 저장 plan 검토 전 지출·임시 공개 또는 원치 않는 Git 게시가 될 수 있다 | closed — D-030, 사용자가 exact SHA의 apply/검증·stage/commit/push에 “ㅇㅇ”로 승인 | Phase 08 run p08-260826-8c1d |
