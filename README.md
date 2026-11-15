# π 100

Native SwiftUI pi-memory app for iPhone, iPhone Duo, and iPad, with the original browser edition retained at `index.html`.

- iOS 17 minimum; build with Xcode 27.1 or later for Duo support (developed using 27.2).
- Bundle ID: `me.zhuhong.pi100`.
- Developer/contact: Zhu Hong · zivzhu@gmail.com · https://zhuhong.me/pi100/.
- Free, no ads, no in-app purchases, no external packages.

The digit board always sits above the keypad, including on an unfolded iPhone Duo. Extra height displays more digits. A local scene preference requests a tall iPhone window on launch/display changes; system multitasking can decline it, and subsequent user rotation remains available. The layout itself never switches to side-by-side columns.

## Run

Open `ios/Pi100.xcodeproj`, select the `Pi100` scheme, and run on a simulator. For a physical device select your Apple Developer team in Signing & Capabilities. `scripts/build.sh` builds the simulator app without signing.

The checked-in Xcode project is ready to open. `python3 scripts/generate_project.py` regenerates it deterministically; this also regenerates the app manifest, privacy manifest, and icon catalog. Make persistent build-setting changes in that generator.

## Rules

Practice and Review allow hints. A hinted or incorrect digit earns no credit and is added to review. Challenge disables hints. Local challenge ranking prioritizes correct digits, then elapsed time. Global Game Center accepts only perfect 100-digit challenges without any interruption; lower time wins. Pause, backgrounding, or opening a modal disqualifies that challenge but preserves its local progress.

A monotonic clock measures time. Each input atomically saves a paused recovery snapshot, without pausing the live round. Up to 200 recent records are retained. Invalid saves remain untouched until explicit local-data reset.

## Game Center

Enable Game Center on the registered App ID and App Store Connect app. Configure a classic leaderboard:

| Setting | Value |
| --- | --- |
| ID | `me.zhuhong.pi100.perfect100` |
| Reference name | Perfect 100 — fastest time |
| Sort | Low to High |
| Submission | Best score |
| Score format | Integer with localized `ms` suffix |
| Range | 1 to 86399999 |

The app submits elapsed **milliseconds**, not seconds. Do not configure a seconds formatter against this payload. A perfect 100-second run submits 100000. Game Center access is user initiated in Results; pending qualifying records retry on connection or by tapping Retry. App ID, capability, leaderboard, signed builds, and end-to-end sandbox score verification must all be ready before release. The client is not a server-side anti-cheat system.

## Verification

```sh
xcodebuild -project ios/Pi100.xcodeproj -scheme Pi100 \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID' \
  -derivedDataPath build/DerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

`Pi100Tests` exercises digit correctness, scoring, hint exclusions, timer lifecycle, qualification, review sanitation, ranking, persistence, and corrupt-save preservation. `Pi100UITests` exercises input, hints, reset confirmation, rotation, pause/resume, relaunch restoration, and account entry points. See `docs/REVIEW.md` for findings and `docs/RELEASE.md` for remaining release steps.

## Website

`python3 scripts/build_site.py` generates the five public files under `release/site/pi100/` for the existing zhuhong.me website. The root personal website must be preserved during deployment. App Store text is in `release/metadata/`. Screenshots are actual simulator captures, not composited artwork.
