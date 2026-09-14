# Install Shelf on your iPhone

## 1. Prepare the Mac once

Install **full Xcode** from Apple, not only Command Line Tools. Use Xcode 16 or later with an iOS SDK compatible with your phone and a macOS version supported by that Xcode release. Open Xcode, accept the license, and allow its first-launch components to install.

For simulator use, install an iOS 17+ runtime under Xcode Settings → Components (called Platforms in some versions). Create an iPhone simulator in Window → Devices and Simulators when none exists.

No Node, npm, package manager, paid API, external service, CocoaPods, or XcodeGen is required.

## 2. Open the delivered folder

Unzip **Shelf-iPhone-Source.zip**. Open Terminal in the extracted `Shelf` folder. For a default Downloads extraction:

```bash
cd "$HOME/Downloads/Shelf"
./run.sh
```

That command builds and starts the simulator. It does **not** sign or deploy to your physical phone.

For physical installation:

```bash
cd "$HOME/Downloads/Shelf"
./run.sh --xcode
```

If the extracted folder is elsewhere, use its actual path. Dragging the folder from Finder into Terminal after `cd ` inserts the path safely.

## 3. Configure signing in Xcode

1. Xcode → Settings → Accounts: add your Apple Account.
2. Select the blue **Shelf project**, then the **Shelf app target**.
3. Under Signing & Capabilities, leave **Automatically manage signing** enabled.
4. Select your **Personal Team** or paid development team.
5. If Apple says the bundle identifier is unavailable, replace `dev.shelf.personal` with a unique identifier, for example `com.yourname.shelf.personal`. Use your own stable identifier.

There are no App Groups, iCloud, push, microphone, camera, AI, or cloud-service entitlements to configure. Shelf uses on-device speech synthesis for page playback; it does not record audio.

## 4. Connect the phone and run

Connect the iPhone to your Mac, unlock it, and accept Trust prompts. In Xcode's destination menu select your physical iPhone, not a simulator or “Any iOS Device.”

Enable **Developer Mode** under iPhone Settings → Privacy & Security when Xcode/iOS requests it; this involves restarting the phone. Depending on iOS/account state, you may also need to trust your development identity under Settings → General → VPN & Device Management.

Press **Command-R**. Keep the phone unlocked during initial preparation. Shelf's icon should appear when Xcode successfully signs, installs, and launches the build. There is no pre-signed universal IPA in this download: signing is tied to your Apple identity.

## Free signing and renewal

Apple's Personal Team permits personal-device testing without paid developer-program enrollment, but its provisioning expires after **seven days**. Reconnect and run the same project from Xcode again to renew the development build.

Do not delete Shelf to renew signing. Keep the same bundle identifier and team. Export your `.shelfbackup` before changing identities, uninstalling, resetting the device, or making a major update. Reinstallation/data preservation needs to be verified on your actual signing setup; do not make the app's only copy your only backup.

Development certificate verification may require an internet connection during installation/initial launch. Shelf's document functions themselves do not depend on a server after import.

## First use

The initial shelf contains six removable original study samples, each four pages. Cold launch now opens with the full Shelf mascot scene before handing off to the library. Reader controls include Read/Original modes, page speech, Mark, Study and Text-size tools. Open one, move to page two, close, and reopen. Try a bookmark and a page note before importing important files.

Tap **+** to import PDFs. Or use a source app's sharing/open-in menu where Shelf appears. Shelf copies the original into its own local storage; renaming the display title never renames or edits the source.

Settings → Export backup opens the native share sheet. Save a backup outside Shelf, then verify Settings → Restore backup can merge it back. The backup is unencrypted, so choose an appropriate location.

## Troubleshooting

| Symptom | Action |
|---|---|
| `xcode-select` or `xcodebuild` error | Open full Xcode and complete first-launch setup. The launcher uses `/Applications/Xcode.app` when only Command Line Tools were selected. |
| No simulator found | Install an iOS 17+ runtime and create an iPhone simulator. |
| Wrong simulator chosen | Run `SHELF_SIMULATOR_UDID="YOUR-UUID" ./run.sh`; UUIDs appear in `xcrun simctl list devices available`. |
| Signing requires a team | Choose the Shelf app target, select your Personal Team, and use a unique bundle ID. |
| Phone unavailable | Unlock/trust it, enable Developer Mode, and use Xcode compatible with its iOS version. |
| App no longer launches after a week | Renew through Command-R using the same signing identity. Do not uninstall first. |
| Document does not appear in another app's share menu | Save to Files and import with Shelf's + button. This project registers open-in handling, not a separate Share Extension. |
| Scanned PDF has no search results | This release searches embedded text; OCR is intentionally absent. Page notes/bookmarks still work. |
| Library recovery warning | Review recent metadata changes and export a new backup. Never delete original files to dismiss the warning. |

## Apple references

Verified for this handoff on September 9, 2026:

- Account and free Personal Team limits: https://developer.apple.com/help/account/basics/about-your-developer-account/
- Running on simulated/physical devices: https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices
- Developer Mode: https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
- Xcode downloads/support: https://developer.apple.com/xcode/

Apple can change signing policies and UI labels. The project's own code cannot bypass them.
