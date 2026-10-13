import unittest
from datetime import timedelta
from pathlib import Path
from typing import Optional

from mng import MNG_SIGNATURE, PNG_SIGNATURE, MNGAnimation, MNGError, MNGFrame, first_png_frame, parse

FIXTURES = Path(__file__).resolve().parents[1] / "tests" / "fixtures"
UINT32_MAX = 4294967295

EXPECTED = {
    "minimal-1x1": [100],
    "timed-2-frame": [250, 500],
    "default-persist": [250, 250, 500, 250, 250],
    "zero-delay": [0, 100],
    "huge-delay": [UINT32_MAX, UINT32_MAX, UINT32_MAX],
    "tps-zero": [250],
    "bad-chunk-length": None,
    "mhdr-short": None,
    "no-iend": None,
    "truncated": None,
    "trailing-garbage": None,
    "no-frames": None,
}

def fixture(name: str) -> bytes:
    return bytes.fromhex("".join((FIXTURES / name).read_text().split()))

def chunk(kind: bytes, payload: bytes = b"") -> bytes:
    return len(payload).to_bytes(4, "big") + kind + payload + bytes(4)

def mhdr(ticks: int) -> bytes:
    return chunk(b"MHDR", (1).to_bytes(4, "big") * 2 + ticks.to_bytes(4, "big") + bytes(16))

def fram(change: int, delay: Optional[int] = None) -> bytes:
    return chunk(b"FRAM", b"\x01\x00" + bytes((change, 0, 0, 0)) + (b"" if delay is None else delay.to_bytes(4, "big")))

def png() -> bytes:
    return chunk(b"IHDR", bytes(13)) + chunk(b"IDAT", b"x") + chunk(b"IEND")

def synth(*chunks: bytes) -> bytes:
    return MNG_SIGNATURE + b"".join(chunks) + chunk(b"MEND")

def delays(*chunks: bytes):
    return [frame.delay_milliseconds for frame in parse(synth(*chunks)).frames]

def timeline(*frame_delays: int) -> MNGAnimation:
    return MNGAnimation(frames=[MNGFrame(b"", delay) for delay in frame_delays])

