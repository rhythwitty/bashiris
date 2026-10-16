SHELL := /bin/bash

SHELL_FILES := $(shell find . -path './.git' -prune -o -type f \( -name '*.sh' -o -name 'iris' \) -print)
PYTHON_SRC  := src tests

.PHONY: fmt fmt-check lint sh-test check py-lint py-test

# ── Shell ─────────────────────────────────────
fmt:
	shfmt -w -i 4 -ci -sr $(SHELL_FILES)

fmt-check:
	shfmt -d -i 4 -ci -sr $(SHELL_FILES)

lint:
	shellcheck $(SHELL_FILES)

sh-test:
	./tests/shell/test_iris.sh

# ── Python ────────────────────────────────────
py-lint:
	ruff check $(PYTHON_SRC)

py-test:
	PYTHONPATH=src python3 -m unittest discover tests -v

# ── Combined ──────────────────────────────────
check: fmt-check lint sh-test py-lint py-test

