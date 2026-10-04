// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Assets = @import("../../assets/Assets.zig");
const Platform = @import("../../platform/Platform.zig");
const RingBuffer = @import("../RingBuffer.zig").RingBuffer;
const Audio = @import("../Audio.zig");
pub const Voice = @import("Voice.zig");

pub const Command = union(enum) {
    play: struct { voice: Voice.VoiceId, asset: Assets.AssetHandle, params: Voice.VoiceParams },
    stop: Voice.VoiceId,
    destroy: Voice.VoiceId,
    set_params: struct { voice: Voice.VoiceId, params: Voice.VoiceParams },
    set_listener: Audio.types.AudioListener
};
pub const MixerCommands = RingBuffer(Command, 1024);
pub const AudioEvents = Audio.AudioEvents;

const Mixer = @This();
mixer_commands: MixerCommands = .{},
audio_events: *AudioEvents,
platform: *Platform,
listener: Audio.types.AudioListener = .{},
temp_storage: [Audio.chunk_frames * Audio.channels]f32 = undefined,
voices: [Audio.max_voices]Voice = @splat(.{}),

pub fn init(platform: *Platform, audio_events: *AudioEvents) !Mixer {
    return .{ .audio_events = audio_events, .platform = platform };
}

pub fn deinit(self: *Mixer) void {
    for (self.voices) |v| v.deinit();
}

pub fn streamCallback(ctx: ?*Mixer, stream: Platform.types.AudioStreamHandle, needed: usize, _: usize) void {
    const self = ctx.?; 
    
    while (self.mixer_commands.pop()) |c| self.doCommand(c);

    const bytes_per_frame = Audio.channels * @sizeOf(f32);
    var frames_left = needed / bytes_per_frame;

    while (frames_left > 0) {
        const n: usize = @min(frames_left, Audio.chunk_frames);
        const out = self.temp_storage[0..n * Audio.channels];
        @memset(out, 0);

        for (&self.voices) |*v| {
            if (!v.active) continue;
            if (!v.finished) v.mixInto(out, n, self.listener);
            if (v.finished and self.audio_events.push(.{ .voice_finished = v.id })) v.active = false;
        }

        self.platform.putAudioStreamData(stream, std.mem.sliceAsBytes(out)) catch continue;
        frames_left -= n;
    }
}

fn doCommand(self: *Mixer, cmd: Command) void {
    switch (cmd) {
        .play => |p| {
            self.voices[p.voice.index] = .{
                .active = true,
                .id = .{ .index = p.voice.index, .generation = p.voice.generation },
                .stream = p.asset,
                .params = p.params,
                .gain = 0
            };
        },
        .stop => |id| {
            const v = &self.voices[id.index];
            if (v.active and v.id.generation == id.generation) v.finished = true;
        },
        .destroy => |id| {
            const v = &self.voices[id.index];
            v.deinit();
        },
        .set_params => |p| {
            const v = &self.voices[p.voice.index];
            if (v.active and v.id.generation == p.voice.generation) v.params = p.params;
        },
        .set_listener => |l| {
            self.listener = l;
        },
    }
}