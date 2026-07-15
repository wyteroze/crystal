// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
pub const AudioSource = @import("AudioSource.zig").AudioSource;
pub const AudioData = @import("AudioData.zig").AudioData;
pub const Object = @import("../object.zig").Object;
pub const Scene = @import("../Scene.zig").Scene;

// todo: move this to be a property under AudioSource
const max_hearing_distance: f32 = 50.0;

pub const AudioEngine = struct {
    allocator: std.mem.Allocator,
    device: sdl3.audio.Device,
    sources: std.ArrayList(*AudioSource),
    listener: ?*Object,

    pub fn init(allocator: std.mem.Allocator) !AudioEngine {
        const device = try sdl3.audio.Device.default_playback.open(null);

        return .{
            .allocator = allocator,
            .device = device,
            .sources = .empty,
            .listener = null
        };
    }

    pub fn deinit(self: *AudioEngine) void {
        for (self.sources.items) |s| {
            s.deinit();
            self.allocator.destroy(s);
        }
        self.sources.deinit(self.allocator);
        self.device.close();
    }

    pub fn createSource(self: *AudioEngine, data: *const AudioData) !*AudioSource {
        const device_format = try self.device.getFormat();
        const stream = try sdl3.audio.Stream.init(try data.sdlSpec(), device_format[0]);
        errdefer stream.deinit();

        try self.device.bindStream(stream);
        errdefer stream.unbind();

        const src = try self.allocator.create(AudioSource);
        errdefer self.allocator.destroy(src);

        src.* = AudioSource.init(data, stream);

        try self.sources.append(self.allocator, src);
        return src;
    }

    pub fn destroySource(self: *AudioEngine, source: *AudioSource) void {
        for (self.sources.items, 0..) |s, i| {
            if (s == source) {
                _ = self.sources.swapRemove(i);
                break;
            }
        }

        source.deinit();
        self.allocator.destroy(source);
    }

    pub fn tick(self: *AudioEngine, current_scene: *Scene) !void {
        for (current_scene.audios.items) |a| {
            self.applyPositionalGain(a, current_scene);
            try a.update();
        }
    }

    fn objectInScene(_: *AudioEngine, object: *Object, scene: ?*Scene) bool {
        if (scene) |s| {
            for (s.objects.items) |o| {
                if (o == object) return true;
            }
        }

        return false;
    }

    fn applyPositionalGain(self: *AudioEngine, source: *AudioSource, current_scene: ?*Scene) void {
        const attached = source.attached_to orelse {
            source.stream.setGain(source.volume) catch {};
            return;
        };

        const listener = self.listener orelse current_scene.?.camera orelse {
            source.stream.setGain(source.volume) catch {};
            return;
        };

        const source_pos = attached.getPosition().vec;
        const listener_pos = listener.getPosition().vec;
        const diff = source_pos - listener_pos;
        const distance = @sqrt(diff[0] * diff[0] + diff[1] * diff[1] + diff[2] * diff[2]);

        const falloff = std.math.clamp(1.0 - (distance / max_hearing_distance), 0.0, 1.0);
        source.stream.setGain(source.volume * falloff) catch {};
    }
};
