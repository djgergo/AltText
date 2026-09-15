# AltText

Alt text for your images, written on-device, by your own Mac or iPhone.

AltText is a tiny Mac + iPhone/iPad app: drop in some images, hit **Generate Alt Text**, and Apple's on-device multimodal Foundation Model writes accessible alt text for each one. Everything happens locally — no backend, no accounts, no analytics, no uploading your photos to someone else's server. If Apple Intelligence isn't available, the app just says so; it never quietly falls back to a cloud service.

## What you need

- A Mac that can run Xcode (free from the Mac App Store) — optionally an iPhone or iPad too, if you want to try it there
- macOS 27+ / iOS 27+ to open the app at all
- An Apple Intelligence-capable device and region

## Getting it running

### 1. Set up Xcode

Install Xcode from the Mac App Store, open it once, and say yes if it asks to install extra components. Then in Terminal:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Sanity check:

```sh
xcodebuild -version
```

If that prints an Xcode version, you're set.

### 2. Open the project

Clone the repo, then open `AltText.xcodeproj` in Xcode. That's it — no separate package resolution step, no waiting for dependencies (there aren't any).

### 3. Run it on your Mac

Pick `AltText > My Mac` from the scheme/destination picker at the top of the Xcode window, then hit `Command + R`. The app opens.

### 4. Run it in an iPhone/iPad Simulator

Same idea — pick `AltText > iPhone 17` (or whatever simulator you like) and `Command + R`. The Simulator boots and installs it automatically, no signing required.

### 5. Run it on your actual iPhone or iPad (optional)

- Plug the device in, unlock it, and tap **Trust** / enter your passcode if it asks.
- In Xcode: `Xcode > Settings… > Apple Accounts`, sign in with any Apple Account (a free one works fine).
- Pick your device from the destination list. Not showing up? Keep it unlocked, try a cable instead of wireless, or check `Window > Devices and Simulators`.
- First build will complain about signing — click the `AltText` target → **Signing & Capabilities** → turn on **Automatically manage signing** → pick your account under **Team**. If the bundle ID is already taken, change it to something like `com.yourname.AltText`.
- `Command + R` builds, installs, and launches it.

This is a dev install, so it'll expire after about a week — just plug in and `Command + R` again when it does.

**Developer Mode prompt on device?** `Settings > Privacy & Security > Developer Mode` → turn it on → restart → confirm after restart → back to Xcode, `Command + R`.

## "Unavailable" instead of a working Generate button

That means the app's running fine, it just can't find a ready Apple Intelligence model. Worth checking:

- Your device actually supports Apple Intelligence
- Apple Intelligence is turned on in Settings
- You're on macOS/iOS 27+
- The model has actually finished downloading
- Your region/language supports Apple Intelligence

There's no cloud fallback by design — if Apple Intelligence isn't there, Generate just stays disabled instead of quietly sending your images somewhere else.

## Running the tests

```sh
swift test
```

or `Command + U` in Xcode. Quick note: `swift test` from the terminal always runs on your Mac, regardless of what the app targets — there's no terminal equivalent for running the suite on a Simulator. Use Xcode's test navigator (`Command + U` with an iPhone/iPad destination picked) for that.

Either way, Xcode needs to be selected via `xcode-select` first (step 1 above).

## Privacy by design

Your images never leave your device. Generation runs through Apple's on-device Foundation Models framework — there's no backend, no analytics, no cloud LLM calls, no account system to speak of.

## License

MIT — see [LICENSE](LICENSE). This is a hobby project; do whatever you want with it.
