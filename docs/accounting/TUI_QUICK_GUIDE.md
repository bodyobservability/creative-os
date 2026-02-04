# TUI Quick Guide (Accounting)

If ingestion (bundles) already exists, you can do everything from the TUI.

## Install
```bash
make shell-install
```

## Run
```bash
make tui
```

## Flow (guided)
- Press **Space** to run the recommended next action.
- Press **m** to toggle SAFE / GUIDED / ALL.
- In **ALL**, dangerous actions require **y** to confirm (**n** cancels).
- Press **p** to preview what an action will write (e.g., exports).

## Typical sequence
Space → dry-run → Space → autofill → Space → ci → Space → exports → Space → backup-dry → Space → backup
