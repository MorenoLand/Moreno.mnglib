import Foundation

public enum MNGError: Error {
    case notMNG
    case truncatedChunk
    case invalidChunkLength
    case invalidHeader
    case noFrames
}

public struct MNGFrame {
    public let png: Data
    public let delayMilliseconds: UInt64

    public init(png: Data, delayMilliseconds: UInt64) {
        self.png = png
        self.delayMilliseconds = delayMilliseconds
    }
}

public struct MNGAnimation {
    public let width: UInt32
    public let height: UInt32
    public let ticksPerSecond: UInt32
    public let nominalLayerCount: UInt32
    public let nominalFrameCount: UInt32
    public let nominalPlayTime: UInt32
    public let simplicityProfile: UInt32
    public let frames: [MNGFrame]

    public func frameIndex(at elapsedMilliseconds: UInt64) -> Int? {
        if frames.isEmpty { return nil }
        if frames.count == 1 { return 0 }
        let duration = frames.reduce(UInt64(0)) { $0 > UInt64.max - $1.delayMilliseconds ? UInt64.max : $0 + $1.delayMilliseconds }
        if duration == 0 { return 0 }
        var elapsed = elapsedMilliseconds % duration
        for (index, frame) in frames.enumerated() {
            if elapsed < frame.delayMilliseconds { return index }
            elapsed -= frame.delayMilliseconds
        }
        return frames.count - 1
    }
}

public enum MNG {
    private static let mngSignature: [UInt8] = [0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

    public static func isMNG(_ data: Data) -> Bool {
        data.count >= mngSignature.count && Array(data.prefix(mngSignature.count)) == mngSignature
    }

    public static func parse(_ data: Data) throws -> MNGAnimation {
        guard isMNG(data) else { throw MNGError.notMNG }
        var width: UInt32 = 0
        var height: UInt32 = 0
        var ticksPerSecond: UInt32 = 100
        var nominalLayerCount: UInt32 = 0
        var nominalFrameCount: UInt32 = 0
        var nominalPlayTime: UInt32 = 0
        var simplicityProfile: UInt32 = 0
        var frames: [MNGFrame] = []
        var frame = Data()
        var defaultTicks: UInt32?
        var nextTicks: UInt32?
        var inPNG = false
        var offset = mngSignature.count
        while offset < data.count {
            guard data.count - offset >= 12 else { throw MNGError.truncatedChunk }
            let declaredLength = readU32(data, offset)
            guard UInt64(declaredLength) + 12 <= UInt64(data.count - offset) else { throw MNGError.invalidChunkLength }
            let dataLength = Int(declaredLength)
            let chunkLength = dataLength + 12
            let chunkStart = data.startIndex + offset
            let chunkType = Data(data[(chunkStart + 4)..<(chunkStart + 8)])
            if chunkType == Data("MHDR".utf8) {
                guard dataLength >= 28 else { throw MNGError.invalidHeader }
                width = readU32(data, offset + 8)
                height = readU32(data, offset + 12)
                let ticks = readU32(data, offset + 16)
                if ticks > 0 { ticksPerSecond = ticks }
                nominalLayerCount = readU32(data, offset + 20)
                nominalFrameCount = readU32(data, offset + 24)
                nominalPlayTime = readU32(data, offset + 28)
                simplicityProfile = readU32(data, offset + 32)
            } else if chunkType == Data("FRAM".utf8), let (change, ticks) = parseFrameDelay(data[(chunkStart + 8)..<(chunkStart + 8 + dataLength)]) {
                if change == 1 {
                    nextTicks = ticks
                } else if change == 2 {
                    defaultTicks = ticks
                    nextTicks = nil
                }
            }
            if !inPNG && chunkType == Data("IHDR".utf8) {
                frame = Data(pngSignature)
                inPNG = true
            }
            if inPNG {
                frame.append(data[chunkStart..<(chunkStart + chunkLength)])
                if chunkType == Data("IEND".utf8) {
                    let delay = (nextTicks ?? defaultTicks).map { min(UInt64(UInt32.max), (UInt64($0) * 1000 + UInt64(ticksPerSecond) / 2) / UInt64(ticksPerSecond)) } ?? 100
                    frames.append(MNGFrame(png: frame, delayMilliseconds: delay))
                    frame.removeAll(keepingCapacity: true)
                    nextTicks = nil
                    inPNG = false
                }
            }
            offset += chunkLength
        }
        if inPNG || frames.isEmpty { throw MNGError.noFrames }
        return MNGAnimation(width: width, height: height, ticksPerSecond: ticksPerSecond, nominalLayerCount: nominalLayerCount, nominalFrameCount: nominalFrameCount, nominalPlayTime: nominalPlayTime, simplicityProfile: simplicityProfile, frames: frames)
    }

    public static func firstPNGFrame(_ data: Data) throws -> Data {
        try parse(data).frames[0].png
    }

    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[data.startIndex + offset]) << 24 | UInt32(data[data.startIndex + offset + 1]) << 16 | UInt32(data[data.startIndex + offset + 2]) << 8 | UInt32(data[data.startIndex + offset + 3])
    }

    private static func parseFrameDelay(_ data: Data) -> (UInt8, UInt32)? {
        if data.isEmpty { return nil }
        var offset = 1
        while offset < data.count && data[data.startIndex + offset] != 0 { offset += 1 }
        if offset == data.count { return nil }
        offset += 1
        if offset >= data.count { return nil }
        let change = data[data.startIndex + offset]
        offset += 1
        if data.count - offset < 3 { return nil }
        offset += 3
        if change == 0 || data.count - offset < 4 { return nil }
        return (change, readU32(data, offset))
    }
}
