# RecordMe

A native macOS screen recording application built with SwiftUI and ScreenCaptureKit, featuring real-time camera overlay and modern interface design.

## Tech Stack

- **SwiftUI** - Modern declarative UI framework for macOS
- **ScreenCaptureKit** - Apple's framework for high-performance screen capture
- **AVFoundation** - Video encoding, audio processing, and media handling
- **CoreImage** - Image processing and compositing for camera overlay
- **Swift** - Primary programming language

## Description

RecordMe is a powerful yet intuitive screen recording application designed specifically for macOS. It provides seamless screen capture with optional camera overlay, allowing users to create professional recordings with both screen content and webcam feed simultaneously. The application features a clean, modern interface that makes it easy to select recording sources, configure audio settings, and manage recordings.

The app leverages Apple's latest ScreenCaptureKit framework for optimal performance and system integration, ensuring smooth recording with minimal impact on system resources.

## Features

- **High-Quality Screen Recording** - Record at up to 60fps in 1080p resolution
- **Camera Overlay** - Real-time webcam integration with customizable positioning
- **Flexible Source Selection** - Choose from individual windows, applications, or entire displays
- **Audio Recording** - Support for both system audio and microphone input
- **MP4 Output Format** - Universal compatibility with H.264 video and AAC audio encoding
- **Live Preview** - Real-time preview of recording content before starting
- **Modern Interface** - Clean, intuitive design following macOS design guidelines
- **Automatic File Management** - Recordings saved directly to Downloads folder with timestamps
- **Performance Optimized** - Efficient memory usage and CPU optimization
- **System Integration** - Native macOS permissions and security model

## Installation

### Download (Recommended)
**[Download Latest Release](https://github.com/abbeazale/recordme/releases)** 

1. Download `RecordMe.dmg` from the releases page
2. Open the DMG and drag RecordMe to your Applications folder
3. Launch RecordMe and grant screen recording permissions when prompted

### Homebrew (Coming Soon)
```bash
brew install --cask recordme
```

### Building from Source
For developers who want to build from source:

#### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

#### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/abbeazale/recordme.git
   cd recordme
   ```

2. Open the project in Xcode:
   ```bash
   open recordme.xcodeproj
   ```

3. Build and run the project (⌘+R)

> **Note**: Building from source requires granting screen recording permissions and may show security warnings since the app isn't code-signed.