import AVFoundation

/// Owns one export's reader and writer. All sample pumping runs in its worker task.
final class VideoEncodingJob: @unchecked Sendable {
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let channels: [(AVAssetReaderOutput, AVAssetWriterInput)]
    private let timeRange: CMTimeRange

    init(asset: AVAsset, videoTracks: [AVAssetTrack], audioTracks: [AVAssetTrack],
         composition: AVVideoComposition, timeRange: CMTimeRange, destination: URL,
         settings: ExportSettings) throws {
        self.timeRange = timeRange
        reader = try AVAssetReader(asset: asset)
        writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        reader.timeRange = timeRange
        writer.shouldOptimizeForNetworkUse = true
        let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        videoOutput.videoComposition = composition
        videoOutput.alwaysCopiesSampleData = false
        let size = composition.renderSize
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.bitRate(for: size),
                AVVideoExpectedSourceFrameRateKey: settings.frameRate.rawValue,
                AVVideoMaxKeyFrameIntervalKey: settings.frameRate.rawValue * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        guard reader.canAdd(videoOutput), writer.canAdd(videoInput) else {
            throw VideoExportError.failed("This video cannot be encoded as H.264.")
        }
        reader.add(videoOutput)
        writer.add(videoInput)
        var channels: [(AVAssetReaderOutput, AVAssetWriterInput)] = [(videoOutput, videoInput)]
        if !audioTracks.isEmpty {
            let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false
            ])
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 160_000
            ])
            guard reader.canAdd(audioOutput), writer.canAdd(audioInput) else {
                throw VideoExportError.failed("This recording's audio cannot be exported.")
            }
            reader.add(audioOutput)
            writer.add(audioInput)
            channels.append((audioOutput, audioInput))
        }
        self.channels = channels
    }

    func run(progress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        do {
            try Task.checkCancellation()
            guard writer.startWriting() else { throw writer.error ?? VideoExportError.incomplete }
            writer.startSession(atSourceTime: timeRange.start)
            guard reader.startReading() else { throw reader.error ?? VideoExportError.incomplete }
            var finished = Set<Int>()
            var lastProgress = 0.0
            while finished.count < channels.count {
                try Task.checkCancellation()
                var appended = false
                for (index, channel) in channels.enumerated() where !finished.contains(index) {
                    let (output, input) = channel
                    guard input.isReadyForMoreMediaData else { continue }
                    let sample = autoreleasepool { output.copyNextSampleBuffer() }
                    if let sample {
                        guard input.append(sample) else { throw writer.error ?? VideoExportError.incomplete }
                        appended = true
                        if index == 0 {
                            let fraction = (sample.presentationTimeStamp.seconds - timeRange.start.seconds) / timeRange.duration.seconds
                            if fraction - lastProgress >= 0.01 {
                                lastProgress = fraction
                                await progress(min(0.99, max(0, fraction)))
                            }
                        }
                    } else {
                        if reader.status == .failed { throw reader.error ?? VideoExportError.incomplete }
                        input.markAsFinished()
                        finished.insert(index)
                    }
                }
                if writer.status == .failed { throw writer.error ?? VideoExportError.incomplete }
                if !appended { try await Task.sleep(nanoseconds: 2_000_000) }
            }
            writer.endSession(atSourceTime: CMTimeRangeGetEnd(timeRange))
            await writer.finishWriting()
            try Task.checkCancellation()
            guard writer.status == .completed else { throw writer.error ?? VideoExportError.incomplete }
            await progress(1)
        } catch {
            if reader.status == .reading { reader.cancelReading() }
            if writer.status == .writing { writer.cancelWriting() }
            throw error
        }
    }
}
