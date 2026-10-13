# C MNG support

This directory contains a dependency-free C11 MNG parser, PNG frame extractor, and elapsed-time frame selector. `mng.h` has `extern "C"` guards, so it can be included from C++.

## Usage

```c
#include "mng.h"

mng_animation animation = {0};
if (mng_parse(data, data_size, &animation)) {
    size_t frame = mng_frame_index_at(&animation, elapsed_milliseconds);
    mng_animation_free(&animation);
}
```

## API

- `mng_is_mng(data, length)` checks the MNG signature.
- `mng_parse(data, length, animation)` fills metadata and extracted PNG frames and returns `1`. It returns `0` on any failure and then leaves `*animation` zeroed.
- `mng_first_png_frame(data, length, png, png_size)` allocates the first PNG frame; free it with `free`.
- `mng_frame_index_at(animation, elapsed_milliseconds)` selects a looping frame. It returns `SIZE_MAX` when `animation` is `NULL` or holds no frames.
- `mng_animation_free(animation)` releases parsed frames and zeroes the struct.

`mng_parse` overwrites `*animation` without freeing it: the struct must be zero-initialized or released with `mng_animation_free` before it is passed again, otherwise its frames leak.

## Behavior

- `mng_parse` fails on a bad signature, a chunk that runs past the end of the data, an `MHDR` shorter than 28 bytes, a PNG run without `IEND`, no PNG frames, or trailing bytes shorter than a 12-byte chunk header. CRCs are not checked.
- Each `IHDR` through `IEND` run becomes one frame: the PNG signature followed by the run's chunks verbatim.
- Delays are in milliseconds at the `MHDR` ticks per second (100 initially; an `MHDR` field of 0 keeps the previous value). A frame with no `FRAM` delay is 100 ms.
- `FRAM` `change_interframe_delay` 1 applies to the next frame only, 2 also becomes the default for later frames, and any other value changes nothing. A `FRAM` without a delay field changes nothing.
- Delays are `(ticks * 1000 + tps / 2) / tps` in unsigned 64-bit arithmetic, saturated at 4294967295.
- Frame selection uses `elapsed % total` over the summed delays (saturating); a single frame or a total of 0 selects frame 0.

## Build

Build with a C11 compiler and link only the standard C library, for example `cc -std=c11 -c mng.c`. Checked with gcc 13.3.0 and clang 18.1.3 using `-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Wshadow`, and with gcc under AddressSanitizer and UndefinedBehaviorSanitizer.
