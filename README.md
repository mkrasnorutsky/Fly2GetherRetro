# Fly2GetherRetro

Fly2GetherRetro is designed for **Intel Macs running macOS High Sierra 10.13**. It targets older flight simulators, including 32-bit simulators that accept a macOS HID joystick. The app can open on newer versions of macOS. On Intel Macs, the app can request loading of the bundled driver and macOS determines whether it can load. [Apple’s 32-bit app compatibility guide](https://support.apple.com/en-us/103076)

In **Other simulators**, click **Install and Load VirtualFly**. The app asks for administrator authorization, stages the bundled driver in a temporary root-owned directory under `/Users/Shared`, requests loading with `kextload`, and removes the staging directory. It makes no persistent driver installation. **Connect to Loaded Driver** retries creating the joystick through a driver that macOS has already loaded. High Sierra may require approval in **System Preferences → Security & Privacy** before you can retry. In **X-Plane 11 or 12**, the iPhone sends controls directly to X-Plane and Retro monitors input without a driver. [Apple’s High Sierra kext approval guide](https://developer.apple.com/library/archive/technotes/tn2459/_index.html)

## Building the driver

The `vfly` target builds for Intel with deployment target 10.13. The driver bundle ID is `com.mkrasnorutsky.driver.vfly`. Its IOKit class names and the client framework use the corresponding namespace.

The **Build VirtualFly kext** phase compiles the driver into Xcode’s derived files directory and embeds it in the app. Set `VFLY_SDKROOT` in the app target’s build settings or pass `VFLY_SDKROOT=/path/to/MacOSX10.13.sdk` to `xcodebuild`. By default, the phase looks for `MacOSX10.13.sdk` under `~/Library/Developer/SDKs`. It uses the High Sierra SDK’s kernel headers and startup libraries with the classic linker. The generated kext is unsigned. Kernel loading on High Sierra remains unverified.

## Building the app

Open `Fly2GetherRetro.xcodeproj` and select the `Fly2GetherRetro` scheme. The project includes its UDP protocol header, so the original FlightJoy checkout is unnecessary.

```sh
xcodebuild -project Fly2GetherRetro.xcodeproj -scheme Fly2GetherRetro \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath ./DerivedData VFLY_SDKROOT=/path/to/MacOSX10.13.sdk build
```

The Release app is in `DerivedData/Build/Products/Release`. The project uses the configured Developer ID for signing. For a local compile without a signing identity, add `CODE_SIGNING_ALLOWED=NO`.

## Signing and distribution

With SIP enabled, High Sierra requires a valid kext-enabled Developer ID signature and may require user approval. Ordinary Developer ID app signing is insufficient for the driver. Apple documents temporary SIP changes for local development. The app uses the system loader and its normal security checks. For public distribution, verify VirtualFly redistribution rights, use the appropriate Apple signing and notarization process, and test on High Sierra with SIP enabled. [Apple’s kext signing requirements](https://developer.apple.com/library/archive/technotes/tn2206/) · [Apple’s SIP development guidance](https://developer.apple.com/documentation/security/disabling-and-enabling-system-integrity-protection) · [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)

## License and authorship

The code is licensed under the [MIT License]
