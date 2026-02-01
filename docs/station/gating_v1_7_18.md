# v1.7.18 — Station Gate (via Station Status)

StationGate now evaluates safety by calling:
```bash
hvlien station status --format json --no-write-report
```

Behavior:
- **refuse** if station_state is `blocked`, `exporting`, or `performing`
- **warn_force** if station_state is `unknown` (requires `--force`)
- **allow** if `idle` or `editing`

Fallback:
- If station status JSON cannot be read, gate defaults to `warn_force`.

Usage (override):
```bash
hvlien assets export-all --force
hvlien apply --force --plan /tmp/plan.json
hvlien drift fix --force
```
