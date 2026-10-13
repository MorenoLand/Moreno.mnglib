# C++ MNG support

This directory contains a C++17 MNG parser and first-frame PNG extractor.

## Usage

```cpp
#include "TMng.h"

auto animation = TMng::parse(data.data(), data.size());
if (animation.has_value()) {
    const auto& frame = animation->frames.front();
}
```

`data` is any contiguous byte container such as `std::vector<std::uint8_t>`.

## API

- `TMng::isMNG(content, length)` checks the MNG signature.
- `TMng::parse(content, length)` returns `TMng::Animation` metadata and extracted PNG frames.
- `TMng::firstPngFrame(content, length)` returns the first embedded PNG frame or an empty vector on failure.

`parse` returns `std::nullopt` on a bad signature, a chunk that runs past the end of the data, an `MHDR` shorter than 28 bytes, a PNG run without `IEND`, no PNG frames, or trailing bytes shorter than a 12-byte chunk header. CRCs are not checked.

## Delays

`Frame::delayMilliseconds` is 100 when no `FRAM` delay applies. `FRAM` `change_interframe_delay` 1 applies to the next frame only, 2 also becomes the default for later frames, and any other value changes nothing. A `FRAM` without a delay field changes nothing. `ticksPerSecond` is 100 until an `MHDR` sets a non-zero value. Delays are `(ticks * 1000 + tps / 2) / tps` in unsigned 64-bit arithmetic, saturated at 4294967295.

## Build

`TMng.cpp` and `TMng.h` require C++17 for `std::optional` and have no third-party dependencies, for example `c++ -std=c++17 -c TMng.cpp`. Checked with g++ 13.3.0 and clang++ 18.1.3 using `-std=c++17 -Wall -Wextra -Wpedantic -Wconversion -Wshadow`, and with g++ under AddressSanitizer and UndefinedBehaviorSanitizer.
