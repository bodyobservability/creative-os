#!/usr/bin/env python3
"""
creative_os.cli

Minimal CLI entrypoint for bundle operations (v0.1).
Local-only. Intended to be called as: python3 -m creative_os.cli <command>
"""
from __future__ import annotations

import argparse
import os
import sys

from creative_os.bundles.engine import (
    bundle_import,
    bundle_list,
    bundle_show,
    bundle_plan,
    bundle_apply,
)

def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]

    p = argparse.ArgumentParser(prog="cos", description="Creative OS CLI (v0.1)")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_bundle = sub.add_parser("bundle", help="Bundle import/plan/apply")
    bsub = p_bundle.add_subparsers(dest="bundle_cmd", required=True)

    p_import = bsub.add_parser("import", help="Import a bundle zip into the vault")
    p_import.add_argument("zip_path", help="Path to bundle zip (must contain bundle_manifest.v1.json at root)")
    p_import.add_argument("--vault", default="", help="Vault root (default: env CREATIVE_OS_VAULT or ~/CreativeOSVault)")
    p_import.add_argument("--tag", action="append", default=[], help="Optional tags to attach to this bundle import")
    p_import.set_defaults(fn=lambda a: bundle_import(a.zip_path, vault_override=a.vault or None, tags=a.tag))

    p_list = bsub.add_parser("list", help="List imported bundles")
    p_list.add_argument("--vault", default="", help="Vault root override")
    p_list.set_defaults(fn=lambda a: bundle_list(vault_override=a.vault or None))

    p_show = bsub.add_parser("show", help="Show bundle manifest and metadata")
    p_show.add_argument("bundle_id", help="Bundle ID")
    p_show.add_argument("--vault", default="", help="Vault root override")
    p_show.set_defaults(fn=lambda a: bundle_show(a.bundle_id, vault_override=a.vault or None))

    p_plan = bsub.add_parser("plan", help="Plan applying an imported bundle to a target directory (dry run)")
    p_plan.add_argument("bundle_id", help="Bundle ID")
    p_plan.add_argument("--target", required=True, help="Target directory (repo root)")
    p_plan.add_argument("--vault", default="", help="Vault root override")
    p_plan.set_defaults(fn=lambda a: bundle_plan(a.bundle_id, a.target, vault_override=a.vault or None))

    p_apply = bsub.add_parser("apply", help="Apply an imported bundle to a target directory")
    p_apply.add_argument("bundle_id", help="Bundle ID")
    p_apply.add_argument("--target", required=True, help="Target directory (repo root)")
    p_apply.add_argument("--mode", default="GUIDED", choices=["SAFE","GUIDED","ALL"], help="Execution gate (local-only). v0.1 uses this only for logging.")
    p_apply.add_argument("--force", action="store_true", help="Pass --force to bundle apply script (if supported)")
    p_apply.add_argument("--vault", default="", help="Vault root override")
    p_apply.set_defaults(fn=lambda a: bundle_apply(a.bundle_id, a.target, mode=a.mode, force=a.force, vault_override=a.vault or None))

    args = p.parse_args(argv)
    try:
        res = args.fn(args)
        return 0 if (res is None or res is True) else int(res)
    except KeyboardInterrupt:
        return 130
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
