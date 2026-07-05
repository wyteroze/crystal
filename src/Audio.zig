// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");
const wav_parser = @import("parsers/wav.zig");

pub const Audio = struct {
    channels: u16,
    sample_rate: u32,
    bits_per_sample: u16,
    data: []u8,

    pub fn init(channels: u16, sample_rate: u32, bits_per_sample: u16, data: []u8) Audio {
        return .{
            .channels = channels,
            .sample_rate = sample_rate,
            .bits_per_sample = bits_per_sample,
            .data = data
        };
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Audio {
        var file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;

        var file_reader = file.reader(io, &buffer);
        const reader = &file_reader.interface;

        const audio = try wav_parser.ParseWav(allocator, reader);
        return audio;
    }

    pub fn deinit(self: *Audio, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};
