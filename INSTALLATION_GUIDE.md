# RecordMe Installation Guide

## Security Warning - This is Normal!

When you first download RecordMe, you'll see this warning:
> "Apple could not verify 'RecordMe' is free of malware..."

**This is completely normal and expected** for unsigned applications.

## How to Install RecordMe

### Method 1: Right-Click Installation (Recommended)
1. **Download** `RecordMe.dmg` from the releases page
2. **Open** the DMG file (double-click)
3. **Drag** RecordMe.app to your Applications folder
4. **Go to Applications folder** in Finder
5. **Right-click** on RecordMe.app
6. **Select "Open"** from the context menu
7. **Click "Open"** in the confirmation dialog
8. **Grant permissions** when prompted (screen recording, etc.)

### Method 2: System Preferences Override
If Method 1 doesn't work:
1. Try to open RecordMe normally (will fail with warning)
2. **Open System Preferences** → **Security & Privacy** → **General**
3. **Click "Open Anyway"** next to the RecordMe warning
4. **Click "Open"** in the confirmation dialog

### Method 3: Terminal Override (Advanced)
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /Applications/RecordMe.app
```

## Why This Happens

- RecordMe is **not code-signed** with an Apple Developer Certificate
- This requires a **$99/year Apple Developer Account**
- The app is **completely safe** - it's open source and you can review the code
- This is common for **indie/open source macOS apps**

## After First Launch

Once you successfully open RecordMe once:
- ✅ **Future launches** work normally (double-click)
- ✅ **No more warnings** appear
- ✅ **Full functionality** is available

## Permissions Required

RecordMe will ask for these permissions:
- 🎥 **Screen Recording** - Required to capture your screen
- 🎤 **Microphone** (optional) - For audio commentary
- 📷 **Camera** (optional) - For overlay functionality

Grant these permissions for full functionality.

## Still Having Issues?

1. **Make sure** you're using the official download from: `https://github.com/abbeazale/recordme/releases`
2. **Check** that you downloaded the latest version
3. **Try** the alternative installation methods above
4. **Restart** your Mac if problems persist

## Security Note

RecordMe is:
- ✅ **Open source** - You can review all code
- ✅ **Sandboxed** - Limited system access for security
- ✅ **Permission-based** - Only accesses what you explicitly allow
- ✅ **No network** - Doesn't send data anywhere

The security warning is just because it's not signed with Apple's certificate system.