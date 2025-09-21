import SwiftUI
import AVKit

struct VideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // add in future
    }
}

struct MyVideoEditingView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var startTime: Double = 0
    @State private var endTime: Double = 1
    @State private var duration: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Video Editor")
                .font(.largeTitle)
                .padding()
            
            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 400)
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(ProgressView())
            }
            
            // Timeline/trim control
            VStack(spacing: 12) {
                Text("Trim Video")
                    .font(.headline)
                
                HStack {
                    Text(formatTime(startTime))
                    Slider(value: $startTime, in: 0...endTime) { _ in
                        seek(to: startTime)
                    }
                    Slider(value: $endTime, in: startTime...duration) { _ in
                        seek(to: endTime)
                    }
                    Text(formatTime(endTime))
                }
                .padding(.horizontal)
            }
            .padding()
            
            // Playback controls
            HStack(spacing: 40) {
                Button(action: {
                    seek(to: max(startTime, 0))
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title)
                }
                
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                Button(action: {
                    seek(to: min(endTime, duration))
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title)
                }
            }
            .padding()
            
            // Action buttons
            HStack(spacing: 20) {
                actionButton("Trim", systemName: "scissors") {
                    trimVideo()
                }
                
                actionButton("Crop", systemName: "crop") {
                    // Crop functionality
                }
                
                actionButton("Effects", systemName: "wand.and.stars") {
                    // Effects functionality
                }
                
                actionButton("Save", systemName: "square.and.arrow.down", isProminent: true) {
                    saveVideo()
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func setupPlayer() {
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        
        // Get video duration
        Task {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            self.duration = durationSeconds
            self.endTime = durationSeconds
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    private func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func trimVideo() {
        // Implement video trimming logic
    }
    
    private func saveVideo() {
        // Save video logic
    }
    
    private func actionButton(_ title: String, systemName: String, isProminent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(.title2, weight: .medium))
                    .foregroundColor(isProminent ? .white : .primary)
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(isProminent ? .white : .primary)
            }
            .frame(width: 80, height: 60)
        }
        .buttonStyle(ModernButtonStyle(color: isProminent ? .accentColor : Color(.controlAccentColor), isProminent: isProminent))
        .help(title)
    }
} 
