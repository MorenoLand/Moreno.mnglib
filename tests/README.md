# Shared MNG fixtures

The `.mng.hex` files are source-controlled byte fixtures: one chunk per line, newline separated. Strip whitespace, then decode with a language-native hexadecimal decoder before passing the bytes to an implementation.

All MNG and embedded PNG chunk CRC fields are valid and every well-formed fixture ends with MEND, so the files also open in image libraries. The parsers do not verify CRCs.

## Expected behavior

Delays are in milliseconds at the MHDR ticks per second (100 when the field is 0). A frame with no FRAM delay uses 100 ms. `change_interframe_delay` 1 applies to the next frame only, 2 also becomes the default for later frames, and 0 changes nothing. Delays are computed as `(ticks * 1000 + tps / 2) / tps` and saturate at 4294967295.

| Fixture | Result |
| --- | --- |
| `minimal-1x1` | 1 frame, 100 |
| `timed-2-frame` | 2 frames, 250 and 500 |
| `default-persist` | 5 frames, 250, 250, 500, 250, 250 |
| `zero-delay` | 2 frames, 0 and 100 |
| `huge-delay` | 3 frames, each 4294967295 (MHDR 1 tick per second, FRAM delay 0xFFFFFFFF) |
| `tps-zero` | 1 frame, 250 (MHDR ticks per second 0 falls back to 100) |
| `bad-chunk-length` | parse fails (chunk length 0xFFFFFFFF) |
| `mhdr-short` | parse fails (MHDR shorter than 28 bytes) |
| `no-iend` | parse fails (PNG run without IEND) |
| `truncated` | parse fails (chunk runs past the end) |
| `trailing-garbage` | parse fails (6 stray bytes after MEND) |
| `no-frames` | parse fails (no PNG frames) |

Frame selection loops over the summed delays. For `timed-2-frame`, elapsed 0 and 249 select frame 0, 250 and 749 select frame 1, and 750 selects frame 0. For `huge-delay`, elapsed 0, 4294967295, 8589934590 and 12884901885 select frames 0, 1, 2 and 0. When the summed delay is 0 the first frame is selected.
