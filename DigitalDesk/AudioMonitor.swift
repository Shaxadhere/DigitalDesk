import AVFoundation
import Combine
import SoundAnalysis
import CoreML

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
/// Manages AVAudioEngine and uses CoreML SoundAnalysis to classify "LeftSlap" vs "RightSlap"
@MainActor
final class AudioMonitor: ObservableObject {

    // ─── Published State ────────────────────────────────────────────────────────
    @Published var isListening: Bool = false
    @Published var statusMessage: String = "Idle"
    @Published var sensitivityThreshold: Float = 0.03   // Retained for UI compatibility
    @Published var leftLevel: Float = 0
    @Published var rightLevel: Float = 0
    @Published var lastSlapSide: SlapSide? = nil
    @Published var slapTrigger: UUID = UUID()

    // ─── Transient Gating ────────────────────────────────────────────────────────
    /// Stores the last few RMS peaks (approx 0.2 seconds of history) to ensure a loud
    /// transient actually occurred around the time the ML model classified a slap.
    private var recentPeaks: [Float] = []

    // ─── Audio Engine & ML ───────────────────────────────────────────────────────
    private let engine = AVAudioEngine()
    private var tapInstalled = false
    
    private var analyzer: SNAudioStreamAnalyzer?
    private var resultsObserver: SlapResultsObserver?

    // ─── Debounce ────────────────────────────────────────────────────────────────
    private let debounceDuration: TimeInterval = 1.0
    private var lastSlapTime: Date = .distantPast

    // ─── Callback ────────────────────────────────────────────────────────────────
    var onSlapDetected: ((SlapEvent) -> Void)?

    // MARK: - Public API

    func startListening() {
        guard !isListening else { return }

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
            statusMessage = "Microphone access denied"
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
        let tapFormat = inputNode.outputFormat(forBus: 0)

        removeTapIfNeeded()
        
        // Setup ML Analyzer
        analyzer = SNAudioStreamAnalyzer(format: tapFormat)
        resultsObserver = SlapResultsObserver(monitor: self)
        
        do {
            let mlModel = try DeskSlapClassifier(configuration: MLModelConfiguration()).model
            let request = try SNClassifySoundRequest(mlModel: mlModel)
            try analyzer?.add(request, withObserver: resultsObserver!)
        } catch {
            print("Failed to setup ML model: \(error)")
            statusMessage = "ML Model Error: \(error.localizedDescription)"
            return
        }

        installAudioTap(on: inputNode, format: tapFormat)
        tapInstalled = true

        do {
            try engine.start()
            isListening = true
            statusMessage = "Listening (ML Active)…"
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
        analyzer = nil
        resultsObserver = nil
    }

    private func installAudioTap(on node: AVAudioNode, format: AVAudioFormat) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processBuffer(buffer, time: time)
        }
    }

    // MARK: - Buffer Processing

    private func processBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Feed ML Analyzer
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }
        
        // Keep RMS for visual UI meters
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let leftRMS = rms(channelData[0], frameCount: frameCount)
        let rightRMS = Int(buffer.format.channelCount) >= 2 ? rms(channelData[1], frameCount: frameCount) : leftRMS
        let peak = max(leftRMS, rightRMS)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.leftLevel = leftRMS
            self.rightLevel = rightRMS
            
            // Keep a rolling window of the last 100 peaks (~2.0 seconds) to account for ML processing delay
            self.recentPeaks.append(peak)
            if self.recentPeaks.count > 100 { self.recentPeaks.removeFirst() }
        }
    }

    // MARK: - ML Hit Handler
    
    nonisolated func handleMLHit(label: String, confidence: Double) {
        // Only accept high confidence slaps
        guard confidence >= 0.85 else { return }
        
        let lowerLabel = label.lowercased()
        let side: SlapSide
        
        if lowerLabel.contains("left") {
            side = .left
        } else if lowerLabel.contains("right") {
            side = .right
        } else {
            return // Not a slap
        }
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            // ── TRANSIENT GATE: Did a loud sound actually happen? ──
            let maxRecentPeak = self.recentPeaks.max() ?? 0
            
            // Print diagnostic log for why an ML hit might be ignored
            print("🧠 ML Output: [\(label)] Conf: \(String(format: "%.2f", confidence)) | Peak in last 2s: \(String(format: "%.3f", maxRecentPeak)) | Required Threshold: \(String(format: "%.3f", self.sensitivityThreshold))")
            
            guard maxRecentPeak >= self.sensitivityThreshold else { return }
            
            let now = Date()
            guard now.timeIntervalSince(self.lastSlapTime) >= self.debounceDuration else { return }
            self.lastSlapTime = now

            self.lastSlapSide = side
            self.slapTrigger = UUID()
            
            let event = SlapEvent(
                side: side,
                leftAmplitude: maxRecentPeak,
                rightAmplitude: maxRecentPeak,
                timestamp: now
            )

            print("🤖 ML + TRANSIENT SLAP DETECTED: \(label) (Peak: \(String(format: "%.3f", maxRecentPeak)), Conf: \(String(format: "%.2f", confidence)))")
            self.onSlapDetected?(event)
        }
    }

    private func rms(_ data: UnsafePointer<Float>, frameCount: Int) -> Float {
        var sum: Float = 0
        for i in 0..<frameCount { sum += data[i] * data[i] }
        return sqrt(sum / Float(frameCount))
    }
}

// MARK: - ML Observer
final class SlapResultsObserver: NSObject, SNResultsObserving {
    private weak var monitor: AudioMonitor?
    
    init(monitor: AudioMonitor) {
        self.monitor = monitor
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        guard let classification = result.classifications.first else { return }
        
        monitor?.handleMLHit(label: classification.identifier, confidence: classification.confidence)
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("ML Analysis failed: \(error)")
    }
}
