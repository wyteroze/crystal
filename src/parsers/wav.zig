// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const log = @import("../log.zig").wav;
const Audio = @import("../Audio.zig").Audio;

pub const ParseError = error {
    UnexpectedEof,
    InvalidMagic,
    InvalidWaveHeader,
    InvalidFmtHeader,
    InvalidAudioFormat,
    InvalidWavFormat,
    InvalidBitsPerSample,
    UnknownSection,
    MissingDataChunk,
};

pub fn ParseWav(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Audio {
    log.info("parsing wav", .{});

    var riff_header: [4]u8 = undefined;
    reader.readSliceAll(&riff_header)
        catch return ParseError.UnexpectedEof;
    if (!std.mem.eql(u8, &riff_header, "RIFF")) {
        log.warn("invalid wav magic bytes: {s}", .{ riff_header });
        return ParseError.InvalidMagic;
    }

    const riff_chunk_size = reader.takeInt(u32, .little)
        catch return ParseError.UnexpectedEof;
    _ = riff_chunk_size;

    var wave_header: [4]u8 = undefined;
    reader.readSliceAll(&wave_header)
        catch return ParseError.UnexpectedEof;

    if (!std.mem.eql(u8, &wave_header, "WAVE")) {
        log.warn("invalid wave header: {s}", .{ wave_header });
        return ParseError.InvalidWaveHeader;
    }

    var fmt_header: [4]u8 = undefined;
    reader.readSliceAll(&fmt_header)
        catch return ParseError.UnexpectedEof;

    if (!std.mem.eql(u8, &fmt_header, "fmt ")) {
        log.warn("invalid fmt header: {s}", .{ fmt_header });
        return ParseError.InvalidFmtHeader;
    }

    const fmt_chunk_size = reader.takeInt(u32, .little)
        catch return ParseError.UnexpectedEof;
    const audio_format = reader.takeInt(i16, .little)
        catch return ParseError.UnexpectedEof;
    log.debug("audio format: {d}", .{ audio_format });

    if (audio_format != 1) { // 1 = PCM
        log.warn("invalid audio format. expected 1 (PCM) but got: {d}", .{ audio_format });
        return ParseError.InvalidAudioFormat;
    }

    const channels = reader.takeInt(i16, .little)
        catch return ParseError.UnexpectedEof;
    const sample_rate = reader.takeInt(i32, .little)
        catch return ParseError.UnexpectedEof;
    const byte_rate = reader.takeInt(i32, .little)
        catch return ParseError.UnexpectedEof;
    const block_align = reader.takeInt(i16, .little)
        catch return ParseError.UnexpectedEof;
    const bits_per_sample = reader.takeInt(i16, .little)
        catch return ParseError.UnexpectedEof;

    _ = byte_rate;    // sample_rate * block_align
    _ = block_align;  // channels * bits_per_sample / 8

    if (fmt_chunk_size == 18) {
        const extension_size = reader.takeInt(i16, .little)
            catch return ParseError.UnexpectedEof;
        _ = extension_size;
    } else if (fmt_chunk_size == 40) {
        const extension_size = reader.takeInt(i16, .little)
            catch return ParseError.UnexpectedEof;
        const valid_bits_per_sample = reader.takeInt(i16, .little)
            catch return ParseError.UnexpectedEof;
        const channel_mask = reader.takeInt(i32, .little)
            catch return ParseError.UnexpectedEof;
        var sub_format: [16]u8 = undefined;
        reader.readSliceAll(&sub_format)
            catch return ParseError.UnexpectedEof;

        _ = extension_size;
        _ = valid_bits_per_sample;
        _ = channel_mask;

    } else if (fmt_chunk_size != 16) {
        log.warn("invalid wav format", .{});
        return ParseError.InvalidWavFormat;
    }

    var data: []u8 = undefined;
    var found_data = false;
    while (!found_data) {
        var chunk_id: [4]u8 = undefined;
        reader.readSliceAll(&chunk_id)
            catch return ParseError.UnexpectedEof;
        const chunk_size = reader.takeInt(u32, .little)
            catch return ParseError.UnexpectedEof;

        if (std.mem.eql(u8, &chunk_id, "data")) {
            data = reader.readAlloc(allocator, chunk_size)
                catch return ParseError.UnexpectedEof;
            found_data = true;
        } else {
            log.info("skipping unknown chunk '{s}' ({d} bytes)", .{ chunk_id, chunk_size });
            reader.discardAll(chunk_size)
                catch return ParseError.UnexpectedEof;

            if (chunk_size % 2 != 0) {
                reader.discardAll(1) catch return ParseError.UnexpectedEof;
            }
        }
    }

    if (!found_data) {
        return ParseError.MissingDataChunk;
    }

    log.info("parsed wav: channels={d}, sample rate={d}, bits per sample={d}, data size: {d} ", .{ channels, sample_rate, bits_per_sample, data.len });
    return Audio.init(
        @as(u16, @intCast(channels)),
        @as(u32, @intCast(sample_rate)),
        @as(u16, @intCast(bits_per_sample)),
        data,
    );
}
