// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const signal = @import("../core/signal.zig");
const Assets = @import("../assets/Assets.zig");
const Audio = @import("Audio.zig");
const Mixer = @import("mixer/Mixer.zig");

pub const TrackEvent = signal.Signal(.{ TrackHandle });

pub const Track = struct {
    asset: Assets.AssetHandle,
    volume: f32 = 1,
    pitch: f32 = 1,
    loops: bool = false,
    playing: bool = false,
    destroy_on_finish: bool = false,
    // Entity ID of the parent speaker, if any.
    owner: ?ecs.Entity = null,
    played: TrackEvent,
    stopped: TrackEvent,
    looped: TrackEvent
};

pub const TrackHandle = struct {
    audio: *Audio,
    id: Mixer.Voice.VoiceId,

    pub fn isAlive(self: TrackHandle) bool {
        return self.audio.isAlive(self.id);
    }
    pub fn get(self: TrackHandle) ?*Track {
        return if (self.isAlive()) &self.audio.tracks[self.id.index] else null;
    }
    pub fn require(self: TrackHandle) !*Track {
        return self.get() orelse error.TrackDestroyed;
    }
    pub fn eql(a: TrackHandle, b: TrackHandle) bool {
        return a.audio == b.audio and a.id.index == b.id.index and a.id.generation == b.id.generation;
    }
};

const bind = @import("../scripting/bind/bind.zig");
pub const sub_api = bind.handle(TrackHandle, .{
    .name = "AudioTrack",
    .alive = bind.func("isAlive", TrackHandle.isAlive),
    .methods = &.{
        bind.func("Play", struct { 
            fn c(h: TrackHandle) !void {
                const self = try h.require();
                try h.audio.start(h, .{
                    .volume = self.volume,
                    .pitch = self.pitch,
                    .loops = self.loops,
                });
            }
        }.c),
        bind.func("Stop", struct { 
            fn c(h: TrackHandle) !void { 
                if (!h.isAlive()) return error.TrackDestroyed;
                _ = h.audio.stop(h.id); 
            } 
        }.c),
        bind.func("Destroy", struct { 
            fn c(h: TrackHandle) void { 
                if (h.isAlive()) h.audio.destroy(h.id); 
            } 
        }.c),
    },
    .signals = &.{
        bind.signal("Played", struct {
            fn c(self: TrackHandle) !*TrackEvent {
                return &(try self.require()).played;
            }
        }.c),
        bind.signal("Looped", struct {
            fn c(self: TrackHandle) !*TrackEvent {
                return &(try self.require()).looped;
            }
        }.c),
        bind.signal("Stopped", struct {
            fn c(self: TrackHandle) !*TrackEvent {
                return &(try self.require()).stopped;
            }
        }.c)
    }
});