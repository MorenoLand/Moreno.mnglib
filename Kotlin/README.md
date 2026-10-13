# Kotlin MNG support

This directory contains a Kotlin/JVM MNG parser, PNG frame extractor, and elapsed-time frame selector.

## Usage

```kotlin
val animation = Mng.parse(data)
val frame = animation.frameIndexAt(Duration.ofMillis(elapsedMilliseconds))
val png = Mng.firstPngFrame(data)
```

## API

- `Mng.isMng(data)` checks the MNG signature.
- `Mng.parse(data)` returns MNG metadata, PNG frames, and delays in milliseconds (at most 4294967295). It throws `MngException` on malformed input.
- `Mng.firstPngFrame(data)` returns a copy of the first embedded PNG frame.
- `MngAnimation.frameIndexAt(elapsed)` selects a looping frame.

The source uses the Kotlin/JVM standard library and `java.time.Duration`, so it needs a JVM 8 or newer. Verified with Kotlin 2.0.21 (language versions 1.9 and 2.0) on OpenJDK 21: `kotlinc -jvm-target 1.8 -d out Mng.kt`.
