# Browser MNG playback

`mng.js` is a dependency-free browser parser and canvas player for MNG animation files.

MNG (Multiple-image Network Graphics) is an animation format from the early 2000s that never gained widespread browser support and was largely abandoned. This library parses and plays MNG files directly in the browser with no dependencies, using Canvas for rendering.

## Usage

```js
const canvas = await MNG.play(file); // File | ArrayBuffer
document.body.appendChild(canvas);

canvas.play();
canvas.pause();
canvas.stop();

const frames = await MNG.parse(file); // [{ png, delay }]
const blob = await MNG.toBlob(file);  // first frame as image/png
```

## API

### MNG

| Method | Description |
|---|---|
| `MNG.play(src, autoplay?)` | Returns a `Promise` of an animated `<canvas>`. Autoplays by default. |
| `MNG.parse(src)` | Returns a `Promise` of `{ png: Uint8Array, delay: number }[]`, with `delay` in milliseconds. |
| `MNG.toBlob(src)` | Returns a `Promise` of the first frame as a PNG `Blob`. |

`src` accepts a `File` or `ArrayBuffer`.

All three methods reject with an `Error` for a malformed file: bad signature, truncated or out-of-bounds chunk, MHDR shorter than 28 bytes, a PNG run without IEND, no frames, or trailing bytes. `play` also rejects if a frame fails to decode.

### Canvas (returned by `MNG.play`)

| Method | Description |
|---|---|
| `canvas.play()` | Start animation |
| `canvas.pause()` | Pause at current frame |
| `canvas.stop()` | Stop and reset to first frame |

The animation loop stops at a frame change if the canvas is not in the document. Attach the canvas right after `MNG.play` resolves, and call `canvas.play()` again after re-attaching it.

## Features

- Parses MNG chunk structure (MHDR, FRAM, IHDR→IEND)
- Per-frame delay from FRAM chunks (delay mode 1 applies to the next frame, mode 2 also becomes the default), in whole milliseconds rounded half up and capped at 4294967295; a frame with no delay uses 100 ms
- Falls back to 100 ticks/sec if MHDR omits tick rate (MNG spec default)
- Descriptive error on invalid signature showing actual file bytes
- Zero dependencies

## Links

- **Userscript** (auto MNG support on any site): [MNG Support on GreasyFork](https://greasyfork.org/en/scripts/571788-mng-support)
- **Library**: [mng.js](mng.js)

## Test Page

Open `mng-test.html` in a browser alongside `mng.js`. Drag and drop MNG files to preview them with frame count, dimensions, and playback controls.
