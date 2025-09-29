# Code Signing Setup for RecordMe

## Current Status
The app currently builds **without code signing** for easy distribution. Users will see a warning on first launch but can bypass it by right-clicking and selecting "Open".

## Setting Up Code Signing (Optional)

If you want to remove the "unidentified developer" warning, you'll need:

### 1. Apple Developer Account
- Cost: $99/year
- Sign up at: https://developer.apple.com

### 2. Developer ID Certificate
1. Open Xcode
2. Go to Xcode → Preferences → Accounts
3. Add your Apple ID
4. Download certificates

### 3. Update GitHub Secrets
Add these to your GitHub repository secrets:

- `MACOS_CERTIFICATE`: Base64 encoded Developer ID certificate
- `MACOS_CERTIFICATE_PWD`: Certificate password  
- `KEYCHAIN_PASSWORD`: Random password for keychain

### 4. Update Workflow
Uncomment the code signing sections in `.github/workflows/build-release.yml`

## For Now
The current setup works fine for:
- Personal use
- Open source distribution
- Testing and development

Users just need to right-click → "Open" on first launch.

## Alternative: Notarization
For professional distribution, you'd also need:
- Notarization with Apple
- Stapling the notarization ticket
- Additional workflow steps

This is optional for most use cases.