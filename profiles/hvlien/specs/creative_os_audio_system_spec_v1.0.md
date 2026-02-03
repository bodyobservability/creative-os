# HVLIEN AUDIO SYSTEM — SPEC v1.0 ## 0. DESIGN PRINCIPLES (NON-FUNCTIONAL REQUIREMENTS) **P0 — Velocity Preservation**
 No step may slow initial creation
 No grid authority
 No mandatory decisions mid-flow **P1 — Graceful Degradation**
 System must function acceptably if any non-core component fails
 Vocal capture must always be available independently **P2 — One-Way Elevation**
 Creation → Finishing → Release
 No back-propagation of complexity into creation **P3 — Fixed Rituals**
 Repeatable setup
 Deterministic outputs
 Minimal variance  ## 1. SYSTEM ARCHITECTURE (HIGH LEVEL) ### 1.1 Roles | Component | Role |
|-|-|
| iPhone + Voloco | Primary vocal creation instrument |
| USB-C iPhone mic | Creative ignition input |
| MacBook Pro (macOS) | Studio processing + finishing |
| Ableton Live Suite | Audio engine + finishing |
| iConnectivity AUDIO4c | Multi-host audio bridge |
| Linux Workstation | Optional automation (deferred) | ### 1.2 Core Invariant
 Voloco remains the creation front-end and is not replaced
 Studio system listens to Voloco; never forces workflow changes upstream  ## 2. AUDIO HARDWARE SPEC ### 2.1 Interface
 iConnectivity AUDIO4c ### 2.2 Monitoring Topology | Output | Destination |
|-|-|
| Outputs 1–2 | Control room monitors |
| Outputs 3–4 | Headphone amp → performer headphones | Constraints:
 Separate volume control per destination
 Performer isolation preserved  ## 3. SOFTWARE STACK
 Ableton Live Suite (latest stable)
 Xfer Serum (single permanent patch; macro-only operation during sessions)  ## 4. ABLETON GLOBAL SETTINGS (ALL PROJECTS) | Setting | Value |
|-|-|
| Sample Rate | 48 kHz |
| Bit Depth (Export) | 24-bit |
| Auto Warp Long Samples | OFF |
| Default Warp Mode | OFF |
| Latency Buffer | 64–128 samples |  ## 5. STUDIO FINISHING BAYS
Defined in `profiles/hvlien/specs/creative_os_audio_system_ableton_artifacts_v1.0-a.md`.  ## 6. FILE & ARCHIVAL CONVENTIONS ### Naming
```
HVLIEN_TrackName_v1.wav
HVLIEN_TrackName_v1_FIN.wav
``` ### Canonical folders
```
/HVLIEN/ /VOL_OCO_EXPORTS/ /ABLETON/FINISHING_BAYS/ /MASTERS/2026/
```  ## 7. OPTIONAL AUTOMATION (DEFERRED)
Linux watch-folder driven batch finishing is deferred until bays are proven stable.  ## 8. PROMOTION RULES (CREATIVE SAFETY)
A track qualifies for deeper production only if:
1. Still resonates after 72 hours
2. Artist explicitly requests expansion
3. Listener response confirms signal
4. Finishing bay required no fixes  ## 9. OUT OF SCOPE (INTENTIONAL)
 Arrangement editing
 Quantization
 Heavy sound design
 AI composition  # END SPEC v1.0
