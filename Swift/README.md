# Swift MNG support

This directory contains a Swift Package Manager MNG parser, PNG frame extractor, and elapsed-time frame selector.

## Usage

```swift
let animation = try MNG.parse(data)
let frame = animation.frameIndex(at: elapsedMilliseconds)
let png = try MNG.firstPNGFrame(data)
```

## API

- `MNG.isMNG(data)` checks the MNG signature.
- `MNG.parse(data)` returns MNG metadata, PNG frames, and delays in milliseconds (at most 4294967295). It throws `MNGError` on malformed input.
- `MNG.firstPNGFrame(data)` returns the first embedded PNG frame.
- `MNGAnimation.frameIndex(at:)` selects a looping frame.

The package uses Foundation and targets Swift 5.7 or newer. Verified with Swift 6.0.3 on Linux: `swift build`.
