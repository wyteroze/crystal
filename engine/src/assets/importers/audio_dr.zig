// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const types = @import("../types.zig");
const ImportLocation = @import("importers.zig").ImportLocation;
const audio_dr = @import("dr_libs");

/// In auto mode, anything longer than this is streamed.
const stream_threshhold_seconds = 5.0;

pub const ImportOptions = struct {
    format: types.AudioFormat,
    mode: enum { auto, decode, stream } = .auto
};

const Info = struct {
    frames: u64,
    sample_rate: u32,
    channels: u8,

    fn duration(self: Info) f64 {
        return @as(f64, @floatFromInt(self.frames)) / @as(f64, @floatFromInt(self.sample_rate));
    }
};

fn getAudioInfo(bytes: []const u8, format: types.AudioFormat) !Info {
    switch (format) {
        .mp3 => {
            var mp3: audio_dr.drmp3 = undefined;
            if (audio_dr.drmp3_init_memory(&mp3, bytes.ptr, bytes.len, null) == 0) return error.Mp3AudioDecodeFailed;
            defer audio_dr.drmp3_uninit(&mp3);
            
            return .{
                .frames = audio_dr.drmp3_get_pcm_frame_count(&mp3),
                .sample_rate = @intCast(mp3.sampleRate),
                .channels = @intCast(mp3.channels),
            };
        },
        .wav => {
            var wav: audio_dr.drwav = undefined;
            if (audio_dr.drwav_init_memory(&wav, bytes.ptr, bytes.len, null) == 0) return error.WavAudioDecodeFailed;
            defer _ = audio_dr.drwav_uninit(&wav);
            
            return .{
                .frames = wav.totalPCMFrameCount,
                .sample_rate = @intCast(wav.sampleRate),
                .channels = @intCast(wav.channels),
            };
        },
    }
}

pub fn decodeFull(allocator: std.mem.Allocator, location: ImportLocation, options: ImportOptions) !types.AudioStream {
    var data: []f32 = undefined;
    var channels: u8 = 0;
    var sample_rate: u32 = 0;
    var num_frames: usize = 0;

    switch (options.format) {
        .mp3 => {
            var config = std.mem.zeroes(audio_dr.drmp3_config);
            var frame_count = std.mem.zeroes(audio_dr.drmp3_uint64);

            const sample_data = switch (location) {
                .bytes => |b| audio_dr.drmp3_open_memory_and_read_pcm_frames_f32(b.ptr, b.len, &config, &frame_count, null),
                .path => |p| blk: {
                    const path_z = try allocator.dupeSentinel(u8, p, 0); 
                    defer allocator.free(path_z);
                    break :blk audio_dr.drmp3_open_file_and_read_pcm_frames_f32(path_z.ptr, &config, &frame_count, null);
                }
            } orelse return error.Mp3AudioDecodeFailed;
            defer audio_dr.drmp3_free(sample_data, null);

            const total_samples = frame_count * config.channels;
            data = try allocator.dupe(f32, sample_data[0..total_samples]);
            sample_rate = @intCast(config.sampleRate);
            channels = @intCast(config.channels);
            num_frames = @intCast(frame_count);
        },
        .wav => {
            var wav: audio_dr.drwav = undefined;

            const ok = switch (location) {
                .bytes => |b| audio_dr.drwav_init_memory(&wav, b.ptr, b.len, null),
                .path => |p| blk: { 
                    const path_z = try allocator.dupeSentinel(u8, p, 0); 
                    defer allocator.free(path_z);
                    break :blk audio_dr.drwav_init_file(&wav, path_z.ptr, null);
                }
            };
            if (ok == 0) return error.WavAudioDecodeFailed;
            defer _ = audio_dr.drwav_uninit(&wav);

            const total_samples = wav.totalPCMFrameCount * wav.channels;
            const buffer = try allocator.alloc(f32, total_samples);
            errdefer allocator.free(buffer);

            const frames_read = audio_dr.drwav_read_pcm_frames_f32(&wav, wav.totalPCMFrameCount, buffer.ptr);
            if (frames_read != wav.totalPCMFrameCount) return error.WavAudioDecodeFailed;

            data = buffer;
            sample_rate = @intCast(wav.sampleRate);
            channels = @intCast(wav.channels);
            num_frames = @intCast(wav.totalPCMFrameCount);
        }
    }

    return .{
        .source = .{ .decoded = data },
        .sample_rate = sample_rate,
        .channels = channels,
        .duration = @as(f64, @floatFromInt(num_frames)) / @as(f64, @floatFromInt(sample_rate)),
    };
}

pub fn importAudio(allocator: std.mem.Allocator, location: ImportLocation, options: ImportOptions) !types.AudioStream {
    const bytes = switch (location) {
        .bytes => |b| b,
        .path => return decodeFull(allocator, location, options),
    };

    const info = try getAudioInfo(bytes, options.format);
    const should_stream = switch (options.mode) {
        .decode => false,
        .stream => true,
        .auto => info.duration() > stream_threshhold_seconds
    };
    if (!should_stream) return decodeFull(allocator, location, options);

    return .{
        .source = .{ .streamed = .{
            .format = options.format,
            .bytes = try allocator.dupe(u8, bytes),
            .total_frames = info.frames
        } },
        .sample_rate = info.sample_rate,
        .channels = info.channels,
        .duration = info.duration()
    };
}