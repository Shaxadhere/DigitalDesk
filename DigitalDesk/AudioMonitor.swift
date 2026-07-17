import AVFoundation
import Combine

// MARK: - Slap Event
enum SlapSide {
    case left, right
}

struct SlapEvent {
    let side: SlapSide
    let leftAmplitude: Float
    let rightAmplitude: Float
    let timestamp: Date
}

// MARK: - AudioMonitor
/// Manages AVAudioEngine, taps the input node, and detects desk-slap transients
/// by comparing left vs. right channel amplitude via RMS.
@MainActor
final class AudioMonitor: ObservableObject {

    // ─── Published State ────────────────────────────────────────────────────────
    @Published var isListening: Bool = false
    @Published var statusMessage: String = "Idle"
    @Published var sensitivityThreshold: Float = 0.03   // 0.0 – 1.0  (lowered: MacBook RMS for a slap is ~0.03–0.15)
    @Published var leftLevel: Float = 0
    @Published var rightLevel: Float = 0
    @Published var lastSlapSide: SlapSide? = nil
    /// A new UUID is written for every confirmed slap. Views can observe this
    /// via .onChange(of:) and read lastSlapSide to know which side fired.
    @Published var slapTrigger: UUID = UUID()


    // ─── Audio Engine ────────────────────────────────────────────────────────────
    private let engine = AVAudioEngine()
    private var tapInstalled = false

    // ─── Debounce ────────────────────────────────────────────────────────────────
    /// Minimum seconds between two recognized slap events.
    private let debounceDuration: TimeInterval = 1.0
    private var lastSlapTime: Date = .distantPast

    // ─── Callback ────────────────────────────────────────────────────────────────
    /// Called on the main actor whenever a slap is confirmed.
    var onSlapDetected: ((SlapEvent) -> Void)?

    // ─── AVAudioSession (macOS uses AVCaptureDevice permissions, not AVAudioSession) ─
    // On macOS we request mic permission via AVCaptureDevice.

    /// Channel ratio for left/right classification.
    /// MacBook mic arrays are physically close — channel difference is ~5–10%,
    /// so 1.05 (5% margin) reliably separates sides without false positives.
    private let spatialRatioThreshold: Float = 1.05

    // MARK: - Public API

