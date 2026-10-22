# AmiSpec — schema validation & tests
# Requires: CUE CLI (https://cuelang.org) on PATH or in ~/.local/bin

.PHONY: all test vet negative goldens goldens-update fmt clean

all: test

test: ## full suite: syntax, unit tests, valid/negative fixtures, goldens
	@./scripts/test.sh

vet: ## validate all valid fixtures
	@./scripts/test.sh

negative: ## assert invalid fixtures are rejected
	@./scripts/negative.sh

goldens: ## check golden snapshots
	@./scripts/export-goldens.sh

goldens-update: ## rewrite golden snapshots after intentional schema changes
	@./scripts/export-goldens.sh --update

fmt: ## format CUE sources (in place)
	@cue fmt ./schemas/...

clean: ## remove temporary artifacts
	@rm -rf tests/goldens/*.tmp
