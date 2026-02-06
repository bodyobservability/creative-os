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

# --- Accounting (Python) ---
# Prefer venv python if present
PYRUN ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python3)
PY ?= $(PYRUN)
RCLONE ?= rclone

ACCOUNTING_SCRIPTS ?= accounting/scripts
BACKUP_LOCAL ?= accounting/data
BACKUP_REMOTE ?= gdrive:CreativeOS/AccountingBackup
BACKUP_EXCLUDES ?= --exclude ".DS_Store" --exclude "**/__pycache__/**"

.PHONY: help init-config dry-run autofill ci exports status all backup backup-dry backup-zip

help:
	@echo "Targets:"
	@echo "  make init-config - copy config template to live config (refuse overwrite)"
	@echo "  make dry-run     - preview corp-card matches (no writes)"
	@echo "  make autofill    - apply corp-card autofill (writes decisions + safe metadata)"
	@echo "  make ci          - fail if any economic_owner missing"
	@echo "  make exports     - generate CSV exports"
	@echo "  make status      - counts bundles by economic_owner/treatment"
	@echo "  make all         - autofill -> ci -> exports"
	@echo "  make backup      - rclone sync local evidence to Drive"
	@echo "  make backup-dry  - preview backup sync"
	@echo "  make backup-zip  - zip snapshot then upload"

init-config:
	$(PY) $(ACCOUNTING_SCRIPTS)/init_config.py

dry-run:
	$(PY) $(ACCOUNTING_SCRIPTS)/autofill_economic_owner.py --dry-run

autofill:
	$(PY) $(ACCOUNTING_SCRIPTS)/autofill_economic_owner.py

ci:
	$(PY) $(ACCOUNTING_SCRIPTS)/ci_check_economic_owner.py

exports:
	$(PY) $(ACCOUNTING_SCRIPTS)/export_2025.py

status:
	$(PY) $(ACCOUNTING_SCRIPTS)/status.py

all: autofill ci exports

backup-dry:
	$(RCLONE) sync $(BACKUP_LOCAL) $(BACKUP_REMOTE) --dry-run $(BACKUP_EXCLUDES)

backup:
	$(RCLONE) sync $(BACKUP_LOCAL) $(BACKUP_REMOTE) $(BACKUP_EXCLUDES)

backup-zip:
	@mkdir -p accounting/data/_snapshots
	@SNAP=accounting/data/_snapshots/accounting_data_$$(date +%Y%m%d_%H%M%S).zip; \
	zip -r $$SNAP $(BACKUP_LOCAL) >/dev/null; \
	echo "Created $$SNAP"; \
	$(RCLONE) copy $$SNAP $(BACKUP_REMOTE)/_snapshots/

# --- Launcher / Shell (Python) ---

.PHONY: shell-install tui launcher

shell-install:
	python3 -m venv .venv
	.venv/bin/pip install --upgrade pip
	.venv/bin/pip install -r requirements-shell.txt

tui:
	$(PYRUN) -m creative_os.shell accounting

launcher:
	$(PYRUN) -m creative_os.launcher