class MNGTests(unittest.TestCase):
    def test_single_frame(self):
        animation = parse(fixture("minimal-1x1.mng.hex"))
        self.assertEqual((animation.width, animation.height), (1, 1))
        self.assertEqual(len(animation.frames), 1)
        self.assertEqual(animation.frames[0].delay_milliseconds, 100)
        self.assertTrue(first_png_frame(fixture("minimal-1x1.mng.hex")).startswith(b"\x89PNG"))

    def test_timed_frames(self):
        animation = parse(fixture("timed-2-frame.mng.hex"))
        self.assertEqual([frame.delay_milliseconds for frame in animation.frames], [250, 500])
        self.assertEqual(animation.frame_index_at(0), 0)
        self.assertEqual(animation.frame_index_at(250), 1)
        self.assertEqual(animation.frame_index_at(750), 0)

    def test_fixture_table(self):
        names = sorted(path.name[:-len(".mng.hex")] for path in FIXTURES.glob("*.mng.hex"))
        self.assertEqual(names, sorted(EXPECTED))
        for name in names:
            with self.subTest(name):
                data = fixture(name + ".mng.hex")
                if EXPECTED[name] is None:
                    with self.assertRaises(MNGError):
                        parse(data)
                    with self.assertRaises(MNGError):
                        first_png_frame(data)
                    continue
                parsed = parse(data)
                self.assertEqual([frame.delay_milliseconds for frame in parsed.frames], EXPECTED[name])
                for frame in parsed.frames:
                    self.assertTrue(frame.png.startswith(PNG_SIGNATURE))
                    self.assertTrue(frame.png.endswith(bytes.fromhex("0000000049454e44ae426082")))
                self.assertEqual(first_png_frame(data), parsed.frames[0].png)

    def test_frame_index_examples(self):
        timed = parse(fixture("timed-2-frame.mng.hex"))
        for elapsed, index in ((0, 0), (249, 0), (250, 1), (749, 1), (750, 0)):
            self.assertEqual(timed.frame_index_at(elapsed), index)
            self.assertEqual(timed.frame_index_at(timedelta(milliseconds=elapsed)), index)
        huge = parse(fixture("huge-delay.mng.hex"))
        for elapsed, index in ((0, 0), (4294967295, 1), (8589934590, 2), (12884901885, 0)):
            self.assertEqual(huge.frame_index_at(elapsed), index)
            self.assertEqual(huge.frame_index_at(timedelta(milliseconds=elapsed)), index)

    def test_frame_index_edge_cases(self):
        self.assertEqual(timeline().frame_index_at(5), -1)
        self.assertEqual(timeline(100).frame_index_at(5000), 0)
        self.assertEqual(timeline(0, 0).frame_index_at(5), 0)
        self.assertEqual(timeline(0, 100).frame_index_at(0), 1)
        self.assertEqual(timeline(1001, 1000).frame_index_at(timedelta(milliseconds=1001)), 1)
        self.assertEqual(timeline(1001, 1000).frame_index_at(timedelta(milliseconds=1000, microseconds=999)), 0)

    def test_zero_delay_is_kept(self):
        self.assertEqual(delays(mhdr(100), fram(1, 0), png(), png()), [0, 100])

    def test_rounding_is_half_up(self):
        self.assertEqual(delays(mhdr(2000), fram(1, 5), png()), [3])
        self.assertEqual(delays(mhdr(16), fram(1, 1), png()), [63])
        self.assertEqual(delays(mhdr(2000), fram(1, 1001), png()), [501])
        self.assertEqual(delays(mhdr(3), fram(1, 1), png()), [333])

    def test_delay_saturates(self):
        self.assertEqual(delays(mhdr(1), fram(1, UINT32_MAX), png()), [UINT32_MAX])
        self.assertEqual(delays(mhdr(1), fram(2, UINT32_MAX), png(), png()), [UINT32_MAX, UINT32_MAX])

    def test_delay_modes(self):
        self.assertEqual(delays(mhdr(100), fram(2, 25), png(), png()), [250, 250])
        self.assertEqual(delays(mhdr(100), fram(1, 25), png(), png()), [250, 100])
        self.assertEqual(delays(mhdr(100), fram(2, 25), fram(1, 50), png(), png()), [500, 250])
        self.assertEqual(delays(mhdr(100), fram(1, 50), fram(2, 25), png(), png()), [250, 250])
        self.assertEqual(delays(mhdr(100), fram(2, 25), fram(0, 99), png(), png()), [250, 250])
        self.assertEqual(delays(mhdr(100), fram(2, 25), fram(3, 99), fram(255, 99), png(), png()), [250, 250])
        self.assertEqual(delays(mhdr(100), fram(1, 25), fram(3, 99), png(), png()), [250, 100])

    def test_fram_without_delay_changes_nothing(self):
        self.assertEqual(delays(mhdr(100), fram(2, 25), png(), fram(0), png(), fram(1), png()), [250, 250, 250])
        self.assertEqual(delays(mhdr(100), fram(1, 25), fram(1), png(), png()), [250, 100])
        self.assertEqual(delays(mhdr(100), fram(1, 25), chunk(b"FRAM", b"\x01"), png(), png()), [250, 100])
        self.assertEqual(delays(mhdr(100), fram(1, 25), chunk(b"FRAM"), png(), png()), [250, 100])

    def test_ticks_per_second_zero_keeps_previous_rate(self):
        self.assertEqual(delays(mhdr(1000), mhdr(0), fram(1, 500), png()), [500])

    def test_rate_at_frame_end_applies(self):
        self.assertEqual(delays(mhdr(100), fram(1, 100), chunk(b"IHDR", bytes(13)), mhdr(1000), chunk(b"IEND"), png()), [100, 100])

    def test_chunks_inside_png_run_are_kept(self):
        inner = chunk(b"IHDR", bytes(13)) + chunk(b"IHDR", bytes(13)) + chunk(b"IDAT", b"x") + chunk(b"IEND")
        parsed = parse(synth(inner))
        self.assertEqual(parsed.frames[0].png, PNG_SIGNATURE + inner)
        inner = chunk(b"IHDR", bytes(13)) + fram(1, 25) + chunk(b"IDAT", b"x") + chunk(b"IEND")
        parsed = parse(synth(mhdr(100), inner))
        self.assertEqual(parsed.frames[0].png, PNG_SIGNATURE + inner)
        self.assertEqual(parsed.frames[0].delay_milliseconds, 250)

    def test_malformed_inputs_fail(self):
        good = synth(mhdr(100), png())
        parse(good)
        cases = {
            "empty": b"",
            "bad signature": PNG_SIGNATURE + good[8:],
            "short mhdr 12": synth(chunk(b"MHDR", bytes(12)), png()),
            "short mhdr 20": synth(chunk(b"MHDR", bytes(20)), png()),
            "short mhdr 8": synth(chunk(b"MHDR", bytes(8)), png()),
            "no iend": synth(mhdr(100), chunk(b"IHDR", bytes(13))),
            "no frames": synth(mhdr(100)),
            "signature only": MNG_SIGNATURE,
            "trailing 11": good + bytes(11),
            "trailing 1": good + b"\x00",
            "truncated": good[:-1],
            "huge length": MNG_SIGNATURE + b"\x7f\xff\xff\xff" + b"IDAT" + bytes(8),
            "max length": MNG_SIGNATURE + b"\xff\xff\xff\xff" + b"IDAT" + bytes(8),
        }
        for name, data in cases.items():
            with self.subTest(name):
                with self.assertRaises(MNGError):
                    parse(data)

if __name__ == "__main__":
    unittest.main()
