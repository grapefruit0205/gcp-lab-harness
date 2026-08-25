SHELL := /usr/bin/env bash

PHASE ?=

.PHONY: install-toolchain gcp-auth gcp-preflight terraform-gcp-check doctor validate-design test-offline run-all-dry-run sync-before-phase handoff-execute prepare-extension-review phase-gate

install-toolchain:
	./scripts/install-toolchain.sh

gcp-auth:
	./scripts/gcp-auth-login.sh

gcp-preflight:
	./scripts/preflight-gcp.sh

terraform-gcp-check:
	./scripts/verify-terraform-gcp.sh

doctor:
	./scripts/doctor.sh

validate-design:
	./scripts/validate-design.sh

test-offline:
	./tests/offline-controller.sh
	./tests/offline-phases-01-06.sh
	./tests/offline-phases-07-15.sh

run-all-dry-run:
	./scripts/run-all.sh --dry-run

sync-before-phase:
	./scripts/sync-before-phase.sh

handoff-execute:
	@test -n "$(PHASE)" || { echo "PHASE=<docs/phases/...md>가 필요합니다." >&2; exit 2; }
	./scripts/handoff-execute.sh "$(PHASE)"

prepare-extension-review:
	@test -n "$(PHASE)" || { echo "PHASE=<docs/phases/...md>가 필요합니다." >&2; exit 2; }
	./scripts/prepare-extension-review.sh "$(PHASE)"

phase-gate:
	@test -n "$(PHASE)" || { echo "PHASE=<docs/phases/...md>가 필요합니다." >&2; exit 2; }
	./scripts/phase-gate.sh "$(PHASE)"
