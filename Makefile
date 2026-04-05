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

export RUST_BACKTRACE ?= 1
export

STYLE_CYAN := \033[36m
STYLE_RESET := \033[0m

.DEFAULT_GOAL := help

.PHONY: all
all: build setup format lint test ##H Build, setup data, format, lint, and run tests

.PHONY: build
build: ##H Build the Rust project
	@echo "Building ZK-Matrix-Join..."
	$(CARGO) build

.PHONY: run
run: ##H Run the ZK-Matrix-Join Demo
	@echo "Running ZK-Matrix-Join Demo..."
	$(CARGO) run --bin zk-matrix-join-host

.PHONY: benchmark
benchmark: ##H Run Verifiable Simulation for cycle counting (Fast, requires less RAM)
	@echo "Running fast verifiable cycle simulation..."
	$(CARGO) run --release --bin zk-matrix-join-host

.PHONY: benchmark-lite
benchmark-lite: ##H Cycle count simulation on minimal 5-event fixture
	@echo "Running fast verifiable cycle simulation on 5-event fixture..."
	MATRIX_FIXTURE_PATH=res/ruma_bootstrap_events.json $(CARGO) run --release --bin zk-matrix-join-host

.PHONY: prove
prove: ##H Build SP1 Guest ELF and Generate STARK Proof
	@echo "Running Host Prover (Auto-Compiling SP1 RISC-V 32-bit Guest)..."
	SP1_PROVE=true $(CARGO) run --release --bin zk-matrix-join-host

.PHONY: prove-lite
prove-lite: ##H Generate STARK Proof on the minimal 5-event fixture
	@echo "Comparing benchmark parity: Proving offline 5-event fixture..."
	MATRIX_FIXTURE_PATH=res/ruma_bootstrap_events.json SP1_PROVE=true $(CARGO) run --release --bin zk-matrix-join-host

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
test: ##H Run fast Native Resolution tests (<1s)
	@echo "Running Fast Native Tests..."
	$(CARGO) test -p zk-matrix-join-host -- --nocapture

.PHONY: test-zk
test-zk: ##H Run the full ZKVM Parity Simulation (Takes several minutes)
	@echo "Running Deep ZKVM Parity Simulation..."
	RUST_LOG=info RAYON_NUM_THREADS=1 $(CARGO) test --release -p zk-matrix-join-host -- --ignored --nocapture --test-threads=1

.PHONY: setup
setup: ##H Combined: Fetch real Matrix data and Ruma state resolution fixtures
	@echo "Setting up project data and fixtures..."
	@if [ -n "$$MATRIX_TOKEN" ]; then \
		echo "Fetching real Matrix state data from $$MATRIX_HOMESERVER..."; \
		$(PYTHON) scripts/fetch_matrix_state.py; \
	else \
		echo "Skipping real Matrix fetch (MATRIX_TOKEN not set)."; \
	fi
	@echo "Ruma State Res test fixtures are checked in to res/"

.PHONY: cpu-info
cpu-info: ##H Print CPU info relevant to native target-cpu
	@echo "=== CPU Model ==="
	@grep -m1 'model name' /proc/cpuinfo 2>/dev/null || sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown"
	@echo "=== Architecture ==="
	@uname -a
	@echo "=== rustc Host Target ==="
	@rustc -vV | grep host
	@echo "=== rustc Native CPU ==="
	@rustc --print=cfg -C target-cpu=native 2>/dev/null | grep target_feature | sort
	@echo "=== CPU Flags [from /proc/cpuinfo] ==="
	@grep -m1 'flags' /proc/cpuinfo 2>/dev/null | tr ' ' '\n' | grep -E 'avx|sse|aes|bmi|fma|popcnt|lzcnt|sha|pclmul' | sort
	@echo "=== GCC Version ==="
	@gcc --version | head -n 1 || true
	@echo "=== G++ / C++ Toolchain ==="
	@g++ --version | head -n 1 || true
	@echo "=== Clang / LLVM ==="
	@clang --version | head -n 1 || true
	@echo "=== GLIBC Version ==="
	@ldd --version | head -n 1 || true
	@echo "=== GNU Make Header ==="
	@make --version | head -n 1 || true
	@echo "=== Python Version ==="
	@python3 --version || true
	@echo "=== Kernel Info ==="
	@uname -srv || true
	@echo "=== Rust Toolchains ==="
	@rustup show || true
	@echo "=== SP1 Toolchain ==="
	@cargo prove --version || true


LINT_LOCS_PY ?= $(shell git ls-files '*.py')

.PHONY: format
format: ##H Format the Rust and Python codebase
	-pre-commit run --all-files
	# Other formatters (python, json, etc)
	-isort $(LINT_LOCS_PY)
	-black $(LINT_LOCS_PY)
	-prettier -w .

.PHONY: lint
lint: ##H Run clippy to lint the codebase and check compilation
	$(CARGO) check
	$(CARGO) clippy --all-targets --all-features -- -D warnings
	@echo "Running ZK Security Scanner (vuln-002-VeilCash)..."
	python3 scripts/detect_vuln_002.py

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
