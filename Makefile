# Makefile aliases for wub workflows
# Note: This file assumes the Swift CLI builds to kernel/cli/.build/release/wub

.PHONY: build sweep plan setup profile station studio onboard check preflight

WUB=kernel/cli/.build/release/wub

build:
	cd kernel/cli && swift build -c release

sweep: build
	$(WUB) sweep

plan: build
	$(WUB) plan

setup: build
	$(WUB) setup --show-manual

profile: build
	$(WUB) profile use hvlien

station: build
	$(WUB) station status --format human

studio: build
	$(WUB) ui

onboard: build
	$(WUB) preflight --auto

check: build
	$(WUB) check

preflight: build
	$(WUB) preflight

# --- Launcher / Shell (Python) ---
# Prefer venv python if present
PYRUN ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python3)

.PHONY: shell-install tui launcher

shell-install:
	python3 -m venv .venv
	.venv/bin/pip install --upgrade pip
	.venv/bin/pip install -r requirements-shell.txt

tui:
	$(PYRUN) -m creative_os.shell accounting

launcher:
	$(PYRUN) -m creative_os.launcher
