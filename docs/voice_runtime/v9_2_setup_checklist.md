# v9.2 Setup Checklist (Mac Runtime Bridge)

## IAC / MIDI
- [ ] IAC Driver enabled (Device is online)
- [ ] Port exists: `HVLIEN_VOICE`
- [ ] MIDI Monitor / Ableton can see events on `HVLIEN_VOICE`

## CLI sender
- [ ] `sendmidi` installed (or equivalent)
- [ ] Terminal test: send CC to `HVLIEN_VOICE` works
- [ ] Terminal test: send Note to `HVLIEN_VOICE` works

## Keyboard Maestro
- [ ] One KM macro per trigger (1 MIDI event per macro)
- [ ] KM macro fires correct MIDI every time

## Voice Control
- [ ] Voice Control enabled
- [ ] Custom command created for each phrase
- [ ] Phrase reliably triggers the intended KM macro

## Acceptance test (minimum)
- [ ] 10/10 “wub up” → CC14=96 on HVLIEN_VOICE
- [ ] 10/10 “sidechain on” → Note60 on HVLIEN_VOICE
- [ ] 10/10 “arm bass” → Note40 on HVLIEN_VOICE

If any test fails, use debug ladder:
Terminal → KM → Voice.

