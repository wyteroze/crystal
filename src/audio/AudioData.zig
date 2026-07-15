// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const wav_parser = @import("../parsers/wav.zig");

pub const AudioData = struct {
    pub const lua_ref = true;
    pub const hidden = .{ "channels", "sample_rate", "bits_per_sample", "data", "loadFromFile" };
    channels: u16,
    sample_rate: u32,
    bits_per_sample: u16,
    data: []u8,

    pub fn init(channels: u16, sample_rate: u32, bits_per_sample: u16, data: []u8) AudioData {
        return .{
            .channels = channels,
            .sample_rate = sample_rate,
            .bits_per_sample = bits_per_sample,
            .data = data
        };
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !AudioData {
        var file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;

        var file_reader = file.reader(io, &buffer);
        const reader = &file_reader.interface;

        const audio = try wav_parser.ParseWav(allocator, reader);
        return audio;
    }

    pub fn sdlSpec(self: AudioData) !sdl3.audio.Spec {
        const format: sdl3.audio.Format = switch (self.bits_per_sample) {
            8  => .unsigned_8_bit,
            16 => .signed_16_bit_little_endian,
            32 => .signed_32_bit_little_endian,
            else => return error.UnsupportedBitsPerSample,
        };

        return .{
            .format = format,
            .num_channels = self.channels,
            .sample_rate = self.sample_rate,
        };
    }

    pub fn deinit(self: *AudioData, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};
