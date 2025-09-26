# Screen Recording Permission Diagnostic

## Steps to Verify and Fix Screen Recording Permissions

### 1. Check System Preferences
1. Open **System Preferences** → **Privacy & Security** → **Screen Recording**
2. Look for your app "recordme" in the list
3. Make sure it has a ✅ checkmark next to it
4. If it's not in the list or unchecked, check the box to enable it

### 2. Bundle Identifier Check
Your app's bundle identifier should be: `abbe.ca.recordme`
- This needs to match exactly in System Preferences

### 3. Restart the App
After granting permissions:
1. **Completely quit the app** (Command+Q)
2. **Restart the app** - permissions only take effect after restart

### 4. Check if App is Sandboxed
The entitlements file includes:
- `com.apple.security.screen-recording` ✅ (Added)
- `com.apple.security.app-sandbox` ✅ (Present)

### 5. Debug What You're Seeing

Run the debug tests in the app to see:
- Can the app get shareable content?
- How many displays/windows are found?
- What error messages appear?

### 6. Common Issues & Solutions

**Issue**: Permission dialog never appeared
**Solution**: The entitlement was missing - this is now fixed

**Issue**: Permission granted but still shows permission screen
**Solution**: Restart the app completely

**Issue**: App shows in System Preferences but permission denied
**Solution**: 
1. Uncheck the app in System Preferences
2. Restart the app (should trigger permission dialog again)
3. Grant permission when prompted
4. Restart the app again

### 7. Final Test
After permissions are working, you should be able to:
1. See displays and windows in the source picker
2. Select a source and see a preview
3. Start recording successfully

### Troubleshooting Commands (if needed)
Reset app permissions completely:
```bash
tccutil reset ScreenCapture abbe.ca.recordme
```
Then restart the app to get a fresh permission prompt.