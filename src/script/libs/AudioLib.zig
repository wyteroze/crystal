// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const AudioEngine = @import("../../audio/AudioEngine.zig").AudioEngine;
const AudioSource = @import("../../audio/AudioSource.zig").AudioSource;
const AudioData   = @import("../../audio/AudioData.zig").AudioData;
const Handle = @import("../reflect/marshal.zig").Handle;

pub const AudioLib = struct {
    pub const name = "Audio";
    pub const hidden = .{ "audio_engine" };
    audio_engine: *AudioEngine,

    pub fn init(audio_engine: *AudioEngine) AudioLib {
        return .{
            .audio_engine = audio_engine
        };
    }

    pub fn new(self: *AudioLib, audioData: Handle(AudioData)) !Handle(AudioSource) {
        const src = try self.audio_engine.createSource(audioData.ptr);

        return .{ .ptr = src };
    }
};
