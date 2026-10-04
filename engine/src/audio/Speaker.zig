// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("types.zig");
const Audio = @import("Audio.zig");
const Assets = @import("../assets/Assets.zig");

const Speaker = @This();
audio: *Audio,
tracks: std.ArrayList(*Audio.AudioTrack) = .empty,
min_distance: f32 = 1,
max_distance: f32 = 100,
attenuation: types.Attenuation = .inverse_square,
volume: f32 = 1,

pub fn play(self: *Speaker, asset: Assets.AssetHandle, params: Audio.Mixer.Voice.VoiceParams) !*Audio.AudioTrack {
    const track = try self.audio.allocator.create(Audio.AudioTrack);
    track.* = try self.audio.play(asset, params);

    try self.tracks.append(self.audio.allocator, track);
    return track;
}

pub fn deinit(self: *Speaker) void {
    for (self.tracks.items) |t| {
        t.deinit();
        self.audio.allocator.destroy(t);
    }
    self.tracks.deinit(self.audio.allocator);
}