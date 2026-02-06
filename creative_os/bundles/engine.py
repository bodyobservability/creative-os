from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional
import zipfile

ISO = "%Y-%m-%dT%H:%M:%SZ"

def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime(ISO)

def _run_id() -> str:
    # Stable-ish monotonic ID for filesystem
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "_" + os.urandom(3).hex()

def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def _vault_root(override: Optional[str] = None) -> Path:
    if override:
        return Path(os.path.expanduser(override)).resolve()
    env = os.environ.get("CREATIVE_OS_VAULT", "").strip()
    if env:
        return Path(os.path.expanduser(env)).resolve()
    return Path(os.path.expanduser("~/CreativeOSVault")).resolve()

def _vault_paths(vault: Path) -> dict[str, Path]:
    return {
        "vault": vault,
        "memory_bundles": vault / "memory" / "bundles",
        "runs": vault / "runs",
        "index": vault / "index",
    }

def _ensure_dirs(vault: Path) -> None:
    paths = _vault_paths(vault)
    for p in [paths["memory_bundles"], paths["runs"], paths["index"]]:
        p.mkdir(parents=True, exist_ok=True)

def _bundle_store_dir(vault: Path, bundle_id: str) -> Path:
    dt = datetime.now(timezone.utc)
    return vault / "memory" / "bundles" / dt.strftime("%Y") / dt.strftime("%m") / bundle_id

def _load_manifest_from_zip(zip_path: Path) -> dict[str, Any]:
    with zipfile.ZipFile(zip_path, "r") as z:
        # must be at root
        candidates = [n for n in z.namelist() if n.endswith("bundle_manifest.v1.json")]
        root_candidate = "bundle_manifest.v1.json" if "bundle_manifest.v1.json" in z.namelist() else None
        if not root_candidate:
            raise ValueError("Zip must contain bundle_manifest.v1.json at root.")
        raw = z.read(root_candidate)
        try:
            manifest = json.loads(raw.decode("utf-8"))
        except Exception as e:
            raise ValueError(f"Failed to parse bundle_manifest.v1.json: {e}")
        return manifest

def _validate_manifest_min(manifest: dict[str, Any]) -> None:
    if manifest.get("schema_version") != 1:
        raise ValueError("bundle_manifest schema_version must be 1")
    bid = manifest.get("bundle_id")
    if not isinstance(bid, str) or not bid:
        raise ValueError("bundle_manifest.bundle_id missing/invalid")
    apply = manifest.get("apply", {})
    if not isinstance(apply, dict):
        raise ValueError("bundle_manifest.apply missing/invalid")
    if not apply.get("default_entrypoint"):
        raise ValueError("bundle_manifest.apply.default_entrypoint missing")
    # contents.archive is optional for imported zips (we compute), but keep consistent.

