const std = @import("std");

const mng_signature = [_]u8{ 0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a };
const png_signature = [_]u8{ 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a };

pub const Error = error{ NotMNG, TruncatedChunk, InvalidChunkLength, InvalidHeader, NoFrames };

pub const Frame = struct {
    png: []u8,
    delay_milliseconds: u32,
};

pub const Animation = struct {
    allocator: std.mem.Allocator,
    width: u32 = 0,
    height: u32 = 0,
    ticks_per_second: u32 = 100,
    nominal_layer_count: u32 = 0,
    nominal_frame_count: u32 = 0,
    nominal_play_time: u32 = 0,
    simplicity_profile: u32 = 0,
    frames: []Frame,

    pub fn deinit(self: *Animation) void {
        for (self.frames) |frame| self.allocator.free(frame.png);
        self.allocator.free(self.frames);
    }

    pub fn frameIndexAt(self: Animation, elapsed_milliseconds: u64) ?usize {
        if (self.frames.len == 0) return null;
        if (self.frames.len == 1) return 0;
        var duration: u64 = 0;
        for (self.frames) |frame| duration +|= frame.delay_milliseconds;
        if (duration == 0) return 0;
        var elapsed = elapsed_milliseconds % duration;
        for (self.frames, 0..) |frame, index| {
            if (elapsed < frame.delay_milliseconds) return index;
            elapsed -= frame.delay_milliseconds;
        }
        return self.frames.len - 1;
    }
};

fn readU32(data: []const u8, offset: usize) u32 {
    return (@as(u32, data[offset]) << 24) | (@as(u32, data[offset + 1]) << 16) | (@as(u32, data[offset + 2]) << 8) | data[offset + 3];
}

fn parseFrameDelay(data: []const u8) ?struct { u8, u32 } {
    if (data.len == 0) return null;
    var offset: usize = 1;
    while (offset < data.len and data[offset] != 0) offset += 1;
    if (offset == data.len) return null;
    offset += 1;
    if (offset >= data.len) return null;
    const change = data[offset];
    offset += 1;
    if (data.len - offset < 3) return null;
    offset += 3;
    if (change == 0 or data.len - offset < 4) return null;
    return .{ change, readU32(data, offset) };
}

pub fn isMNG(data: []const u8) bool {
    return data.len >= mng_signature.len and std.mem.eql(u8, data[0..mng_signature.len], mng_signature[0..]);
}

pub fn parse(allocator: std.mem.Allocator, data: []const u8) !Animation {
    if (!isMNG(data)) return error.NotMNG;
    var frames = try std.ArrayListUnmanaged(Frame).initCapacity(allocator, 0);
    errdefer {
        for (frames.items) |frame| allocator.free(frame.png);
        frames.deinit(allocator);
    }
    var animation = Animation{ .allocator = allocator, .frames = undefined };
    var frame = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 0);
    defer frame.deinit(allocator);
    var default_ticks: ?u32 = null;
    var next_ticks: ?u32 = null;
    var in_png = false;
    var offset: usize = mng_signature.len;
    while (offset < data.len) {
        if (data.len - offset < 12) return error.TruncatedChunk;
        const data_length = @as(usize, readU32(data, offset));
        if (data_length > data.len - offset - 12) return error.InvalidChunkLength;
        const chunk_length = data_length + 12;
        const chunk_type = data[offset + 4 .. offset + 8];
        const chunk_data = data[offset + 8 .. offset + 8 + data_length];
        if (std.mem.eql(u8, chunk_type, "MHDR")) {
            if (data_length < 28) return error.InvalidHeader;
            animation.width = readU32(chunk_data, 0);
            animation.height = readU32(chunk_data, 4);
            const ticks = readU32(chunk_data, 8);
            if (ticks > 0) animation.ticks_per_second = ticks;
            animation.nominal_layer_count = readU32(chunk_data, 12);
            animation.nominal_frame_count = readU32(chunk_data, 16);
            animation.nominal_play_time = readU32(chunk_data, 20);
            animation.simplicity_profile = readU32(chunk_data, 24);
        } else if (std.mem.eql(u8, chunk_type, "FRAM")) {
            if (parseFrameDelay(chunk_data)) |change_ticks| {
                switch (change_ticks[0]) {
                    1 => next_ticks = change_ticks[1],
                    2 => {
                        default_ticks = change_ticks[1];
                        next_ticks = null;
                    },
                    else => {},
                }
            }
        }
        if (!in_png and std.mem.eql(u8, chunk_type, "IHDR")) {
            try frame.appendSlice(allocator, png_signature[0..]);
            in_png = true;
        }
        if (in_png) {
            try frame.appendSlice(allocator, data[offset .. offset + chunk_length]);
            if (std.mem.eql(u8, chunk_type, "IEND")) {
                const delay: u32 = if (next_ticks orelse default_ticks) |ticks| @intCast(@min((@as(u64, ticks) * 1000 + animation.ticks_per_second / 2) / animation.ticks_per_second, std.math.maxInt(u32))) else 100;
                const png = try frame.toOwnedSlice(allocator);
                frames.append(allocator, .{ .png = png, .delay_milliseconds = delay }) catch |err| {
                    allocator.free(png);
                    return err;
                };
                next_ticks = null;
                in_png = false;
            }
        }
        offset += chunk_length;
    }
    if (in_png or frames.items.len == 0) return error.NoFrames;
    animation.frames = try frames.toOwnedSlice(allocator);
    return animation;
}

pub fn firstPngFrame(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var animation = try parse(allocator, data);
    defer animation.deinit();
    const result = try allocator.alloc(u8, animation.frames[0].png.len);
    @memcpy(result, animation.frames[0].png);
    return result;
}
