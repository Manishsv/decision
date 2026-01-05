# Code Signing Issue Fix

## Problem

When building the macOS app, you may encounter this error:
```
resource fork, Finder information, or similar detritus not allowed
Command CodeSign failed with a nonzero exit code
```

## Solution

This is a known macOS build issue. For development builds, code signing has been disabled in the Xcode project. If you still encounter this error, try:

### Option 1: Clean and rebuild
```bash
flutter clean
rm -rf build/
xattr -cr .
flutter pub get
flutter run -d macos
```

### Option 2: Build without code signing (if needed)
The Xcode project is already configured to skip code signing for Debug builds. If issues persist, you can verify the settings in Xcode:
- Open `macos/Runner.xcworkspace` in Xcode
- Select the Runner target
- Go to Signing & Capabilities
- Ensure "Automatically manage signing" is unchecked for Debug builds

### Option 3: For production builds
For Release builds, you'll need to configure proper code signing:
1. Enable code signing in Xcode
2. Configure your Apple Developer certificate
3. Set up provisioning profiles

Note: For MVP development, unsigned Debug builds are sufficient.
