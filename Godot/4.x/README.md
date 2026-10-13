# Godot 4.x MNG support

`mng.gd` targets Godot 4.x (tested on 4.0, 4.3, and 4.5) and provides an MNG parser with PNG frame decoding and looping frame timing.

## Usage

```gdscript
var data := FileAccess.get_file_as_bytes("res://animation.mng")
var animation = MNG.parse(data)
if animation == null:
    return

var textures := MNG.decode_frames(animation)
var frame_index: int = animation.frame_index_at(Time.get_ticks_msec())
var first_png := MNG.first_png_frame(data)
```

## API

- `MNG.is_mng(data)` checks the MNG signature.
- `MNG.parse(data)` returns an animation with MHDR metadata, PNG frames, and delays, or `null` for a bad signature, a truncated or out-of-bounds chunk, an MHDR shorter than 28 bytes, a PNG run without IEND, no frames, or trailing bytes. It has no static return type, so declare the type of values read from its result (`var frame_index: int = ...`) instead of using `:=`.
- `MNG.first_png_frame(data)` returns the first embedded PNG frame as a `PackedByteArray`.
- `MNG.decode_frames(animation)` converts embedded PNG frames into Godot `Texture2D` objects.
- `MNGAnimation.frame_index_at(elapsed_milliseconds)` selects the looping frame for elapsed milliseconds.

Frame delays (`delay_milliseconds`) are whole milliseconds, `(ticks * 1000 + ticks_per_second / 2) / ticks_per_second` with integer division, capped at 4294967295. A frame with no FRAM delay uses 100 ms. A FRAM `change_interframe_delay` of 1 applies to the next frame only, 2 also becomes the default for later frames, and any other value changes nothing.

The script uses Godot 4.x APIs and has no add-on or third-party dependency.
