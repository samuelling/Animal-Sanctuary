# Animal Sanctuary for iPhone and iPad

The same game as `index.html`, bundled into a SwiftUI app that runs it full screen in a `WKWebView`. Nothing about the game is rewritten: the app is a frame around it, plus native saving.

## Build it

1. Open `ios/AnimalSanctuary.xcodeproj` in Xcode 16 or later.
2. Pick your iPhone or iPad and press Run. Signing is set to Automatic with team `Y4HDFDP479` and bundle ID `com.samuelling.animalsanctuary` (the same pattern as Vocal Fish Fry).
3. Debug builds are inspectable: on the Mac, Safari ▸ Develop ▸ your device ▸ Sanctuary.

Every push that touches the game or `ios/` is compile-checked on GitHub's macOS runner (`.github/workflows/ios.yml`, unsigned).

## After changing the game

```
python3 ios/tools/sync_web.py      # copies index.html into ios/AnimalSanctuary/Game/
python3 ios/tools/make_icon.py     # only if you want the icon redrawn (it reads the Puffbun sprite from index.html)
```

CI fails if `Game/index.html` is older than `index.html`, so the app can't quietly fall behind the web version.

`sync_web.py` makes four changes on the way in:
- Pixelify Sans and Silkscreen come from bundled font files instead of Google Fonts.
- PeerJS (co-op) comes from the bundled `peerjs.min.js` instead of unpkg.
- The cabinets in `IOS_HIDDEN_CABINETS` are left out of the arcade, and the hall closes the gap. This is currently only MEGAzine BBS (see App Review below).
- It adds a `<meta name="as-platform" content="ios">` marker.

So the game runs fully offline. Only the arcade cabinets (which load our other games from GitHub Pages) and co-op need the internet.

## How saving works

The game still saves to `localStorage`. At launch the app injects `Game/ios-bridge.js`, which does two things:
- It mirrors every write to `SaveStore.swift`, which writes one JSON file in Application Support/Saves.
- On the next launch, it copies the saved values back into the page before the game reads them.

What this protects:
- If WebKit ever clears its storage, the save comes back.
- The save is included in the device's iCloud or computer backup like any app data.
- The first write each launch keeps the previous file as `localStorage.previous.json`, so one bad session can be undone.
- Writes are batched about every 0.75 s and flushed when the app goes to the background.

Saves are per device for now. Cross-device sync (iCloud) would be the next step: it needs the iCloud capability and an App Store Connect setup, and fits into `SaveStore` without touching the game.

## Settings worth knowing

- **Name under the icon:** "Sanctuary". "Animal Sanctuary" gets cut off on the home screen. Change `INFOPLIST_KEY_CFBundleDisplayName`.
- **Orientation:** portrait only on iPhone, every orientation on iPad.
- **Sound:** follows the silent switch and mixes with other audio (`.ambient` in `AnimalSanctuaryApp.swift`). Switch to `.playback` if the kids should hear music with the switch on silent.
- **Links:** links that leave the game (the making-of link, "Open in its own tab") open in Safari. Arcade games play inside the cabinet.
- **Local network prompt:** iOS may ask once, the first time you play together, because co-op connects devices directly (WebRTC). The wording is in `NSLocalNetworkUsageDescription`.

## Before TestFlight / App Store

- [ ] Register the bundle ID and create the app in App Store Connect. Reserve the name early. App Store names are unique and "Animal Sanctuary" may be taken, so have a backup ready (e.g. "Animal Sanctuary: Glimmerwild").
- [ ] Play it on a real iPhone and iPad and check:
  - the touch controller and safe areas (notch and home bar)
  - sound with the silent switch both ways
  - arcade cabinets, the recursive cabinet and the back room
  - co-op between the app and the web version (both use PeerJS)
  - saves after force-quitting
- [ ] App Privacy label: "Data Not Collected". Nothing is sent to us; co-op names travel directly between players' devices. The privacy manifest (`PrivacyInfo.xcprivacy`) declares no tracking and no required-reason APIs.
- [ ] Age rating questionnaire. The Immortal Dungeon (weapons, hunting dangerous animals) counts as cartoon/fantasy violence. The game also deals with death and grief (Pop, Gran, creature and keeper lifetimes). Expect 9+ or 12+. It is not a fit for the Kids category, which forbids external links and web content.
- [ ] Encryption export: already answered "No" (`ITSAppUsesNonExemptEncryption`); HTTPS/WebRTC only.

### App Review risks to decide on

- **MEGAzine BBS** is a live board where anyone can post. Guideline 1.2 requires user-generated content to have reporting, blocking and filtering, so it is hidden in the iOS build. To bring it back, remove it from `IOS_HIDDEN_CABINETS` once the board has those tools.
- **Arcade cabinets load web games.** Guideline 4.7 allows HTML5 mini games, and these are all ours, but a reviewer may ask about them. They also need a connection; offline, a cabinet shows an empty screen.
- **The Watertown portal** recreates the real neighborhood, with the family's house as the Halloween house. That's lovely for the family build. For a public release, consider whether you want strangers to have it.
- **Co-op** uses the free public PeerJS signalling server. It's fine for family play. For a public release, consider running our own PeerServer so co-op doesn't depend on someone else's free service.

## Licences of bundled files

- Pixelify Sans and Silkscreen: SIL Open Font License (`Game/*-OFL.txt`).
- PeerJS 1.5.4: MIT (`Game/PeerJS-LICENSE.txt`).