    func startListening() {
        guard !isListening else { return }

        // Request microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.beginCapture() }
                    else { self?.statusMessage = "Microphone access denied" }
                }
            }
        default:
            statusMessage = "Microphone access denied – check System Settings › Privacy"
        }
    }

    func stopListening() {
        guard isListening else { return }
        removeTapIfNeeded()
        engine.stop()
        isListening = false
        statusMessage = "Paused"
        leftLevel = 0
        rightLevel = 0
    }

    // MARK: - Private Engine Setup

    private func beginCapture() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // ── Validate channel count ──────────────────────────────────────────────
        // MacBook built-in mic arrays expose 2 channels.
        // If mono, we'll duplicate the single channel as a safe fallback.
        let channelCount = inputFormat.channelCount
        guard channelCount >= 1 else {
            statusMessage = "No microphone channels found"
            return
        }

        // Use the native hardware format to avoid sample-rate conversion glitches.
        let tapFormat = inputNode.outputFormat(forBus: 0)

        removeTapIfNeeded()
        
        // Disable Voice Processing to prevent macOS from downmixing to Mono
        // and aggressively silencing our "desk slaps" using echo cancellation.
        if #available(macOS 12.0, *) {
            do {
                try inputNode.setVoiceProcessingEnabled(false)
            } catch {
                print("Failed to disable Voice Processing: \(error)")
            }
        }
        
        // NOTE: installTap(onBus:bufferSize:format:block:) was deprecated in macOS 27.
        // The closure-based API still functions correctly. The deprecation is a warning
        // only — it does not block the build or affect runtime behaviour.
        // Adoption of the new async-stream API is deferred as a future improvement.
        installAudioTap(on: inputNode, format: tapFormat)
        tapInstalled = true


        do {
            try engine.start()
            isListening = true
            statusMessage = "Listening…"
        } catch {
            statusMessage = "Engine failed: \(error.localizedDescription)"
            removeTapIfNeeded()
        }
    }

    private func removeTapIfNeeded() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    /// Wraps the deprecated `installTap(onBus:bufferSize:format:block:)` call so
    /// the warning is contained in one named, documented site rather than scattered.
    /// Do NOT add @available(deprecated:) here — that re-propagates the warning
    /// to every caller, which is exactly what we want to avoid.
    private func installAudioTap(on node: AVAudioNode, format: AVAudioFormat) {
        // macOS 27 deprecated this in favour of an async-stream API.
        // It still functions correctly; migrate when the new API is stable.
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // Runs on the audio I/O thread – do NOT mutate @Published properties here.
            self?.processBuffer(buffer)
        }
    }

    // MARK: - Buffer Processing (Audio Thread)

    /// Runs on the real-time audio I/O thread.  All @Published mutations are
    /// dispatched back to the MainActor via Task.
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let numChannels = Int(buffer.format.channelCount)

        // ── Compute per-channel RMS ─────────────────────────────────────────────
        let leftRMS  = rms(channelData[0], frameCount: frameCount)

        // Stereo: use channel 1.  Mono fallback: mirror channel 0.
        let rightRMS = numChannels >= 2
            ? rms(channelData[1], frameCount: frameCount)
            : leftRMS

        // [DIAGNOSTIC LOGGING] Print RMS values every ~30 buffers to avoid console spam
        DispatchQueue.main.async {
            struct Counter { static var count = 0 }
            Counter.count += 1
            if Counter.count % 30 == 0 {
                print("🎤 Mic Check | L: \(String(format: "%.4f", leftRMS)) | R: \(String(format: "%.4f", rightRMS)) | Channels: \(numChannels)")
            }
        }

        // Capture threshold locally (safe read – Float assignment is atomic on arm64)
        let threshold = sensitivityThreshold

        // ── Update VU meters on main actor ──────────────────────────────────────
        Task { @MainActor [weak self] in
            self?.leftLevel  = leftRMS
            self?.rightLevel = rightRMS
        }

        // ── Transient detection ─────────────────────────────────────────────────
        let peak = max(leftRMS, rightRMS)
        guard peak >= threshold else { return }

        // ── Debounce ────────────────────────────────────────────────────────────
        let now = Date()
        // lastSlapTime read/write must stay on one thread; use MainActor.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard now.timeIntervalSince(self.lastSlapTime) >= self.debounceDuration else { return }
            self.lastSlapTime = now

            // ── Spatial comparison ───────────────────────────────────────────────
            let side: SlapSide
            if leftRMS > rightRMS * self.spatialRatioThreshold {
                side = .left
            } else if rightRMS > leftRMS * self.spatialRatioThreshold {
                side = .right
            } else {
                // Centred hit – treat as left by convention; you can customise.
                side = .left
            }

            self.lastSlapSide = side
            self.slapTrigger = UUID()   // fires .onChange in any observing view
            let event = SlapEvent(
                side: side,
                leftAmplitude: leftRMS,
                rightAmplitude: rightRMS,
                timestamp: now
            )

            print("""
                  ─── SLAP DETECTED ───
                  Side      : \(side == .left ? "LEFT" : "RIGHT")
                  Left RMS  : \(String(format: "%.4f", leftRMS))
                  Right RMS : \(String(format: "%.4f", rightRMS))
                  ─────────────────────
                  """)

            self.onSlapDetected?(event)
        }
    }

    // MARK: - DSP Helpers

    /// Root-Mean-Square amplitude over `frameCount` samples.
    private func rms(_ data: UnsafePointer<Float>, frameCount: Int) -> Float {
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += data[i] * data[i]
        }
        return sqrt(sum / Float(frameCount))
    }
}
