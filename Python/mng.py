from dataclasses import dataclass, field
from datetime import timedelta
from typing import List, Optional, Tuple, Union

MNG_SIGNATURE = bytes((0x8A, 0x4D, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A))
PNG_SIGNATURE = bytes((0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A))

class MNGError(ValueError):
    pass

@dataclass(frozen=True)
class MNGFrame:
    png: bytes
    delay_milliseconds: int = 100

@dataclass
class MNGAnimation:
    width: int = 0
    height: int = 0
    ticks_per_second: int = 100
    nominal_layer_count: int = 0
    nominal_frame_count: int = 0
    nominal_play_time: int = 0
    simplicity_profile: int = 0
    frames: List[MNGFrame] = field(default_factory=list)

    def frame_index_at(self, elapsed: Union[timedelta, int]) -> int:
        if not self.frames:
            return -1
        if len(self.frames) == 1:
            return 0
        milliseconds = elapsed // timedelta(milliseconds=1) if isinstance(elapsed, timedelta) else int(elapsed)
        duration = sum(frame.delay_milliseconds for frame in self.frames)
        if duration <= 0:
            return 0
        elapsed = milliseconds % duration
        for index, frame in enumerate(self.frames):
            if elapsed < frame.delay_milliseconds:
                return index
            elapsed -= frame.delay_milliseconds
        return len(self.frames) - 1

def is_mng(data: bytes) -> bool:
    return data[:len(MNG_SIGNATURE)] == MNG_SIGNATURE

def _read_u32(data: bytes, offset: int) -> int:
    return int.from_bytes(data[offset:offset + 4], "big")

def _parse_frame_delay(data: bytes) -> Optional[Tuple[int, int]]:
    if not data:
        return None
    offset = 1
    while offset < len(data) and data[offset] != 0:
        offset += 1
    if offset == len(data):
        return None
    offset += 1
    if offset >= len(data):
        return None
    mode = data[offset]
    offset += 1
    if len(data) - offset < 3:
        return None
    offset += 3
    if mode == 0 or len(data) - offset < 4:
        return None
    return mode, _read_u32(data, offset)

def parse(data: bytes) -> MNGAnimation:
    if not is_mng(data):
        raise MNGError("not an MNG image")
    animation = MNGAnimation()
    frame = bytearray()
    default_ticks: Optional[int] = None
    next_ticks: Optional[int] = None
    in_png = False
    offset = len(MNG_SIGNATURE)
    while offset < len(data):
        if len(data) - offset < 12:
            raise MNGError("truncated MNG chunk")
        data_length = _read_u32(data, offset)
        chunk_length = data_length + 12
        if chunk_length < 12 or chunk_length > len(data) - offset:
            raise MNGError("invalid MNG chunk length")
        chunk_type = data[offset + 4:offset + 8]
        chunk_data = data[offset + 8:offset + 8 + data_length]
        if chunk_type == b"MHDR":
            if data_length < 28:
                raise MNGError("invalid MNG header")
            animation.width = _read_u32(chunk_data, 0)
            animation.height = _read_u32(chunk_data, 4)
            ticks = _read_u32(chunk_data, 8)
            if ticks > 0:
                animation.ticks_per_second = ticks
            animation.nominal_layer_count = _read_u32(chunk_data, 12)
            animation.nominal_frame_count = _read_u32(chunk_data, 16)
            animation.nominal_play_time = _read_u32(chunk_data, 20)
            animation.simplicity_profile = _read_u32(chunk_data, 24)
        elif chunk_type == b"FRAM":
            frame_delay = _parse_frame_delay(chunk_data)
            if frame_delay is not None:
                mode, frame_ticks = frame_delay
                if mode == 1:
                    next_ticks = frame_ticks
                elif mode == 2:
                    default_ticks = frame_ticks
                    next_ticks = None
        if not in_png and chunk_type == b"IHDR":
            frame = bytearray(PNG_SIGNATURE)
            in_png = True
        if in_png:
            frame.extend(data[offset:offset + chunk_length])
            if chunk_type == b"IEND":
                frame_ticks = default_ticks if next_ticks is None else next_ticks
                delay = 100 if frame_ticks is None else min(0xFFFFFFFF, (frame_ticks * 1000 + animation.ticks_per_second // 2) // animation.ticks_per_second)
                animation.frames.append(MNGFrame(bytes(frame), delay))
                frame.clear()
                next_ticks = None
                in_png = False
        offset += chunk_length
    if in_png or not animation.frames:
        raise MNGError("MNG contains no complete frames")
    return animation

def first_png_frame(data: bytes) -> bytes:
    return parse(data).frames[0].png
