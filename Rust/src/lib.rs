use std::fmt;
use std::time::Duration;

const MNG_SIGNATURE: [u8; 8] = [0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const PNG_SIGNATURE: [u8; 8] = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Error {
    NotMng,
    TruncatedChunk,
    InvalidChunkLength,
    InvalidHeader,
    NoFrames,
}

impl fmt::Display for Error {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::NotMng => "not an MNG image",
            Self::TruncatedChunk => "truncated MNG chunk",
            Self::InvalidChunkLength => "invalid MNG chunk length",
            Self::InvalidHeader => "invalid MNG header",
            Self::NoFrames => "MNG contains no complete frames",
        })
    }
}

impl std::error::Error for Error {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Frame {
    pub png: Vec<u8>,
    pub delay: Duration,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Animation {
    pub width: u32,
    pub height: u32,
    pub ticks_per_second: u32,
    pub nominal_layer_count: u32,
    pub nominal_frame_count: u32,
    pub nominal_play_time: u32,
    pub simplicity_profile: u32,
    pub frames: Vec<Frame>,
}

impl Animation {
    pub fn frame_index_at(&self, elapsed: Duration) -> Option<usize> {
        if self.frames.is_empty() { return None; }
        if self.frames.len() == 1 { return Some(0); }
        let duration = self.frames.iter().fold(Duration::ZERO, |total, frame| total.saturating_add(frame.delay));
        if duration.is_zero() { return Some(0); }
        let mut elapsed = elapsed.as_nanos() % duration.as_nanos();
        for (index, frame) in self.frames.iter().enumerate() {
            let delay = frame.delay.as_nanos();
            if elapsed < delay { return Some(index); }
            elapsed -= delay;
        }
        Some(self.frames.len() - 1)
    }
}

pub fn is_mng(data: &[u8]) -> bool {
    data.len() >= MNG_SIGNATURE.len() && data[..MNG_SIGNATURE.len()] == MNG_SIGNATURE
}

fn read_u32(data: &[u8], offset: usize) -> u32 {
    u32::from_be_bytes(data[offset..offset + 4].try_into().unwrap())
}

fn parse_frame_delay(data: &[u8]) -> Option<(u8, u32)> {
    if data.is_empty() { return None; }
    let mut offset = 1;
    while offset < data.len() && data[offset] != 0 { offset += 1; }
    if offset == data.len() { return None; }
    offset += 1;
    if offset >= data.len() { return None; }
    let change = data[offset];
    offset += 1;
    if data.len() - offset < 3 { return None; }
    offset += 3;
    if change == 0 || data.len() - offset < 4 { return None; }
    Some((change, read_u32(data, offset)))
}

pub fn parse_mng(data: &[u8]) -> Result<Animation, Error> {
    if !is_mng(data) { return Err(Error::NotMng); }
    let mut animation = Animation { width: 0, height: 0, ticks_per_second: 100, nominal_layer_count: 0, nominal_frame_count: 0, nominal_play_time: 0, simplicity_profile: 0, frames: Vec::new() };
    let mut frame = Vec::new();
    let mut default_ticks = None;
    let mut next_ticks = None;
    let mut in_png = false;
    let mut offset = MNG_SIGNATURE.len();
    while offset < data.len() {
        if data.len() - offset < 12 { return Err(Error::TruncatedChunk); }
        let data_length = read_u32(data, offset) as usize;
        if data_length > data.len() - offset - 12 { return Err(Error::InvalidChunkLength); }
        let chunk_length = data_length + 12;
        let chunk_type = &data[offset + 4..offset + 8];
        let chunk_data = &data[offset + 8..offset + 8 + data_length];
        if chunk_type == b"MHDR" {
            if data_length < 28 { return Err(Error::InvalidHeader); }
            animation.width = read_u32(chunk_data, 0);
            animation.height = read_u32(chunk_data, 4);
            let ticks = read_u32(chunk_data, 8);
            if ticks > 0 { animation.ticks_per_second = ticks; }
            animation.nominal_layer_count = read_u32(chunk_data, 12);
            animation.nominal_frame_count = read_u32(chunk_data, 16);
            animation.nominal_play_time = read_u32(chunk_data, 20);
            animation.simplicity_profile = read_u32(chunk_data, 24);
        } else if chunk_type == b"FRAM" {
            match parse_frame_delay(chunk_data) {
                Some((1, ticks)) => next_ticks = Some(ticks),
                Some((2, ticks)) => {
                    default_ticks = Some(ticks);
                    next_ticks = None;
                }
                _ => {}
            }
        }
        if !in_png && chunk_type == b"IHDR" {
            frame.extend_from_slice(&PNG_SIGNATURE);
            in_png = true;
        }
        if in_png {
            frame.extend_from_slice(&data[offset..offset + chunk_length]);
            if chunk_type == b"IEND" {
                let delay = next_ticks.or(default_ticks).map(|ticks| Duration::from_millis(((ticks as u64 * 1000 + animation.ticks_per_second as u64 / 2) / animation.ticks_per_second as u64).min(u32::MAX as u64))).unwrap_or_else(|| Duration::from_millis(100));
                animation.frames.push(Frame { png: std::mem::take(&mut frame), delay });
                next_ticks = None;
                in_png = false;
            }
        }
        offset += chunk_length;
    }
    if in_png || animation.frames.is_empty() { return Err(Error::NoFrames); }
    Ok(animation)
}

pub fn first_png_frame(data: &[u8]) -> Result<Vec<u8>, Error> {
    Ok(parse_mng(data)?.frames.into_iter().next().ok_or(Error::NoFrames)?.png)
}
