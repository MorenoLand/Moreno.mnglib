# C# MNG support

This directory contains a .NET Standard 2.0 MNG parser, PNG frame extractor, and elapsed-time frame selector.

## Usage

```csharp
using Mng;

MngAnimation animation = MngParser.Parse(data);
int frame = animation.FrameIndexAt(elapsed);
byte[] png = MngParser.FirstPngFrame(data);
```

## API

- `MngParser.IsMng(data)` checks the MNG signature.
- `MngParser.Parse(data)` returns MNG metadata, PNG frames, and delays in milliseconds (at most 4294967295). It throws `FormatException` on malformed input.
- `MngParser.FirstPngFrame(data)` returns a copy of the first embedded PNG frame.
- `MngAnimation.FrameIndexAt(elapsed)` selects a looping frame.

Build `Mng.csproj` with the .NET SDK; it has no third-party dependencies. Verified with .NET SDK 8.0.425: `dotnet build Mng.csproj`.
