# x86-64 assembly MNG scanning

This directory contains x86-64 assembly that checks the MNG signature and counts the embedded PNG frames. It is a scanner, not a parser: it does not read `MHDR` fields (it only requires `MHDR` to hold at least 28 data bytes), `FRAM`, or delays, does not return frame offsets or sizes, and does not display images. Use the [C port](../../C/README.md) to extract frames and delays.

The functions use the Windows x64 calling convention:

- `mng_is_mng(const uint8_t *data, size_t length)` returns `1` when `data` is not NULL, `length` is at least 8, and the data starts with the MNG signature; otherwise `0`.
- `mng_frame_count(const uint8_t *data, size_t length)` returns the number of complete `IHDR` through `IEND` runs, or `0` when `data` is NULL, the signature is bad, a chunk runs past the end of the data, an `MHDR` chunk has fewer than 28 data bytes, trailing bytes are shorter than a 12-byte chunk header, a run has no `IEND`, or there are no runs. CRCs are not checked.

`mng_frame_count` applies the same chunk walk and failure rules as the C `mng_parse` and returns its `frame_count`, or `0` where `mng_parse` fails.

Both functions are leaf functions that use only volatile registers and no stack, so they need no unwind information.

## Build

```
nasm -f win64 mng.asm -o mng.obj
ml64 /c mng_masm.asm
```

`mng.asm` (NASM) and `mng_masm.asm` (MASM) contain the same code. Checked with NASM 2.16.01; `mng_masm.asm` was not assembled with `ml64.exe`. The scanners have no runtime or library dependency.
