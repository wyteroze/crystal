// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const audio_dr = @import("dr_libs");
const SampleRing = @import("SampleRing.zig");
const Assets = @import("../../assets/Assets.zig");

pub const ring_samples = 1 << 17;

const StreamDecoder = @This();
decoder: union(Assets.types.AudioFormat) { mp3: audio_dr.drmp3, wav: audio_dr.drwav },
channels: usize,
loop: std.atomic.Value(bool),
ring: SampleRing,
temp_storage: [2048]f32 = undefined,
empty_reads: u8 = 0,
end_of_stream: std.atomic.Value(bool) = .init(false),

pub fn init(allocator: std.mem.Allocator, audio: Assets.types.AudioStream, loop: bool) !*StreamDecoder {
    if (audio.channels > 8) return error.TooManyChannels;
    
    const src = audio.source.streamed;
    const self = try allocator.create(StreamDecoder);
    errdefer allocator.destroy(self);

    self.* = .{
        .decoder = switch (src.format) {
            .mp3 => .{ .mp3 = undefined },
            .wav => .{ .wav = undefined }
        },
        .channels = audio.channels,
        .loop = .init(loop),
        .ring = try .init(allocator, ring_samples)
    };
    errdefer self.ring.deinit(allocator);

    switch (self.decoder) {
        .mp3 => |*d| if (audio_dr.drmp3_init_memory(d, src.bytes.ptr, src.bytes.len, null) == 0)
            return error.Mp3AudioDecodeFailed,
        .wav => |*d| if (audio_dr.drwav_init_memory(d, src.bytes.ptr, src.bytes.len, null) == 0)
            return error.WavAudioDecodeFailed,
    }

    return self;
}

pub fn deinit(self: *StreamDecoder, allocator: std.mem.Allocator) void {
    switch (self.decoder) {
        .mp3 => |*d| audio_dr.drmp3_uninit(d),
        .wav => |*d| _ = audio_dr.drwav_uninit(d),
    }
    self.ring.deinit(allocator);
    allocator.destroy(self);
}

pub fn needsFill(self: *const StreamDecoder) bool {
    return !self.end_of_stream.load(.acquire) and self.ring.writable() >= ring_samples / 2;
}

pub fn fill(self: *StreamDecoder, max_frames: usize) void {
    var budget = max_frames;
    while (budget > 0 and !self.end_of_stream.load(.monotonic)) {
        const want = @min(self.ring.writable() / self.channels, self.temp_storage.len / self.channels, budget);
        if (want == 0) return;

        const got = self.readFrames(want);
        if (got > 0) self.ring.write(self.temp_storage[0..got * self.channels]);
        budget -= got;
        self.empty_reads = if (got == 0) self.empty_reads +| 1 else 0;

        if (got < want) {
            // file is probably broken
            if (self.loop.load(.acquire) and self.empty_reads < 2) self.rewind()
                else self.end_of_stream.store(true, .release);
        }
    }
}

fn readFrames(self: *StreamDecoder, frames: usize) usize {
    const dst = self.temp_storage[0..].ptr;
    return switch (self.decoder) {
        .mp3 => |*d| @intCast(audio_dr.drmp3_read_pcm_frames_f32(d, frames, dst)),
        .wav => |*d| @intCast(audio_dr.drwav_read_pcm_frames_f32(d, frames, dst)),
    };
}

fn rewind(self: *StreamDecoder) void {
    switch (self.decoder) {
        .mp3 => |*d| _ = audio_dr.drmp3_seek_to_pcm_frame(d, 0),
        .wav => |*d| _ = audio_dr.drwav_seek_to_pcm_frame(d, 0),
    }
}