// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../../core/core.zig");
const Assets = @import("../../assets/Assets.zig");
const StreamDecoder = @import("../streaming/StreamDecoder.zig");
const Audio = @import("../Audio.zig");

const Pull = union(enum) { frame: [2]f32, underrun, ended };
const StreamResult = union(enum) { sample: struct { l: f32, r: f32 }, underrun, finished };
pub const Status = packed struct { started: bool = false, looped: bool = false };
pub const VoiceId = packed struct { index: u16, generation: u16 };

pub const VoiceParams = struct {
    position: ?core.math.Vec3 = null,
    right: core.math.Vec3 = .new(1, 0, 0),
    volume: f32 = 1.0,
    pitch: f32 = 1.0,
    loops: bool = false,
    min_distance: f32 = 1,
    max_distance: f32 = 100,
    attenuation: Audio.types.Attenuation = .inverse_square,
};

const Voice = @This();
active: bool = false,
started: bool = false,
finished: bool = false,
id: VoiceId = .{ .index = 0, .generation = 0 },
cursor: f64 = 0,
stream: ?Assets.AssetHandle = null,
params: VoiceParams = .{},
gain: f32 = 1,
pan: f32 = 0, // Ranges from -1 to 1
decoder: ?*StreamDecoder = null,
// For streamed audios
f0: [2]f32 = .{ 0, 0 },
f1: [2]f32 = .{ 0, 0 },
base: u64 = 0,
loaded: u8 = 0,

pub fn mixInto(self: *Voice, out: []f32, frames: usize, listener: Audio.types.AudioListener) Status {
    var status: Status = .{};
    const stream = (self.stream orelse return status).cpuGet(.audio) catch return status;

    const params = &self.params;
    const spatial = params.position != null;

    var target_gain = std.math.clamp(params.volume, 0.0, 10.0);
    var target_pan: f32 = 0;
    if (params.position) |p| {
        const to = p.sub(listener.position);
        const dist = to.length();
        if (dist > params.max_distance) {
            target_gain = 0;
        } else {
            target_gain *= attenuate(params.attenuation, dist, params.min_distance, params.max_distance);
        }
        if (dist > 0.0001) target_pan = std.math.clamp(to.dot(listener.right) / dist, -1, 1);
    }

    if (!self.started) {
        self.started = true;
        status.started = true;
    }

    const frame_count = stream.frameCount();
    if (frame_count == 0) { self.finished = true; return status; }
    const inv: f32 = 1.0 / @as(f32, @floatFromInt(frames));
    const gain_step = (target_gain - self.gain) * inv;
    const pan_step = (target_pan - self.pan) * inv;
    const step: f64 = @as(f64, @max(params.pitch, 0.001)) * @as(f64, @floatFromInt(stream.sample_rate)) / @as(f64, Audio.sample_rate);
    const total: f64 = @floatFromInt(frame_count);
    if (total == 0) { self.finished = true; return status; }
    const ch = stream.channels;

    frames: for (0..frames) |i| {
        var l: f32 = undefined;
        var r: f32 = undefined;

        switch (stream.source) {
            .decoded => |samples| {
                if (self.cursor >= total) {
                    if (params.loops) {
                        self.cursor = @mod(self.cursor, total);
                        status.looped = true;
                    } else {
                        self.finished = true;
                        break :frames;
                    }
                }

                const i_0: usize = @intFromFloat(self.cursor);
                const i_1: usize = if (i_0 + 1 < frame_count) i_0 + 1 else if (params.loops) 0 else i_0;
                const t: f32 = @floatCast(self.cursor - @floor(self.cursor));

                l = std.math.lerp(samples[i_0 * ch], samples[i_1 * ch], t);
                r = std.math.lerp(samples[i_0 * ch + ch - 1], samples[i_1 * ch + ch - 1], t);
            },
            .streamed => switch (self.streamFrame(ch, @intFromFloat(total), params.loops, &status)) {
                .sample => |s| {
                    l = s.l;
                    r = s.r;
                },
                // Just output silence and don't advance. The decoder will eventually catch up to us.
                .underrun => continue :frames,
                .finished => {
                    self.finished = true;
                    break :frames;
                },
            },
        }

        var o_l: f32 = undefined;
        var o_r: f32 = undefined;
        if (spatial) {
            const m = (l+r) / 2;
            const a = (self.pan+1) * (std.math.pi / 4.0);
            o_l = m * @cos(a) * self.gain;
            o_r = m * @sin(a) * self.gain;
        } else {
            o_l = l * self.gain;
            o_r = r * self.gain;
        }

        out[i*2] += o_l;
        out[i*2+1] += o_r;

        self.gain += gain_step;
        self.pan += pan_step;
        self.cursor += step;
    }

    self.gain = target_gain;
    self.pan = target_pan;
    return status;
}

pub fn deinit(self: *Voice) void {
    if (self.stream) |s| s.cpuRelease();
    self.stream = null;
    self.decoder = null; // DecoderThread frees itself, not us
}

fn attenuate(kind: Audio.types.Attenuation, dist: f32, min_d: f32, max_d: f32) f32 {
    const d = std.math.clamp(dist, min_d, max_d);
    return switch (kind) {
        .linear => if (max_d > min_d) 1.0 - (d - min_d) / (max_d - min_d) else 1.0,
        // First number in pow() is the volume at max distance
        .exponential => if (max_d > min_d) std.math.pow(f32, 0.01, (d - min_d) / (max_d - min_d)) else 1.0,
        .inverse_square => if (d > 0) (min_d / d) * (min_d / d) else 1.0,
    };
}

fn pull(d: *StreamDecoder, ch: usize) Pull {
    const ended = d.end_of_stream.load(.acquire);

    if (d.ring.available() >= ch) {
        var buf: [8]f32 = undefined;
        _ = d.ring.read(buf[0..ch]);

        return .{ .frame = .{ buf[0], buf[ch - 1] } };
    }

    return if (ended) .ended else .underrun;
}

fn streamFrame(self: *Voice, ch: usize, total: u64, loops: bool, status: *Status) StreamResult {
    const d = self.decoder orelse return .finished;

    while (self.loaded < 2) {
        switch (pull(d, ch)) {
            .frame => |f| {
                self.f0 = self.f1;
                self.f1 = f;
                self.loaded += 1;
            },
            .underrun => return .underrun,
            .ended => return .finished,
        }
    }

    while (self.cursor >= @as(f64, @floatFromInt(self.base + 1))) {
        switch (pull(d, ch)) {
            .frame => |f| {
                self.f0 = self.f1;
                self.f1 = f;
                self.base += 1;
                
                if (loops and self.base % total == 0) status.looped = true;
            },
            .underrun => return .underrun,
            .ended => return .finished,
        }
    }

    const t: f32 = @floatCast(self.cursor - @as(f64, @floatFromInt(self.base)));
    return .{ .sample = .{
        .l = std.math.lerp(self.f0[0], self.f1[0], t),
        .r = std.math.lerp(self.f0[1], self.f1[1], t),
    } };
}