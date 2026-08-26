# memory/ — gcp-lab-harness brain

Purpose: this folder is the durable memory for gcp-lab-harness. Conversations forget; this folder does not. What is recorded here survives topic changes, session resets, and context compaction.

## File map

| File | What | Write rule |
|---|---|---|
| `DECISIONS.md` | Confirmed decisions | Append-only. Supersede protocol — never edit past entries |
| `OPEN-QUESTIONS.md` | Unresolved items awaiting a decision, and readings in force the user has not confirmed | Two tables. Close each row with a link to the resolving decision, or drop it |
| `SESSION-LOG.md` | What happened, per working session | Append, dated |
| `PRODUCT-TRUTH.md` | What the product actually does (if applicable) | Evidence + date only. Three sections: implemented / not / excluded |
| `knowledge/` | 검증된 외부 도구·플랫폼 지식 | 검증 게이트를 통과한 사실만 기록 |
| `goal/gcp-lab-harness.md` | 목표 구조·근거·완료 기준 | 목표 파이프라인의 canonical copy |
| `CHECKPOINT.md` | 현재 작업의 30초 복귀 지점 | 큰 작업 단위 완료 또는 세션 종료 전에 갱신 |
| `checkpoints/` | 이전 체크포인트 기록 | append-only 보관 |
| `HANDOFF.md` | 다음 세션에 전달할 일회성 실행 지시 | 읽고 실행한 직후 삭제 |
| `../.claude/skills/phase09-mysql-repair/SKILL.md` | 실기 검증한 Phase09 MySQL 보존 복구 절차 | 성공 근거·한계·날짜와 함께 유지, Cloud 변경은 새 승인 경계 준수 |
| `../docs/console-checks.md` | 각 Phase 완료 시 사용자에게 제공할 Task별 콘솔 확인 공통 안내 | Phase별 표·출력 도구·보고 prompt·coverage 검사와 함께 유지 |
| `../docs/console/` | 원문 Task 아래167개 제목·번호 절차를 포함한221개 상세 콘솔 확인 항목 | 원문은 보존하며 클릭 경로·판정·미구현 경계를 코드와 대조 |
| `../docs/phase-10-15-execution.md` | Phase10–15 보존형 실행·승인·검증·복구·종료 안내 | 실제 Cloud 성공과 로컬 검증을 구분 |
| `../docs/audits/phase-10-15-repair.md` | Phase10–15 오류 수정·남은 차이·리허설 증거 | 코드·테스트 근거와 함께 갱신 |

## Operating principles

1. **Record in-session.** Decisions and important facts are written the moment they appear, not at the end. Zero loss.
2. **User-confirmed vs AI-proposed are always distinguished.** A proposal the user hasn't confirmed is not a decision — and neither is your reading of a non-answer; that is registered in OPEN-QUESTIONS.md as `assumed`.
3. **Claims carry labels** — confirmed / observed / assumed / hearsay / unknown (see the ballast verify-gate skill).
4. **External product claims require truth-file evidence** (see the ballast proof-standard skill).
5. **Unresolved things get registered**, not remembered. If it's not in OPEN-QUESTIONS.md, it will be lost.
