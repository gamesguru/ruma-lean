SHELL=/bin/bash

# Variables
CARGO = cargo
PYTHON = python3

# Load environment variables from .env file if it exists
ifneq (,$(wildcard ./.env))
    include .env
endif

# Clean quotes from variables to avoid "makefile things"
MATRIX_TOKEN := $(subst ",,$(subst ',,$(MATRIX_TOKEN)))
MATRIX_HOMESERVER := $(subst ",,$(subst ',,$(MATRIX_HOMESERVER)))
MATRIX_ROOM_ID := $(subst ",,$(subst ',,$(MATRIX_ROOM_ID)))

export

STYLE_CYAN := \033[36m
STYLE_RESET := \033[0m

.DEFAULT_GOAL := help

.PHONY: all
all: build test ##H Build the project and run tests

.PHONY: build
build: ##H Build the Rust project
	@echo "Building ZK-Matrix-Join..."
	$(CARGO) build

.PHONY: run
run: ##H Run the ZK-Matrix-Join Demo
	@echo "Running ZK-Matrix-Join Demo..."
	$(CARGO) run --bin zk-matrix-join-host

.PHONY: prove
prove: ##H Build SP1 Guest ELF and Generate STARK Proof
	@echo "Running Host Prover (Auto-Compiling SP1 RISC-V 32-bit Guest)..."
	SP1_PROVE=true $(CARGO) run --release --bin zk-matrix-join-host

.PHONY: wasm
wasm: ##H Build the WebAssembly light-client Verifier
	@echo "Compiling WASM bindings..."
	cd src/wasm-client && wasm-pack build --target web

.PHONY: web-demo
web-demo: ##H Run a local web server to test the WASM UI
	@echo "================================================================"
	@echo " ZK-Matrix WebAssembly Server is starting!"
	@echo " Please manually open your web browser to:"
	@echo " http://localhost:8080/demo/index.html"
	@echo "================================================================"
	python3 -m http.server 8080

.PHONY: test
test: ##H Run the ZK Circuit Tests
	@echo "Running ZK Circuit Tests..."
	$(CARGO) test -p zk-matrix-join-host

.PHONY: fetch
fetch: ##H Fetch real Matrix data (uses .env file for configuration)
	@if [ -z "$$MATRIX_TOKEN" ]; then \
		echo "Error: MATRIX_TOKEN is not set."; \
		echo "Please copy .env.example to .env and add your token."; \
		exit 1; \
	fi
	@echo "Fetching real Matrix state data from $$MATRIX_HOMESERVER..."
	$(PYTHON) scripts/fetch_matrix_state.py

.PHONY: fixtures
fixtures: ##H Download Ruma state resolution test fixtures
	@echo "Downloading Ruma State Res test fixtures..."
	mkdir -p res
	curl -sL "https://raw.githubusercontent.com/ruma/ruma/main/crates/ruma-state-res/tests/it/fixtures/bootstrap-private-chat.json" -o res/ruma_bootstrap_events.json
	@echo "Saved to res/ruma_bootstrap_events.json"


LINT_LOCS_PY ?= $(shell git ls-files '*.py')

.PHONY: format
format: ##H Format the Rust and Python codebase
	pre-commit run --all-files
	$(CARGO) fmt
	# Other formatters (python, json, etc)
	-isort $(LINT_LOCS_PY)
	-black $(LINT_LOCS_PY)
	-prettier -w .

.PHONY: lint
lint: ##H Run clippy to lint the codebase and check compilation
	$(CARGO) check
	$(CARGO) clippy --all-targets --all-features -- -D warnings

.PHONY: clean
clean: ##H Clean up cache and optionally build artifacts
	@echo "Cleaning up..."
	find . -name .mypy_cache -exec rm -rf {} +;
	find . -name .ruff_cache -exec rm -rf {} +;
	find . -name .pytest_cache -exec rm -rf {} +;
# 	$(CARGO) clean


# Messes up vim/sublime syntax highlighting, so it's at the end!
.PHONY: help
help: ##H Show this help, list available targets
	@grep -hE '^[a-zA-Z0-9_\/-]+:.*?##H .*$$' $(MAKEFILE_LIST) \
                | awk 'BEGIN {FS = ":.*?##H "}; {printf "$(STYLE_CYAN)%-20s$(STYLE_RESET) %s\n", $$1, $$2}'
