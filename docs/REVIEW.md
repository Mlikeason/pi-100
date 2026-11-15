# Review — 2026-11-08

Reviewed upstream `Mlikeason/pi-100` at commit `2c37b8c`. All tracked files were cloned; the repository originally contained a single HTML app, three icons, and .gitignore.

## Findings and disposition

1. **High: public write access to shared scores.** `PANTRY_ID` was embedded in the web client. Anyone with the URL could read/overwrite the shared basket; scores and names were client supplied. Removed the credential from the current web source and disabled remote upload. The native app uses optional Game Center. The historical Pantry identifier remains in Git history and the existing deployed web version until updated. Revoke/rotate it at the provider; removing it from source does not revoke it. No calls were made to that score service.
2. **High: shared score updates lose concurrent writes.** Fetch/modify/post replaces the entire shared basket. Per-client serialized requests cannot protect multiple users. Native Game Center submits a single score, eliminating this application-level shared-basket update.
3. **Medium: speed outranked accuracy.** The old leaderboard sorted only by `timeUsed`; wrong guesses auto-advanced. Local native rankings use accuracy first. Global ranking admits only a perfect challenge. Legacy local sorting corrected.
4. **Medium: hints earned normal credit.** Automatic answer highlighting was scored as independent recall. Native explicit hints mark answers assisted and exclude them from credit and global submissions. Legacy hint-assisted answers no longer increase score.
5. **Medium: unreliable timer and resume.** The old app started counting at load, incremented a setInterval counter, and lost active progress on reload. Native timing starts explicitly, uses system uptime, pauses on scene inactivity, and persists a recovery snapshot after each action.
6. **Medium: fixed phone-width layout.** The web container maxed out at 480px with hidden body overflow. Native layout reacts to current GeometryReader size and respects system safe areas. Following user feedback, the board and keypad always stack vertically; extra height shows more digits. A separate local-scene helper requests a quarter turn for wide iPhone windows, without using orientation to choose the layout. No global screen/window lookup or device-model detection.
7. **Medium: accidental reset.** Old C key erased progress without confirmation. Confirmations now protect restarts and entering historical review over an unfinished round.
8. **Medium: release infrastructure absent.** Added Xcode project/scheme, app icon catalog, privacy required-reason declarations, Game Center entitlement, Chinese/English UI, metadata, support/privacy site sources, and tests.
9. **Low: web accessibility.** Removed zoom lock and labeled legacy C/M buttons. Native controls have descriptive accessibility labels, non-color error symbols, larger-text layout, and keyboard shortcuts.

## Verification evidence

- Initial universal simulator Debug build: passed using Xcode 27.2.
- Native core: 12 XCTest cases passed, 0 failures on iOS 27.2 Duo runtime.
- Duo UI automation initially failed before executing methods: test runner aborted during setup. This is not a passed UI suite.
- Initial live Duo visual check found a compact-screen problem: keypad below the first viewport. Tight compact layout implemented in response; final verification is recorded in RELEASE.md.
- Layout static review by a separate reviewer covered all Swift sources, Info.plist, and project configuration. Launch screen present; iPad orientations complete; no full-screen opt-out or deprecated global geometry APIs.
- Game Center service is compiled but requires account-side setup and authenticated sandbox submission verification. No claim of working production leaderboard is made from compilation alone.

## Intentional differences from browser version

No automatic public nickname upload, no legacy browser score import, no time bonus rewarding incorrect fast guesses. Native local data is isolated from Safari localStorage. Global scores are perfect uninterrupted challenges only. The legacy web app remains a separate product and does not inherit native persistence or Game Center.

## References

- https://developer.apple.com/iphone-duo/prepare/
- https://developer.apple.com/news/?id=kkphp5qo
- https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards/
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- https://developer.apple.com/app-store/review/guidelines/
