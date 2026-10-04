// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const core = @import("../../core/core.zig");
const Assets = @import("../../assets/Assets.zig");
const Audio = @import("../Audio.zig");

pub const VoiceId = packed struct { index: u16, generation: u16 };

pub const VoiceParams = struct {
    position: ?core.math.Vec3 = null,
    right: core.math.Vec3 = .new(1, 0, 0),
    volume: f32 = 1.0,
    pitch: f32 = 1.0,
    loops: bool = false
};

const Voice = @This();
active: bool = false,
finished: bool = false,
id: VoiceId = .{ .index = 0, .generation = 0 },
cursor: f64 = 0,
stream: ?Assets.AssetHandle = null,
params: VoiceParams = .{},
gain: f32 = 1,
pan: f32 = 0, // Ranges from -1 to 1

pub fn mixInto(self: *Voice, out: []f32, frames: usize, listener: Audio.types.AudioListener) void {
    const stream = self.stream.?.cpuGet(.audio) catch return;
    const params = &self.params;
    const spatial = params.position != null;

    var target_gain = params.volume;
    var target_pan: f32 = 0;
    if (params.position) |p| {
        const to = p.sub(listener.position);
        const dist = to.length();
        target_gain *= 1.0 / (1.0 + dist);
        if (dist > 10000) target_pan = std.math.clamp(to.dot(listener.right) / dist, -1, 1);
    }

    const frame_count = stream.frameCount();
    const inv: f32 = 1.0 / @as(f32, @floatFromInt(frames));
    const gain_step = (target_gain - self.gain) * inv;
    const pan_step = (target_pan - self.pan) * inv;
    const step: f64 = @as(f64, params.pitch) * @as(f64, @floatFromInt(stream.sample_rate)) / @as(f64, Audio.sample_rate);
    const total: f64 = @floatFromInt(frame_count);
    const ch = stream.channels;

    for (0..frames) |i| {
        if (self.cursor >= total) {
            if (params.loops) self.cursor = @mod(self.cursor, total) else {
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
            o_r = m * @cos(a) * self.gain;
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
}

pub fn deinit(self: *const Voice) void {
    if (self.stream) |s| s.cpuRelease();
}