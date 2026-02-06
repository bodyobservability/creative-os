# Repo Launcher TUI (v0.1.1, exec replacement)

A lightweight repo-root Textual launcher that starts persona TUIs without merging them into one monolith.

## Install
```bash
make shell-install
```

## Run
```bash
make launcher
```

## Behavior
- Enter runs the selected app via exec replacement (launcher process is replaced).
- i installs the selected app:
  - hidden in SAFE
  - allowed in GUIDED
  - requires y-confirm in ALL
- m toggles SAFE/GUIDED/ALL.

## Wiring
Apps are listed in `creative_os/launcher/registry.py`.
- Accounting: install `make shell-install`, run `make tui`
- Studio: install `make onboard`, run `make studio`


## Health + guided next step
- Each app shows a badge: green ● installed, red ○ not installed.
- Space runs the recommended next step (install if missing, otherwise run).


## Repo status pane
The launcher shows repo prerequisites (make/python/rclone) and accounting readiness (config + bundles present).
If nothing is selected, Space runs the global recommended next step.


## Ingestion readiness
v0.4 adds ingestion readiness checks for accounting (.mbox present, extracted mail present, bundles present).
- p shows a minimal ingestion plan
- o opens intake or bundles folder depending on state
- global Next (Space) guides you through ingestion gates before installs/runs.
