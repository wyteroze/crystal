// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const Assets = @import("../assets/Assets.zig");
const Mixer = @import("mixer/Mixer.zig");

const AudioTrack = @This();
stream: Assets.AssetHandle,
volume: f32 = 1,
pitch: f32 = 1,
loops: bool = false,
playing: bool = false,
voice: ?Mixer.Voice.VoiceId = null,

pub fn deinit(self: *AudioTrack) void {
    self.stream.cpuRelease();
}