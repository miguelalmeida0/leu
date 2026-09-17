# Physical-device installation repair

## Root cause and binary architecture

The actual failed `Debug-iphoneos/Shelf.app/Frameworks/LeuQwenNative.framework`
contains an **arm64 Mach-O DYLIB**, with the expected `@rpath` install name and
an iPhoneOS load command. It is dynamic and must remain embedded.

The packaging script put `ThirdPartyNotices.txt` in a top-level `Resources`
directory inside the otherwise flat iOS framework. Codesign consequently treated
the bundle with the wrong layout: its output said **`Info.plist=not bound`** and
used `LeuQwenNative` instead of the plist's bundle identifier. The on-disk plist
actually contained `FMWK` and `CFBundleExecutable`; adding those keys alone would
not address the observed defect. Name and version fields were also empty, and
the default CMake template included an irrelevant icon key.

`layout-probe.json` isolates the layout effect: copies of the same binary and
plist were ad-hoc signed with and without that directory. Only the flat copy
bound the plist and used `dev.leu.qwen-native`. This establishes the packaging
defect; repair of the physical installation remains unverified.

The original app's deep/strict signature check passes despite the unbound plist.
That check alone is insufficient. The original-app pre-install gate preserves
the failed metadata, binding and layout checks. The first gate also unnecessarily
required `CFBundleInfoDictionaryVersion` in the third-party ONNX framework; the
final gate applies that requested field to Qwen only. ONNX was not changed.

## Packaging fix

- Keep the existing dynamic framework and Swift package binary target.
- Provide a framework-specific CMake plist template with valid name, identifier,
  executable, package type, dictionary version and non-empty bundle versions.
- Put iOS/simulator notices at framework root; retain the versioned macOS layout.
- Derive SDK/platform/build metadata from the actual selected Apple SDK and Xcode.
- Add a named build-directory suffix so repair rebuilds preserve prior outputs.
- Add `scripts/check-qwen-ios-package.py` to inspect the final app before install.

All three native slices rebuilt successfully with:

```sh
python3 scripts/prepare-qwen-native.py --platform all --build-suffix install-repair
```

The regenerated XCFramework contains `macos-arm64`, `ios-arm64`, and
`ios-arm64-simulator` as separate slices. The device framework contains:

```text
LeuQwenNative.framework/
  LeuQwenNative
  Info.plist
  ThirdPartyNotices.txt
  Headers/LeuQwenNative.h
  Modules/module.modulemap
```

Device plist: `FMWK`, executable/name `LeuQwenNative`, identifier
`dev.leu.qwen-native`, bundle version `1`, short version `1.0.0`, dictionary
version `6.0`, supported platform `iPhoneOS`, minimum OS `17.0`, SDK
`iphoneos26.5` / build `23F81a`, Xcode build `17F113`. No icon key, nested
framework, `Resources` directory or simulator binary is in that device slice.

## Codesign and physical status

**Rebuilt framework-only probe: PASS.** An isolated copied framework signed
ad-hoc binds all 14 plist entries and passes deep/strict verification. This
does not establish the app's development signature or device installation.

**Fresh full app build: BLOCKED.** A new repair-owned DerivedData directory and
a copied pinned dependency cache were used. Xcode exited 74 during package
resolution with `permissionDenied`; see `app-build.txt`. No new signed Shelf.app
was produced, so the final app payload and its signature cannot be certified.

**Physical install: FAIL in the user's original run; repair retest NOT RUN.**
User-reported device: iPhone15,4, iOS 26.3.1, arm64; original installer error:
CoreDevice 3002, MIInstallerErrorDomain 35, `PackageInspectionFailed`.
The current tool's CoreDeviceService connection fails initialization. Xcode
Computer Use also returns `Computer Use was not approved to use Xcode`.
There is no new lowest-level MIInstaller error because no repaired app reached
installation. These environment blockers are distinct from the packaging cause.

**Launch and Teach controls: NOT RUN.** No model download or inference was attempted.

## Scope and commit

Changed packaging source: `Native/Qwen/CMakeLists.txt`,
`Native/Qwen/FrameworkInfo.plist.in`, `scripts/prepare-qwen-native.py`,
`scripts/check-qwen-ios-package.py`, and this repair's evidence directory.
The pre-existing modified Xcode project is preserved and is not part of this
repair's edits. Frozen prompt, benchmark settings, semantic guard and native
inference source hashes remain unchanged.

**No new commit or push.** The requested install-and-launch gate has not passed.
Base/pushed commit remains `85da85aeab4893f9e796cb950f74f620e4a5f12a`.
After physical acceptance, commit only the packaging repair with:
`fix: package Qwen native runtime for iOS device`, then push normally to
`codex/qwen-local-understanding`.

## Next physical test

Run the following from a local Terminal with normal Xcode access, after selecting
the connected iPhone15,4 in Xcode. This builds into a new directory and checks
the final app before installation; it does not remove old DerivedData:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuQwenLocal
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$PWD/.qwen-local/physical-install-check" \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile build
python3 scripts/check-qwen-ios-package.py \
  .qwen-local/physical-install-check/Build/Products/Debug-iphoneos/Shelf.app \
  --output docs/qwen-local/install-repair/physical-app-preinstall.json
```

Only if that gate passes, install that exact Shelf.app using Xcode Devices and
Simulators' Installed Apps `+` control on the actual phone. Launch Leu, open Teach
Leu, and verify the offline controls/toggle without downloading the model. Record
install and launch separately. Do not install the stale original app. Alternatively,
enable Xcode Computer Use access so this task can perform the remaining UI steps.

References: [Apple bundle layout](https://developer.apple.com/documentation/bundleresources/placing-content-in-a-bundle),
[CMake framework plist configuration](https://cmake.org/cmake/help/v4.1/prop_tgt/MACOSX_FRAMEWORK_INFO_PLIST.html).
