// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../../core/core.zig");
const Assets = @import("../../assets/Assets.zig");
const Audio = @import("../Audio.zig");

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

    for (0..frames) |i| {
        if (self.cursor >= total) {
            if (params.loops) {
                self.cursor = @mod(self.cursor, total);
                status.looped = true;
            } else {
                self.finished = true;
                break;
            }
        }

        const i_0: usize = @intFromFloat(self.cursor);
        const i_1: usize = if (i_0 + 1 < frame_count) i_0 + 1 else if (params.loops) 0 else i_0;
        const t: f32 = @floatCast(self.cursor - @floor(self.cursor));

        const l = std.math.lerp(stream.samples[i_0 * ch], stream.samples[i_1 * ch], t);
        const r = std.math.lerp(stream.samples[i_0 * ch + ch - 1], stream.samples[i_1 * ch + ch - 1], t);

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