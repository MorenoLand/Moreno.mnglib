# Cross-language MNG implementations

Small, language-specific implementations that keep Multiple-image Network Graphics (MNG) usable across languages, game engines, and browsers.

Each implementation except Assembly parses the MNG signature and chunk stream, reads MHDR metadata, extracts embedded PNG frames, and applies FRAM timing, using 100 ticks per second when MHDR gives none and a 100 ms delay for frames without a FRAM delay.

## Implementations

- [C](C/README.md) — C11 parser, frame extraction, and timing API.
- [C++](C%2B%2B/README.md) — C++17 parser and PNG frame extraction API.
- [C#](CSharp/README.md) — .NET parser, frame extraction, and timing API.
- [Godot](Godot/README.md) — versioned Godot 3.x and 4.x GDScript ports.
- [Golang](Golang/README.md) — standalone Go package for parsing, frame extraction, and timing.
- [Java](Java/README.md) — Java 8+ parser, frame extraction, and timing API.
- [JavaScript](JavaScript/README.md) — dependency-free browser parser and canvas player.
- [Kotlin](Kotlin/README.md) — JVM parser, frame extraction, and timing API.
- [Python](Python/README.md) — standard-library parser, frame extraction, timing, and fixture tests.
- [Rust](Rust/README.md) — dependency-free parser, frame extraction, and timing API.
- [Swift](Swift/README.md) — Swift Package Manager parser, frame extraction, and timing API.
- [Zig](Zig/README.md) — allocator-aware parser, frame extraction, and timing API.
- [Assembly](Assembly/x86-64/README.md) — Windows x64 NASM MNG signature and frame scanner. (DOES NOT DISPLAY IMAGES)

Each folder contains its own API and usage documentation. Shared byte fixtures are in [tests](tests/README.md). Implementations remain separate so each language can follow its native conventions while preserving the same MNG behavior.

## Project documents

- [Contributing](CONTRIBUTING.md)
- [Donating](DONATING.md)
- [Security](SECURITY.md)
- [MNG preservation pledge](MNG-PLEDGE.md)
- [License](LICENSE)
