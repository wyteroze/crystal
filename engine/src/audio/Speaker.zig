// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const bind = @import("../scripting/bind/bind.zig");
const Assets = @import("../assets/Assets.zig");
const types = @import("types.zig");
const Audio = @import("Audio.zig");

const min_volume = 0.0;
const max_volume = 10.0;

const Speaker = @This();
volume: f32 = 1,
min_distance: f32 = 1,
max_distance: f32 = 100,
attenuation: types.Attenuation = .inverse_square,

pub const sub_api = bind.record(Speaker, .{ .handle = SpeakerHandle });

pub const SpeakerHandle = struct {
    entity: ecs.Entity,
    audio: *Audio,

    pub fn get(self: SpeakerHandle) ?*Speaker {
        // TODO!!!!!!!!!!!!!!!!!!! Stop querying `id` so often, create it once then save it somewhere
        // like a struct instead of having to do this so often (plus it looks ugly)
        const id = self.entity.world.components.id("Speaker") orelse unreachable;
        return self.entity.world.getComponent(self.entity, id, Speaker);
    }

    pub fn require(self: SpeakerHandle) !*Speaker { 
        return self.get() orelse error.SpeakerRemoved;
    }

    pub fn isAlive(self: SpeakerHandle) bool { 
        return self.get() != null;
    }

    pub fn load(self: SpeakerHandle, asset: Assets.AssetHandle) !Audio.track.TrackHandle {
        _ = try self.require();
        return self.audio.create(asset, self.entity);
    }

    pub fn play(self: SpeakerHandle, asset: Assets.AssetHandle) !Audio.track.TrackHandle {
        const t = try self.load(asset);
        try self.audio.start(t, .{});

        return t;
    }

    pub fn fromComponent(host: anytype, e: ecs.Entity) SpeakerHandle {
        return .{ .entity = e, .audio = host.audio };
    }

    pub const sub_api = bind.handle(SpeakerHandle, .{
        .name = "Speaker",
        .alive = bind.func("isAlive", SpeakerHandle.isAlive),
        .methods = &.{
            bind.func("Play", SpeakerHandle.play)
        },
        .props = &.{
            bind.prop("Volume", struct {
                fn get(self: SpeakerHandle) !f32 { return (try self.require()).volume; }
            }.get, struct {
                fn set(self: SpeakerHandle, volume: f32) !void { (try self.require()).volume = std.math.clamp(volume, min_volume, max_volume); }
            }.set),
            bind.prop("MinDistance", struct {
                fn get(self: SpeakerHandle) !f32 { return (try self.require()).min_distance; }
            }.get, struct {
                fn set(self: SpeakerHandle, distance: f32) !void { (try self.require()).min_distance = @max(distance, 0); }
            }.set),
            bind.prop("MaxDistance", struct {
                fn get(self: SpeakerHandle) !f32 { return (try self.require()).max_distance; }
            }.get, struct {
                fn set(self: SpeakerHandle, distance: f32) !void { (try self.require()).max_distance = @max(distance, 0); }
            }.set),
            bind.prop("Attenuation", struct {
                fn get(self: SpeakerHandle) !Audio.types.Attenuation { return (try self.require()).attenuation; }
            }.get, struct {
                fn set(self: SpeakerHandle, attenuation: Audio.types.Attenuation) !void { (try self.require()).attenuation = attenuation; }
            }.set),
        }
    });
};
