# Pocket Beings

Seven tiny people live in a town in your pocket. They rob, bribe, run for office and print money while you watch. Tap to meddle.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black) ![SwiftUI + SpriteKit](https://img.shields.io/badge/SwiftUI-SpriteKit-orange) ![Built on GitHub Actions](https://img.shields.io/badge/built%20on-GitHub%20Actions%20macOS-2088FF)

**[Download Pocket Beings on the App Store](https://apps.apple.com/app/id6812787188)**

<p align="center">
  <img src="fastlane/screenshots/en-US/iPhone%2017%20Pro%20Max-01_Title.png" width="250" alt="Pocket Beings screenshot">
  <img src="fastlane/screenshots/en-US/iPhone%2017%20Pro%20Max-02_Town.png" width="250" alt="Pocket Beings screenshot">
  <img src="fastlane/screenshots/en-US/iPhone%2017%20Pro%20Max-03_Meddle.png" width="250" alt="Pocket Beings screenshot">
</p>

A small emergent-society game. Every couple of seconds somebody does something: a being with no money steals, one with no friends starts giving coins away, one with no title runs for office and, once it holds the Crown, prints money and drives up prices. Gangs and book clubs get founded, someone is exiled by vote, and a stranger moves into the empty house. It all shows up in the town newspaper, one line at a time.

## Features

- A live town of seven beings with coins, businesses, factions, gangs, heat, offices and rank
- Tap anyone to open their file, then meddle: give 50 coins, rob them for someone else, jail them, crown them, exile them
- The town remembers: gifts make friends, robberies make grudges
- Close the app and the town keeps going; the paper tells you what you missed
- A yard (SpriteKit) where the beings wander, stop to think and bump into each other

## Privacy

No network code at all. No accounts, no ads, no in-app purchases, no subscription, no internet connection; nothing is collected. The town is saved on the device in `town.json`.

## How it works

The society engine is the model-free half of [BEINGS](https://beings-phi.vercel.app) (`lib/verbs.ts`, `power.ts`, `offices.ts`) ported to Swift, with the chat, the language model and the server removed.

| File | What it does |
| --- | --- |
| `Sources/Engine/Society.swift` | The whole game as pure functions over a `Town`: verbs, power, offices, money printing, jail, exile |
| `Sources/Engine/Words.swift` | Every word the town can use (all made up) |
| `Sources/App/TownModel.swift` | Holds the town, runs the clock, saves |
| `Sources/App/YardView.swift` | The SpriteKit yard |
| `Sources/App/Screens.swift` | The title screen, the town, and the windows on top |
| `Sources/App/Theme.swift` | The look: a desktop from about 2001, bevelled panels and a blue title bar |
| `Tests/UnitTests/SocietyTests.swift` | Engine tests: same seed gives the same town, nobody goes negative, coins only come from printing and luck, every verb gets used, jail ends, meddling is remembered |
| `Tests/ScreenshotTests/` | UI test that captures the store screenshots (fastlane `snapshot`) |

## Built without a Mac

Written on a Windows PC and built, tested, signed and submitted by a GitHub Actions macOS runner. `project.yml` is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec (the `.xcodeproj` is generated on the runner, never committed), and one manual workflow, `.github/workflows/appstore.yml`, has five modes:

```
Actions -> App Store -> compile       build + unit tests
                        screenshots   store screenshots as an artifact
                        review_video  the app playing itself from the home screen
                        dry_run       build, sign, upload; do not submit
                        release       everything, including Submit for Review
```

Signing imports a distribution certificate from a secret into a throwaway keychain, and [fastlane](https://fastlane.tools) fetches the App Store profile with an App Store Connect API key. The listing is managed from Windows without a binary: `python Store/asc.py create-app`, `python Store/listing.py finish`.

## Build and run

With a Mac and Xcode 26:

```bash
brew install xcodegen
xcodegen generate
open PocketBeings.xcodeproj
```

Run the `PocketBeings` scheme on an iPhone simulator; `Cmd+U` runs the engine tests. Without a Mac: fork, then run the App Store workflow in `compile` mode. Releasing needs the secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`, `DEVELOPMENT_TEAM`, `DIST_CERT_P12` and `DIST_CERT_PASSWORD`.

Every being is a made-up cartoon character; no real person, company, place or event appears in the game.

---

**More apps built the same way:** [Chain](https://github.com/Mattbusel/chain), [Ironbook](https://github.com/Mattbusel/ironbook), [Quiver](https://github.com/Mattbusel/quiver), [Race Fuel](https://github.com/Mattbusel/race-fuel), [Minder](https://github.com/Mattbusel/minder), [Baseline Ledger](https://github.com/Mattbusel/baseline-ledger), [Fairway Ledger](https://github.com/Mattbusel/fairway-ledger), [Odometer](https://github.com/Mattbusel/odometer), [Rooms](https://github.com/Mattbusel/rooms), [Clockout](https://github.com/Mattbusel/clockout), [Curve](https://github.com/Mattbusel/curve), [Pricebook](https://github.com/Mattbusel/pricebook), [Chores](https://github.com/Mattbusel/chores), [Pawprint](https://github.com/Mattbusel/pawprint), [Glyphstorm](https://github.com/Mattbusel/glyphstorm), [Clear the Strait](https://github.com/Mattbusel/clear-the-strait).


## Hire the author

I designed, built and shipped this app myself. **Want one like it for your business?** I build native iOS apps from prototype to App Store launch, fixed price. [Services and pricing](https://mattbusel.github.io/) · [Email](mailto:mattbusel@gmail.com) · [LinkedIn](https://www.linkedin.com/in/matthewbusel/)
