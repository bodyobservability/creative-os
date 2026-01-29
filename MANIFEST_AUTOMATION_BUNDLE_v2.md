# HVLIEN Automation Bundle v2 (complete)

Includes:
- Full v1 JSON Schemas: inventory, substitutions, controllers, pack signatures, recommendations
- Curated v1 JSON inputs: substitutions, recommendations, pack_signatures (tag-implied)
- Docs: normalization/dedupe, A0 acceptance, probe queries
- Example YAML spec
- Swift CLI tool `hvlien` (ArgumentParser + Yams) with:
  - `a0`: ScreenCaptureKit + Vision OCR (manual probe typing) -> inventory.v1.json, controllers_inventory.v1.json, resolve_report.json
  - `resolve`: resolve-only using existing inventories
  - `--interactive`: terminal prompt loop
  - SpecCompiler: YAML -> DeviceRequest + ControllerRequest + PackCheckRequest
  - InventoryBuilder: confidence gating + merge + stable_key
  - Resolvers: devices + controllers + packs + recommendations
  - CoreMIDI enumerator (unique_id + endpoint names)
  - MPK mini IV Port 2 selector

Does NOT include Ableton .als files, installers, packs, or any runs/ artifacts.
