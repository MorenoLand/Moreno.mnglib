# Zig MNG support

This directory contains an allocator-aware Zig MNG parser, PNG frame extractor, and elapsed-time frame selector.

## Usage

```zig
var animation = try mng.parse(allocator, data);
defer animation.deinit();

const frame = animation.frameIndexAt(elapsed_milliseconds);
const png = try mng.firstPngFrame(allocator, data);
defer allocator.free(png);
```

## API

- `isMNG(data)` checks the MNG signature.
- `parse(allocator, data)` returns MNG metadata, PNG frames, and delays.
- `firstPngFrame(allocator, data)` allocates the first embedded PNG frame.
- `Animation.frameIndexAt(elapsed_milliseconds)` selects a looping frame.
- `Animation.deinit()` releases all parser allocations.

Frames without a FRAM delay last 100 ms. FRAM delays follow `change_interframe_delay`: 1 applies to the next frame only, 2 also becomes the default for later frames, and any other value changes nothing. Delays are converted with the MHDR ticks per second (100 when the field is 0) and saturate at 4294967295 ms. `frameIndexAt` returns `null` for no frames and 0 when the total delay is 0. Chunk CRCs are not verified.

The source uses the Zig standard library and does not depend on an image package. It builds with Zig 0.13.0, 0.14.1, 0.15.1, and 0.17.0 in Debug, ReleaseSafe, and ReleaseFast, including `-target x86-linux-musl`.
