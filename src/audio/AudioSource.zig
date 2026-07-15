// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const AudioData = @import("AudioData.zig").AudioData;
const Object = @import("../object.zig").Object;
const Handle = @import("../script/reflect/marshal.zig").Handle;

pub const AudioSource = struct {
    pub const name = "AudioSource";
    pub const lua_ref = true;
    pub const hidden = .{
        "data", "stream", "playing", "loops",
        "volume", "time", "attached_to", "read_offset",
        "bytesPerSecond", "update"
    };

    data: *const AudioData,
    stream: sdl3.audio.Stream,
    playing: bool,
    loops: bool,
    volume: f32,
    time: f32,
    attached_to: ?*Object,
    read_offset: usize,

    pub fn init(data: *const AudioData, stream: sdl3.audio.Stream) AudioSource {
        return .{
            .data = data,
            .stream = stream,
            .playing = false,
            .loops = false,
            .volume = 1.0,
            .time = 0.0,
            .attached_to = null,
            .read_offset = 0
        };
    }

    pub fn deinit(self: *AudioSource) void {
        self.stream.unbind();
        self.stream.deinit();
    }

    fn bytesPerSecond(self: AudioSource) usize {
        const bytes_per_sample = self.data.bits_per_sample / 8;
        return bytes_per_sample * self.data.channels * self.data.sample_rate;
    }

    pub fn getLength(self: AudioSource) f32 {
        const bps = self.bytesPerSecond();
        if (bps == 0) return 0;

        return @as(f32, @floatFromInt(self.data.data.len)) / @as(f32, @floatFromInt(bps));
    }

    pub fn getTime(self: AudioSource) f32 {
        const bps = self.bytesPerSecond();
        if (bps == 0) return 0;

        return @as(f32, @floatFromInt(self.read_offset)) / @as(f32, @floatFromInt(bps));
    }

    pub fn setTime(self: *AudioSource, value: f32) void {
        const bps = self.bytesPerSecond();
        const clamped = std.math.clamp(value, 0.0, self.getLength());
        var offset = @as(usize, @intFromFloat(clamped * @as(f32, @floatFromInt(bps))));

        // keep it aligned to a full sample frame. if we don't, we could
        // start reading mid-frame and we'd get noise
        const frame_size = (self.data.bits_per_sample / 8) * self.data.channels;
        if (frame_size > 0) offset -= offset % frame_size;

        self.read_offset = offset;

        self.stream.clear() catch {};
    }

    pub fn getVolume(self: AudioSource) f32 {
        return self.volume;
    }

    pub fn setVolume(self: *AudioSource, value: f32) void {
        const clamped = std.math.clamp(value, 0.0, 10.0);
        self.volume = clamped;
    }

    pub fn getLoops(self: AudioSource) bool {
        return self.loops;
    }

    pub fn setLoops(self: *AudioSource, loops: bool) void {
        self.loops = loops;
    }

    pub fn getPlaying(self: AudioSource) bool {
        return self.playing;
    }

    pub fn setPlaying(self: *AudioSource, playing: bool) void {
        self.playing = playing;
    }

    pub fn attachTo(self: *AudioSource, object: ?*Object) void {
        self.attached_to = object;
    }

    pub fn AttachTo(self: *AudioSource, object: ?Handle(Object)) void {
        self.attachTo(if (object) |o| o.ptr else null);
    }

    pub fn update(self: *AudioSource) !void {
        if (!self.playing) return;

        // keep about 100ms of audio queued up
        const wanted_queued_bytes = self.bytesPerSecond() / 10;

        while (true) {
            const queued = try self.stream.getQueued();
            if (queued >= wanted_queued_bytes) break;

            const remaining = self.data.data.len - self.read_offset;
            if (remaining == 0) {
                if (self.loops) {
                    self.read_offset = 0;
                    break;
                } else {
                    self.playing = false;
                    return;
                }
            }

            const chunk_size = @min(remaining, wanted_queued_bytes - queued);
            const chunk = self.data.data[self.read_offset .. self.read_offset + chunk_size];
            try self.stream.putData(chunk);

            self.read_offset += chunk_size;
        }
    }
};
