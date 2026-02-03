# OpenCV build integration (macOS)

Recommended: Xcode wrapper project

1) Install OpenCV:
   brew install opencv
   pkg-config --modversion opencv4

2) Create an Xcode macOS Command Line Tool target.
   Add Swift sources from:
   kernel/cli/Sources/StudioCore/

3) Add these files:
   kernel/cli/Sources/AnchorCV/AnchorMatcherBridge.h
   kernel/cli/Sources/AnchorCV/AnchorMatcherBridge.mm
   kernel/cli/Sources/AnchorCV/AnchorCV-Bridging-Header.h

4) Xcode Build Settings:
   - Header Search Paths: /opt/homebrew/include
   - Library Search Paths: /opt/homebrew/lib
   - Other Linker Flags: (paste output of `pkg-config --libs opencv4`)
   - C++ Standard: C++17
   - Objective-C Bridging Header: .../AnchorCV-Bridging-Header.h

5) Validate anchors:
   wub validate-anchors --pack shared/specs/automation/anchors/ableton12_3_macos_default_5k_morespace

## Anchors pack basics

- Ensure Ableton UI layout is stable (Browser visible, Device View open, consistent theme/scale).
- Capture anchor crops with `wub capture-anchor` for key regions (browser.search, browser.results, device.chain, file dialog buttons).
- Store anchors in a pack folder with a `manifest.v1.json` listing anchor ids + region ids + min_score.
- Validate with:
  wub validate-anchors --pack shared/specs/automation/anchors/<pack_id>
