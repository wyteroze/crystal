// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Assets = @import("../assets/Assets.zig");
const Platform = @import("../platform/Platform.zig");
const RingBuffer = @import("RingBuffer.zig").RingBuffer;
pub const types = @import("types.zig");
pub const Mixer = @import("mixer/Mixer.zig");
pub const Speaker = @import("Speaker.zig");
pub const AudioTrack = @import("AudioTrack.zig");

pub const channels = 2;
pub const chunk_frames = 512;
pub const sample_rate = 48000; // 48khz.. duh
pub const max_voices = 256;

pub const Event = union(enum) {
    voice_finished: Mixer.Voice.VoiceId,
};
pub const AudioEvents = RingBuffer(Event, 1024);

const Audio = @This();
io: std.Io,
allocator: std.mem.Allocator,
events: AudioEvents,
platform: *Platform,
mixer: Mixer,
device: Platform.types.AudioDeviceHandle,
stream: Platform.types.AudioStreamHandle,

// For voices
generations: [max_voices]u16,
alive: [max_voices]bool,
free: [max_voices]u16,
free_len: usize,

pub fn init(self: *Audio, io: std.Io, allocator: std.mem.Allocator, platform: *Platform) !void {
    const spec: Platform.desc.AudioSpec = .{ .channels = 2, .sample_rate = sample_rate, .format = .f32_le };

    self.* = .{
        .io = io,
        .allocator = allocator,
        .platform = platform,
        .events = .{},
        .mixer = try .init(platform, &self.events),
        .device = undefined,
        .stream = undefined,
        .generations = @splat(0),
        .alive = @splat(false),
        .free = undefined,
        .free_len = max_voices,
    };
    for (0..max_voices) |i| self.free[i] = @intCast(max_voices-1-i);

    self.device = try platform.openAudioDevice(spec);
    errdefer platform.closeAudioDevice(self.device);

    self.stream = try platform.audioDeviceCreateStream(self.device, spec, Mixer, Mixer.streamCallback, &self.mixer);
    platform.resumeAudioStream(self.stream); // Paused by default
}

pub fn deinit(self: *Audio) void {
    self.mixer.deinit();
    self.platform.deinitStream(self.stream);
    self.platform.closeAudioDevice(self.device);
}

pub fn play(self: *Audio, asset: Assets.AssetHandle, params: Mixer.Voice.VoiceParams) !AudioTrack {
    if (self.free_len == 0) return error.TooManyVoices;
    const index = self.free[self.free_len-1];
    const id: Mixer.Voice.VoiceId = .{ .index = index, .generation = self.generations[index] };

    if (!self.mixer.mixer_commands.push(.{ .play = .{
        .voice = id, .asset = asset.cpuClone(), .params = params
    } })) return error.TooManyVoices;

    self.free_len -= 1;
    self.alive[index] = true;

    return .{ .playing = true, .voice = id, .stream = asset.cpuClone() };
}

pub fn stop(self: *Audio, id: Mixer.Voice.VoiceId) bool {
    if (!self.mixer.mixer_commands.push(.{ .stop = id })) {
        std.log.err("Tried to stop a voice, but the mixer queue is full.", .{});
        return false;
    }

    return true;
}

pub fn destroy(self: *Audio, id: Mixer.Voice.VoiceId) void {
    if (!self.mixer.mixer_commands.push(.{ .destroy = id })) 
        std.log.err("Tried to destroy a voice, but the mixer queue is full.", .{});
}

pub fn setListener(self: *Audio, l: types.AudioListener) void {
    if (!self.mixer.mixer_commands.push(.{ .set_listener = l })) 
        std.log.err("Tried to set listener, but the mixer queue is full.", .{});
}

pub fn setParams(self: *Audio, id: Mixer.Voice.VoiceId, params: Mixer.Voice.VoiceParams) void {
    if (!self.mixer.mixer_commands.push(.{ .set_params = .{ .voice = id, .params = params } }))
        std.log.err("Tried to set a voice's params, but the mixer queue is full.", .{});
}

pub fn isAlive(self: *const Audio, id: Mixer.Voice.VoiceId) bool {
    return self.alive[id.index] and self.generations[id.index] == id.generation;
}

pub fn tick(self: *Audio) void {
    while (self.events.pop()) |ev| switch (ev) {
        .voice_finished => |id| {
            self.generations[id.index] +%= 1;
            self.alive[id.index] = false;
            self.free[self.free_len] = id.index;
            self.free_len += 1;
        },
    };
}