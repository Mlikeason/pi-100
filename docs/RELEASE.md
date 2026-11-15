# Release preparation — π 100 1.0

**Store work paused at the user's request.** Build 1 was uploaded successfully before the pause and was processing; it has not been submitted for review. Current local build 2 replaces the split layout with a single vertical board/keypad and requests a tall iPhone window on display changes. Do not upload or submit this revision until the user resumes store work.

Intended publisher: Zhu Hong. Apple Developer team observed in the portal: Hong Zhu, KW9NTQUH4T. The account login email is intentionally not stored in public source. App Store seller name is determined by Apple's enrolled legal entity; the in-app developer label is Zhu Hong.

## Identity and metadata

- Bundle ID: me.zhuhong.pi100
- App Store Connect ID: 6832265598
- SKU: pi100-ios-001
- Primary locale: Simplified Chinese; English metadata included.
- Category proposal: Games / Puzzle, with Education secondary. Complete age-rating questions from actual content; do not imply medical benefits or a Kids Category commitment.
- Free download, no ads, no in-app purchases, no custom login.
- Website: https://zhuhong.me/pi100/
- Privacy: https://zhuhong.me/pi100/privacy/
- Support: https://zhuhong.me/pi100/support/
- Contact: Zhu Hong, zivzhu@gmail.com
- Game Center: me.zhuhong.pi100.perfect100; integer milliseconds, Low to High, best score.

## App privacy inventory

The app does not use advertising identifiers, location, contacts, camera, microphone, analytics, or a developer-operated backend. UserDefaults stores the haptic preference; system uptime measures elapsed in-app time. Required-reason manifest includes CA92.1 and 35F9.1. Only elapsed game duration (not raw uptime) is submitted to Game Center. Apple manages the player's Game Center identity and service data. Evaluate App Store Connect's current questions against this optional Game Center use before final privacy submission; don't equate an empty app-side collected-data array with a universal claim that Apple handles no data.

## Release gates

- [x] Repository cloned and reviewed.
- [x] Native SwiftUI app and Game Center client implemented.
- [x] Initial simulator and compact-layout revision compilation passed.
- [x] Unsigned iOS 27.2 Release archive built and payload validated.
- [x] 12 core tests passed.
- [x] Local build 2 simulator compilation (vertical layout and tall-window preference).
- [ ] Final vertical-layout UI verification, Duo default rotation, fold continuity, and standard iPhone UI suite.
- [x] Signed archive and App Store distribution IPA; Game Center entitlement verified.
- [x] App Store Connect app record and Game Center capability.
- [ ] Game Center leaderboard configuration.
- [ ] Real signed Game Center sign-in, score submit, fetch and offline retry check.
- [x] Public website/privacy/support deployed; 5 files returned HTTP 200 and matched local SHA-256.
- [ ] Store screenshots from final build: standard iPhone, Duo unfolded/closed, and iPad if shipping universal.
- [ ] App privacy, age rating, review contact phone, availability, export compliance completed.
- [ ] TestFlight smoke test on physical device.
- [ ] Submit App Store version and linked leaderboard for review.

No App Store submission or public availability is implied by a successful build/export. The signed archive is `build/Pi100.xcarchive`; the App Store distribution IPA is `build/AppStore/Pi100.ipa`. It uses Cloud Managed Apple Distribution and an iOS Team Store Provisioning Profile for `KW9NTQUH4T.me.zhuhong.pi100`, with Game Center enabled and debugging disabled. This store IPA is not an ad hoc install package.

## Environment findings

The initial Duo UI test runner aborted during setup before methods ran. The shared Device Hub window was also used by other tasks, so manual control was stopped to avoid interference. A subsequent dedicated Duo install hung in CoreSimulator; only this task’s install process was stopped. Final fold/unfold interaction, compact visual checks and Game Center round trips remain unverified. Disk exhaustion interrupted two builds; after clearing only task-owned build artifacts, both simulator compilation and unsigned archive succeeded. A scroll fallback for very short compact windows and preservation of review positions on replay were added afterward; the final unsigned Release archive rebuilt successfully with both changes.

The user explicitly authorized Apple account-resource configuration after an initial automatic approval rejection. Bundle ID registration, Game Center entitlement, development/store provisioning and signed export then succeeded. App record 6832265598 was created and Chinese listing metadata saved. Build 1 upload succeeded; subsequent processing status is unverified because store work was paused. The leaderboard creation form was opened but not submitted. The browser also declined dismissing that form after the pause; no further store actions were taken.

The user separately authorized publishing the three Pi100 website pages while preserving the existing site. All 144 source files of the current production baseline were verified by SHA-1 and retained unchanged; only the five Pi100 public files were added. Deployment `dpl_3eZDHsbHFrS2YFRAo9LisDDeL2qR` is READY and bound to zhuhong.me / www.zhuhong.me. The published file tree confirms all 144 originals have unchanged hashes. All five public Pi100 files returned HTTP 200 at www.zhuhong.me and matched local SHA-256. Files and inclusion rules were synchronized back to `/Users/hoo/zhuhong-journal` without changing existing pages, so later website deployments retain them. Browser visual verification timed out.

Local build 2 uses one vertical composition at every width, with a taller digit area on taller windows. Its orientation helper uses the current window and scene, requests a quarter turn only for a wide iPhone window, and handles a new display/activation once. It does not lock subsequent user rotation, rotate the SwiftUI view artificially, or use global device/screen state. A generation check prevents queued requests for an old display. System policies may decline the orientation preference; the single-column layout remains usable in that case.

Build 2 was installed and launched on the dedicated Duo simulator. The closed-screen view showed the board above the complete keypad without overlap; Begin and the first digit 1 worked, with 1/100 progress and correct feedback. Before the unfold action, the shared Device Hub switched to an unrelated physical device, so UI control stopped. Automatic tall orientation, five-digit continuity, and fold/unfold persistence remain unverified. An exclusive simulator UI session is needed to complete those checks.

At the user's subsequent request, local build 1.0 (2) was development-signed, installed, and launched successfully on their physical iPhone Duo running iOS 27.2. The development profile includes the target device and Game Center. CoreDevice's post-install query confirms `me.zhuhong.pi100`, version 1.0, bundle version 2. This is a direct development installation; store upload/review remains paused and fold behavior is not inferred from launch success.

The standard iPhone UI retry was stopped after more than eight minutes without entering test methods (CoreSimulator setup stalled). Both task-owned simulators were shut down; no shared simulator services or other projects were reset. The screenshot files are from the earlier build, not evidence of the compact-layout fix.
