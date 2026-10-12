// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const signal = @import("../core/signal.zig");
const Assets = @import("../assets/Assets.zig");
const Platform = @import("../platform/Platform.zig");
const RingBuffer = @import("RingBuffer.zig").RingBuffer;
pub const types = @import("types.zig");
pub const Mixer = @import("mixer/Mixer.zig");
pub const Speaker = @import("Speaker.zig");
pub const track = @import("track.zig");

pub const channels = 2;
pub const chunk_frames = 512;
pub const sample_rate = 48000; // 48khz.. duh
pub const max_voices = 256;

pub const AudioEvents = RingBuffer(Event, 1024);
pub const Event = union(enum) {
    voice_started: Mixer.Voice.VoiceId,
    voice_looped: Mixer.Voice.VoiceId,
    voice_finished: Mixer.Voice.VoiceId,
};

const SlotState = enum(u8) {
    free,
    /// Allocated, but no mixer voice.
    reserved,
    /// Mixer owns a slot for this voice.
    active,
    /// Destroyed, waiting for the mixer's ack
    dying
};

const Audio = @This();
io: std.Io,
allocator: std.mem.Allocator,
events: AudioEvents,
platform: *Platform,
mixer: Mixer,
device: Platform.types.AudioDeviceHandle,
stream: Platform.types.AudioStreamHandle,

tracks: [max_voices]track.Track,
dispatcher: signal.Dispatcher,

// For voices
generations: [max_voices]u16,
slot_state: [max_voices]SlotState,
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
        .tracks = undefined,
        .dispatcher = .init(allocator),
        .generations = @splat(0),
        .slot_state = @splat(.free),
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
    for (0..max_voices) |i| if (self.slot_state[i] != .free) self.release(@intCast(i));

    self.platform.deinitStream(self.stream);
    self.platform.closeAudioDevice(self.device);
    self.dispatcher.deinit();
}

pub fn create(self: *Audio, asset: Assets.AssetHandle, owner: ?ecs.Entity) !track.TrackHandle {
    if (self.free_len == 0) return error.TooManyVoices;
    self.free_len -= 1;
    const index = self.free[self.free_len];

    self.tracks[index] = .{
        .asset = asset.cpuClone(),
        .owner = owner,
        .played = .init(self.allocator, &self.dispatcher),
        .stopped = .init(self.allocator, &self.dispatcher),
        .looped = .init(self.allocator, &self.dispatcher),
    };
    self.slot_state[index] = .reserved;

    return self.getHandle(index);
}

pub fn start(self: *Audio, h: track.TrackHandle, params: Mixer.Voice.VoiceParams) !void {
    const t = try h.require();
    if (self.slot_state[h.id.index] != .reserved) return error.AlreadyPlaying;

    if (!self.mixer.mixer_commands.push(.{ .play = .{
        .voice = h.id,
        .asset = t.asset.cpuClone(),
        .params = params,
    } })) return error.MixerQueueFull;

    self.slot_state[h.id.index] = .active;
    t.playing = true;
}

pub fn destroy(self: *Audio, id: Mixer.Voice.VoiceId) void {
    if (!self.isAlive(id)) return;
    const index = id.index;

    switch (self.slot_state[index]) {
        .reserved => self.release(index),
        .active => {
            if (!self.mixer.mixer_commands.push(.{ .destroy = id })) {
                std.log.err("Tried to destroy a voice, but the mixer queue is full.", .{});
                return;
            }
            self.tracks[index].playing = false;
            self.slot_state[index] = .dying;
            self.generations[index] +%= 1;
        },
        .free, .dying => {},
    }
}

fn release(self: *Audio, index: u16) void {
    const t = &self.tracks[index];
    t.played.deinit();
    t.stopped.deinit();
    t.looped.deinit();
    t.asset.cpuRelease();

    if (self.slot_state[index] != .dying) self.generations[index] +%= 1;
    self.slot_state[index] = .free;
    self.free[self.free_len] = index;
    self.free_len += 1;
}

pub fn stop(self: *Audio, id: Mixer.Voice.VoiceId) bool {
    if (!self.mixer.mixer_commands.push(.{ .stop = id })) {
        std.log.err("Tried to stop a voice, but the mixer queue is full.", .{});
        return false;
    }

    return true;
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
    if (self.generations[id.index] != id.generation) return false;
    return switch (self.slot_state[id.index]) {
        .reserved, .active => true,
        .free, .dying => false,
    };
}

pub fn getHandle(self: *Audio, index: u16) track.TrackHandle {
    return .{ .audio = self, .id = .{ .index = index, .generation = self.generations[index] } };
}

pub fn tick(self: *Audio) void {
    while (self.events.pop()) |ev| switch (ev) {
        .voice_started => |id| if (self.isAlive(id)) {
            self.tracks[id.index].played.fire(.{self.getHandle(id.index)});
        },
        .voice_looped => |id| if (self.isAlive(id)) {
            self.tracks[id.index].looped.fire(.{self.getHandle(id.index)});
        },
        .voice_finished => |id| {
            const index = id.index;
            switch (self.slot_state[index]) {
                // Lua called `:Destroy()`, and now the mixer has acknowledged it.
                .dying => self.release(index),

                .active => {
                    const h = self.getHandle(index);
                    const t = &self.tracks[index];

                    // Mark as replayable before trying to fire any events,
                    // so callbacks can safely call :Play() or :Destroy().
                    self.slot_state[index] = .reserved;
                    t.playing = false;
                    t.stopped.fire(.{h});
                    self.dispatcher.flush();

                    if (t.destroy_on_finish and self.slot_state[index] == .reserved and h.get() != null)
                        self.release(index);
                },
                .free, .reserved => {},
            }
        },
    };

    self.dispatcher.flush();
}

const bind = @import("../scripting/bind/bind.zig");
pub const api = bind.module("audio", .{
    .kind = .{ .singleton = Audio },
    .members = &.{
        track.sub_api,
        Speaker.sub_api,
        Speaker.SpeakerHandle.sub_api
    }
});