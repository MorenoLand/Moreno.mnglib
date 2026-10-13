# Godot 3.x MNG support

`mng.gd` targets Godot 3.x (tested on 3.5) and provides an MNG parser with PNG frame decoding and looping frame timing.

## Usage

```gdscript
var data = PoolByteArray()
var file = File.new()
if file.open("res://animation.mng", File.READ) == OK:
    data = file.get_buffer(file.get_len())
    file.close()

var animation = MNG.parse(data)
if animation == null:
    return

var textures = MNG.decode_frames(animation)
var frame_index = animation.frame_index_at(OS.get_ticks_msec())
var first_png = MNG.first_png_frame(data)
```

## API

- `MNG.is_mng(data)` checks the MNG signature.
- `MNG.parse(data)` returns an animation with MHDR metadata, PNG frames, and delays, or `null` for a bad signature, a truncated or out-of-bounds chunk, an MHDR shorter than 28 bytes, a PNG run without IEND, no frames, or trailing bytes.
- `MNG.first_png_frame(data)` returns the first embedded PNG frame as a `PoolByteArray`.
- `MNG.decode_frames(animation)` converts embedded PNG frames into Godot 3.x `Texture` objects.
- `MNGAnimation.frame_index_at(elapsed_milliseconds)` selects the looping frame for elapsed milliseconds.

Frame delays (`delay_milliseconds`) are whole milliseconds, `(ticks * 1000 + ticks_per_second / 2) / ticks_per_second` with integer division, capped at 4294967295. A frame with no FRAM delay uses 100 ms. A FRAM `change_interframe_delay` of 1 applies to the next frame only, 2 also becomes the default for later frames, and any other value changes nothing.

The script uses Godot 3.x APIs and has no add-on or third-party dependency.
