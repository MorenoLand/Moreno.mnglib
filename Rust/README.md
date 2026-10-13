# Rust MNG support

This directory contains a dependency-free Rust MNG parser, PNG frame extractor, and elapsed-time frame selector.

## Usage

```rust
use std::time::Duration;

let animation = mng::parse_mng(&data)?;
let frame = animation.frame_index_at(Duration::from_millis(elapsed_milliseconds));
let png = mng::first_png_frame(&data)?;
```

## API

- `is_mng(data)` checks the MNG signature.
- `parse_mng(data)` returns MNG metadata, PNG frames, and delays.
- `first_png_frame(data)` returns the first embedded PNG frame.
- `Animation::frame_index_at(elapsed)` selects a looping frame; it returns `None` for no frames and `Some(0)` when the total delay is zero.

Frames without a FRAM delay last 100 ms. FRAM delays follow `change_interframe_delay`: 1 applies to the next frame only, 2 also becomes the default for later frames, and any other value changes nothing. Delays are converted with the MHDR ticks per second (100 when the field is 0) and saturate at 4294967295 ms. Chunk CRCs are not verified.

The crate uses only the Rust standard library and targets Rust 2021. Built and checked with Rust 1.97.0 (`cargo build`, `cargo clippy`, `cargo publish --dry-run`), including `i686-unknown-linux-musl`.
