import AVFoundation

/// 用循环播放的无声音频把 App 保活在后台。
/// 没有它，App 一旦被挂起，CallKit 就没法弹出来电。
final class KeepAlive {
    static let shared = KeepAlive()

    private var player: AVAudioPlayer?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    var isRunning: Bool { player?.isPlaying ?? false }

    func start() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("audio session 配置失败: \(error)")
        }

        if player == nil {
            player = try? AVAudioPlayer(data: Self.silentWav())
            player?.numberOfLoops = -1
            player?.volume = 1.0
        }
        player?.play()
    }

    func stop() {
        player?.stop()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        if type == .ended {
            start()
        }
    }

    /// 生成一段 1 秒的静音 WAV（8kHz / 16bit / 单声道）
    private static func silentWav(seconds: Double = 1.0, rate: Int = 8000) -> Data {
        let samples = Int(Double(rate) * seconds)
        let dataSize = samples * 2
        var data = Data()

        func put(_ s: String) { data.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: UInt32) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
        }
        func u16(_ v: UInt16) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
        }

        put("RIFF"); u32(UInt32(36 + dataSize)); put("WAVE")
        put("fmt "); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        put("data"); u32(UInt32(dataSize))
        data.append(Data(count: dataSize))
        return data
    }
}
