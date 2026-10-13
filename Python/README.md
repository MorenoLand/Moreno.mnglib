# Python MNG support

This directory contains a standard-library MNG parser, PNG frame extractor, elapsed-time frame selector, and fixture tests. It requires Python 3.7 or later.

## Usage

```python
from mng import first_png_frame, parse

animation = parse(data)
frame = animation.frame_index_at(250)
png = first_png_frame(data)
```

## API

- `is_mng(data)` checks the MNG signature.
- `parse(data)` returns an `MNGAnimation` with MHDR metadata and `frames`, each with embedded `png` bytes and `delay_milliseconds`.
- `first_png_frame(data)` returns the first embedded PNG frame.
- `MNGAnimation.frame_index_at(elapsed)` selects a looping frame for elapsed milliseconds (`int`) or a `timedelta`.
- `MNGError` (a `ValueError`) is raised for a bad signature, a truncated or out-of-bounds chunk, an MHDR shorter than 28 bytes, a PNG run without IEND, no frames, or trailing bytes.

Delays are whole milliseconds, `(ticks * 1000 + tps // 2) // tps`, capped at 4294967295. A frame with no FRAM delay uses 100 ms. A `change_interframe_delay` of 1 applies to the next frame only, 2 also becomes the default for later frames, and 0 changes nothing.

Run the fixture tests from this directory with `python -m unittest`. They read the shared fixtures in `../tests/fixtures`.