def bundle_import(zip_path: str, vault_override: Optional[str] = None, tags: Optional[list[str]] = None) -> bool:
    zpath = Path(zip_path).expanduser().resolve()
    if not zpath.exists():
        raise FileNotFoundError(f"zip not found: {zpath}")
    data = zpath.read_bytes()
    zip_sha = _sha256_bytes(data)
    zip_bytes = len(data)

    manifest = _load_manifest_from_zip(zpath)
    _validate_manifest_min(manifest)

    bundle_id = manifest["bundle_id"]
    vault = _vault_root(vault_override)
    _ensure_dirs(vault)

    store_dir = _bundle_store_dir(vault, bundle_id)
    store_dir.mkdir(parents=True, exist_ok=True)

    # write bundle zip
    stored_zip = store_dir / "bundle.zip"
    stored_zip.write_bytes(data)

    # write manifest as stored copy
    stored_manifest = store_dir / "bundle_manifest.v1.json"
    stored_manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    # write computed metadata
    meta = {
        "schema_version": 1,
        "bundle_id": bundle_id,
        "imported_at": _now_iso(),
        "source_zip_path": str(zpath),
        "zip": {"bytes": zip_bytes, "sha256": zip_sha},
        "manifest_sha256": _sha256_file(stored_manifest),
        "tags": tags or [],
        "vault_store_dir": str(store_dir),
    }
    (store_dir / "import_meta.v1.json").write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    # import receipt
    run_id = _run_id()
    run_dir = vault / "runs" / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    receipt = {
        "schema_version": 1,
        "import_id": f"cos_import_{run_id}",
        "imported_at": _now_iso(),
        "source": {"kind": "path", "ref": str(zpath)},
        "objects": [{"kind": "bundle", "id": bundle_id}],
        "status": "pass",
        "reasons": [],
        "links_created": {"project_ids": manifest.get("targets", []) if isinstance(manifest.get("targets"), list) else [], "tags": tags or []},
        "bundle": meta,
    }
    (run_dir / "bundle_import_receipt.v1.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"Imported bundle: {bundle_id}")
    print(f"Stored at: {store_dir}")
    print(f"Receipt: {run_dir / 'bundle_import_receipt.v1.json'}")
    return True

def _list_bundle_dirs(vault: Path) -> list[Path]:
    base = vault / "memory" / "bundles"
    if not base.exists():
        return []
    return [p for p in base.rglob("*") if p.is_dir() and (p / "bundle_manifest.v1.json").exists()]

def bundle_list(vault_override: Optional[str] = None) -> bool:
    vault = _vault_root(vault_override)
    dirs = _list_bundle_dirs(vault)
    if not dirs:
        print("No bundles found.")
        return True
    # sort by mtime of manifest
    items = []
    for d in dirs:
        m = d / "bundle_manifest.v1.json"
        items.append((m.stat().st_mtime, d))
    items.sort(reverse=True)
    for _, d in items[:200]:
        manifest = json.loads((d / "bundle_manifest.v1.json").read_text(encoding="utf-8"))
        print(f"- {manifest.get('bundle_id')}  ({d})")
    return True

def _find_bundle_dir(vault: Path, bundle_id: str) -> Path:
    for d in _list_bundle_dirs(vault):
        m = json.loads((d / "bundle_manifest.v1.json").read_text(encoding="utf-8"))
        if m.get("bundle_id") == bundle_id:
            return d
    raise FileNotFoundError(f"Bundle not found in vault: {bundle_id}")

def bundle_show(bundle_id: str, vault_override: Optional[str] = None) -> bool:
    vault = _vault_root(vault_override)
    d = _find_bundle_dir(vault, bundle_id)
    print((d / "bundle_manifest.v1.json").read_text(encoding="utf-8"))
    return True

def bundle_plan(bundle_id: str, target: str, vault_override: Optional[str] = None) -> bool:
    vault = _vault_root(vault_override)
    d = _find_bundle_dir(vault, bundle_id)
    manifest = json.loads((d / "bundle_manifest.v1.json").read_text(encoding="utf-8"))

    tgt = Path(os.path.expanduser(target)).resolve()
    exists = tgt.exists()
    is_git = (tgt / ".git").exists()
    print("== cos bundle plan ==")
    print(f"bundle: {bundle_id}")
    print(f"target: {tgt}")
    print(f"target_exists: {exists}")
    print(f"target_is_git: {is_git}")
    apply = manifest.get("apply", {})
    print(f"entrypoint: {apply.get('default_entrypoint')}")
    print(f"verification: {apply.get('verification', {}).get('path')}")
    print("NOTE: v0.1 plan is informational only (no diff).")
    return True

def bundle_apply(bundle_id: str, target: str, mode: str = "GUIDED", force: bool = False, vault_override: Optional[str] = None) -> bool:
    vault = _vault_root(vault_override)
    d = _find_bundle_dir(vault, bundle_id)
    manifest = json.loads((d / "bundle_manifest.v1.json").read_text(encoding="utf-8"))
    zip_path = d / "bundle.zip"
    if not zip_path.exists():
        raise FileNotFoundError(f"Stored bundle.zip missing: {zip_path}")

    tgt = Path(os.path.expanduser(target)).resolve()
    tgt.mkdir(parents=True, exist_ok=True)

    # Extract to temp dir
    tmp = Path(tempfile.mkdtemp(prefix="cos_bundle_"))
    try:
        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(tmp)

        entry = manifest["apply"]["default_entrypoint"]
        entry_path = tmp / entry
        if not entry_path.exists():
            raise FileNotFoundError(f"Entrypoint not found in bundle: {entry}")

        # Prepare run dir
        run_id = _run_id()
        run_dir = vault / "runs" / run_id
        log_dir = run_dir / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        run_dir.mkdir(parents=True, exist_ok=True)
        apply_log = log_dir / "bundle_apply.log"

        cmd = ["bash", str(entry_path), "--target", str(tgt)]
        if force:
            cmd.append("--force")

        # Execute apply
        with apply_log.open("w", encoding="utf-8") as lf:
            lf.write(f"mode={mode}\n")
            lf.write(f"bundle_id={bundle_id}\n")
            lf.write(f"target={tgt}\n")
            lf.write("cmd=" + " ".join(cmd) + "\n\n")
            proc = subprocess.run(cmd, cwd=str(tmp), stdout=lf, stderr=subprocess.STDOUT)
            apply_exit = proc.returncode

        # Verify
        verify_path = manifest.get("apply", {}).get("verification", {}).get("path", "")
        verify_exit = None
        verify_log = None
        if verify_path:
            verify_log = log_dir / "bundle_verify.log"
            vcmd = ["bash", verify_path]
            with verify_log.open("w", encoding="utf-8") as lf:
                lf.write("cmd=" + " ".join(vcmd) + "\n\n")
                proc2 = subprocess.run(vcmd, cwd=str(tgt), stdout=lf, stderr=subprocess.STDOUT)
                verify_exit = proc2.returncode

        status = "pass" if (apply_exit == 0 and (verify_exit in (None, 0))) else "fail"

        receipt = {
            "schema_version": 1,
            "apply_id": f"cos_apply_{run_id}",
            "applied_at": _now_iso(),
            "bundle_id": bundle_id,
            "target": str(tgt),
            "mode": mode,
            "force": bool(force),
            "apply_exit": apply_exit,
            "verify": {"path": verify_path or None, "exit": verify_exit, "log": str(verify_log) if verify_log else None},
            "logs": {"apply": str(apply_log)},
            "status": status,
        }
        (run_dir / "bundle_apply_receipt.v1.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"Apply status: {status}")
        print(f"Receipt: {run_dir / 'bundle_apply_receipt.v1.json'}")
        return status == "pass"
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
