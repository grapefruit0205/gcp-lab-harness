# 정제된 실행 증거

이 폴더에는 Git에 공개해도 되는 Phase별 요약만 저장합니다. 원시 stdout/stderr, Terraform state, 프로젝트 번호, 결제 계정 ID, IP 주소, 이메일, 토큰, 키, 비밀번호는 `artifacts/`에만 두고 커밋하지 않습니다.

각 요약은 최소한 다음을 포함합니다.

- Phase와 run ID
- 실행 시각과 도구 버전
- 검증 항목별 pass/fail
- 생성·삭제한 리소스의 종류와 개수(식별자는 마스킹)
- cleanup 완료 여부
- 사람의 승인 여부와 Codex review 결과 요약
