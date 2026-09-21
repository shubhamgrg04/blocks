import Foundation

/// Original, short UI tones with soft attacks and decaying tails. Generated locally so
/// every installation has the same six choices without downloads or system voice assets.
public enum CompletionSound: String, Codable, CaseIterable {
    case softBell, warmChime, droplet, gentleTap, airyPing, mellowKeys

    public var title: String {
        switch self {
        case .softBell: return "Soft bell"
        case .warmChime: return "Warm chime"
        case .droplet: return "Droplet"
        case .gentleTap: return "Gentle tap"
        case .airyPing: return "Airy ping"
        case .mellowKeys: return "Mellow keys"
        }
    }
    public var detail: String {
        switch self {
        case .softBell: return "One rounded bell with a soft, fading tail."
        case .warmChime: return "Two warm notes, gently rising."
        case .droplet: return "A small, rounded water-drop tone."
        case .gentleTap: return "A quiet wooden tap — the shortest option."
        case .airyPing: return "A light, clear ping that melts away."
        case .mellowKeys: return "A mellow pair of piano-like notes."
        }
    }

    private struct Note {
        var frequency: Double
        var start: Double = 0
        var duration: Double
        var harmonic: Double = 0.12
        var sweep: Double = 0
    }
    private var notes: [Note] {
        switch self {
        case .softBell: return [Note(frequency: 660, duration: 0.9, harmonic: 0.16)]
        case .warmChime: return [Note(frequency: 440, duration: 0.65), Note(frequency: 554.37, start: 0.2, duration: 0.7)]
        case .droplet: return [Note(frequency: 740, duration: 0.42, harmonic: 0.04, sweep: -360)]
        case .gentleTap: return [Note(frequency: 330, duration: 0.24, harmonic: 0.3)]
        case .airyPing: return [Note(frequency: 880, duration: 1.05, harmonic: 0.04)]
        case .mellowKeys: return [Note(frequency: 392, duration: 0.7, harmonic: 0.22), Note(frequency: 523.25, start: 0.16, duration: 0.85, harmonic: 0.18)]
        }
    }

    /// 16-bit mono PCM WAV; equal peak levels, silence at both ends, and no hard cuts.
    public func wavData() -> Data {
        let sampleRate = 44_100
        let tones = notes
        let duration = tones.map { $0.start + $0.duration }.max()! + 0.03
        var samples = [Double](repeating: 0, count: Int(duration * Double(sampleRate)))
        for index in samples.indices {
            let time = Double(index) / Double(sampleRate)
            for note in tones {
                let t = time - note.start
                guard t >= 0, t < note.duration else { continue }
                let attack = min(1, t / 0.018)
                let release = min(1, (note.duration - t) / 0.09)
                let envelope = attack * attack * release * release * exp(-5 * t / note.duration)
                let phase = 2 * Double.pi * (note.frequency * t + 0.5 * note.sweep * t * t)
                samples[index] += envelope * (sin(phase) + note.harmonic * sin(phase * 2))
            }
        }
        let peak = max(0.001, samples.map { abs($0) }.max()!)
        var data = Data()
        func append<T: FixedWidthInteger>(_ number: T) {
            var littleEndian = number.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + samples.count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2))
        append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(UInt32(samples.count * 2))
        for sample in samples { append(Int16((sample / peak * 0.32 * Double(Int16.max)).rounded())) }
        return data
    }
}
