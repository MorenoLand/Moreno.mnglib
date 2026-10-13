# Java MNG support

This directory contains a Java 8+ MNG parser, PNG frame extractor, and elapsed-time frame selector.

## Usage

```java
Mng.Animation animation = Mng.parse(data);
int frame = animation.frameIndexAt(Duration.ofMillis(elapsedMilliseconds));
byte[] png = Mng.firstPngFrame(data);
```

## API

- `Mng.isMng(data)` checks the MNG signature.
- `Mng.parse(data)` returns MNG metadata, PNG frames, and delays in milliseconds (at most 4294967295). It throws `Mng.ParseException` on malformed input.
- `Mng.firstPngFrame(data)` returns a copy of the first embedded PNG frame.
- `Mng.Animation.frameIndexAt(elapsed)` selects a looping frame.

The source uses only the Java standard library. Verified with OpenJDK 21: `javac --release 8 -d out Mng.java`.
