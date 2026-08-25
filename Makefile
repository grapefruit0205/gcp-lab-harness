SHELL := /usr/bin/env bash

PHASE ?=

.PHONY: doctor validate-design run-all-dry-run sync-before-phase handoff-execute prepare-extension-review phase-gate

doctor:
	./scripts/doctor.sh

validate-design:
	./scripts/validate-design.sh

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
