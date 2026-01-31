# OpenCV build integration (macOS)

Recommended: Xcode wrapper project

1) Install OpenCV:
   brew install opencv
   pkg-config --modversion opencv4

2) Create an Xcode macOS Command Line Tool target.
   Add Swift sources from:
   tools/automation/swift-cli/Sources/hvlien/

3) Add these files:
   tools/automation/swift-cli/Sources/AnchorCV/AnchorMatcherBridge.h
   tools/automation/swift-cli/Sources/AnchorCV/AnchorMatcherBridge.mm
   tools/automation/swift-cli/Sources/AnchorCV/hvlien-Bridging-Header.h

4) Xcode Build Settings:
   - Header Search Paths: /opt/homebrew/include
   - Library Search Paths: /opt/homebrew/lib
   - Other Linker Flags: (paste output of `pkg-config --libs opencv4`)
   - C++ Standard: C++17
   - Objective-C Bridging Header: .../hvlien-Bridging-Header.h

5) Validate anchors:
   hvlien validate-anchors --pack specs/automation/anchors/ableton12_3_macos_default_5k_morespace

## Anchors pack basics

- Ensure Ableton UI layout is stable (Browser visible, Device View open, consistent theme/scale).
- Capture anchor crops with `hvlien capture-anchor` for key regions (browser.search, browser.results, device.chain, file dialog buttons).
- Store anchors in a pack folder with a `manifest.v1.json` listing anchor ids + region ids + min_score.
- Validate with:
  hvlien validate-anchors --pack specs/automation/anchors/<pack_id>
