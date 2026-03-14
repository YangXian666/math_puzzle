import Foundation
import AVFAudio

final class AudioManager {
    static let shared = AudioManager()

    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?
    private var isUsingA = true
    private var fadeTimer: Timer?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playLoop(resource: String, withExtension ext: String = "mp3", volume: Float = 1.0, fadeDuration: TimeInterval = 0.6) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            print("[AudioManager] Missing resource: \(resource).\(ext)")
            return
        }
        let nextPlayer = try? AVAudioPlayer(contentsOf: url)
        nextPlayer?.numberOfLoops = -1
        nextPlayer?.volume = 0.0
        nextPlayer?.prepareToPlay()

        fadeTimer?.invalidate()

        if isUsingA {
            // Crossfade A -> B
            playerB = nextPlayer
            playerB?.play()
            crossfade(from: playerA, to: playerB, targetVolume: volume, duration: fadeDuration)
            isUsingA = false
        } else {
            // Crossfade B -> A
            playerA = nextPlayer
            playerA?.play()
            crossfade(from: playerB, to: playerA, targetVolume: volume, duration: fadeDuration)
            isUsingA = true
        }
    }

    func stop(fadeDuration: TimeInterval = 0.4) {
        fadeTimer?.invalidate()
        crossfade(from: currentPlayer, to: nil, targetVolume: 0.0, duration: fadeDuration)
    }
    
    func playAchievement(resource: String = "achievement", withExtension ext: String = "mp3") {

        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            print("[AudioManager] Missing SFX: \(resource).\(ext)")
            return
        }

        do {
            // 暫停背景音
            currentPlayer?.pause()

            sfxPlayer = try AVAudioPlayer(contentsOf: url)
            sfxPlayer?.prepareToPlay()
            sfxPlayer?.play()

            let duration = sfxPlayer?.duration ?? 1

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.currentPlayer?.play()
            }

        } catch {
            print("[AudioManager] SFX error:", error)
        }
    }

    private var currentPlayer: AVAudioPlayer? { isUsingA ? playerA : playerB }

    private func crossfade(from old: AVAudioPlayer?, to new: AVAudioPlayer?, targetVolume: Float, duration: TimeInterval) {
        let steps = 24
        let interval = duration / Double(steps)
        let oldStart = old?.volume ?? 0
        let newStart = new?.volume ?? 0
        let oldDelta = -oldStart
        let newDelta = targetVolume - newStart
        var tick = 0

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
            guard let self = self else { return }
            tick += 1
            let progress = min(1.0, Double(tick) / Double(steps))
            old?.volume = oldStart + Float(progress) * Float(oldDelta)
            new?.volume = newStart + Float(progress) * Float(newDelta)
            if progress >= 1.0 {
                t.invalidate()
                self.fadeTimer = nil
                old?.stop()
                old?.currentTime = 0
            }
        }
    }
}
