import AVFoundation
import CallKit

/// 收到服务器的 incoming_call 事件后，用 CallKit 弹出系统级来电界面。
/// 接听 → 播报任务内容 → 播完自动挂断。
final class CallManager: NSObject {

    static let shared = CallManager()

    private var provider: CXProvider?
    private let speech = AVSpeechSynthesizer()
    private var activeCall: UUID?
    private var pendingText = ""

    override init() {
        super.init()

        let config = CXProviderConfiguration(localizedName: "私人助理")
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]

        let p = CXProvider(configuration: config)
        p.setDelegate(self, queue: nil)
        provider = p
        speech.delegate = self
    }

    func ring(title: String, body: String, id: String) {
        Notify.cancel(id: id)

        let uuid = UUID()
        activeCall = uuid
        pendingText = body

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: title)
        update.localizedCallerName = title
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false

        provider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                print("来电弹窗失败: \(error)")
                // 退化成本地通知
                Notify.schedule(
                    id: id + "-fallback",
                    title: title,
                    body: body,
                    at: Date().addingTimeInterval(1)
                )
            }
        }
    }

    private func activateCallAudio() {
        KeepAlive.shared.stop()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("通话音频激活失败: \(error)")
        }
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.postUtteranceDelay = 0.3
        speech.speak(utterance)
    }

    private func hangUp() {
        guard let uuid = activeCall else { return }
        activeCall = nil
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        provider?.request(transaction) { _ in }
    }
}

extension CallManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        activeCall = nil
        KeepAlive.shared.start()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        activateCallAudio()
        speak(pendingText)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        speech.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        action.fulfill()
        KeepAlive.shared.start()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("通话音频已激活")
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        KeepAlive.shared.start()
    }
}

extension CallManager: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 念完自动挂断，不占着系统通话界面
        hangUp()
    }
}
