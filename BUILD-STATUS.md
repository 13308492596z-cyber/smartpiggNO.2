# Build status

Source commit: b11311207b7d6afbee037fe2409b7ec822f40f30

Run: https://github.com/13308492596z-cyber/smartpiggNO.2/actions/runs/39944881564

- Native arm64 iOS 16 build: success.
- Route math checks: passed.
- Plist and embedded entitlements: passed.
- Archive downloaded and checksums verified locally.
- Package SHA-256: 35e2ab12a8fa0c6cd630caaae3c5c55aba8d74c0ad5bd1270d0ce6ef1b4ac9ef
- XR installation and on-device simulation: pending.

Upstream GPX encoder emits three signed/unsigned comparison warnings. The build succeeds. This result does not establish that the private service accepts the requested permissions or that background route playback works on iOS 16.4.1.
