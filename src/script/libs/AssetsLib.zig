// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const log = @import("../../log.zig").engine;
const Diagnostic = @import("../shared.zig").Diagnostic;
const MeshData = @import("../../MeshData.zig").MeshData;
const ImageData = @import("../../ImageData.zig").ImageData;
const AudioData = @import("../../audio/AudioData.zig").AudioData;
const marshal = @import("../reflect/marshal.zig");

const mesh_path = "src/assets/models/";
const image_path = "src/assets/images/";
const audio_path = "src/assets/audios/";

pub const AssetsLib = struct {
    pub const name = "Assets";
    diagnostic: Diagnostic = Diagnostic{},
    allocator: std.mem.Allocator,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) AssetsLib {
        return .{
            .allocator = allocator,
            .io = io
        };
    }

    pub fn loadMesh(self: *AssetsLib, path: []const u8) !MeshData {
        const full_path = try std.mem.concat(self.allocator, u8, &.{ mesh_path, path });
        defer self.allocator.free(full_path);

        return MeshData.loadFromFile(marshal.ref_allocator, self.io, full_path) catch |e| {
            self.diagnostic.set("failed to load mesh from '{s}': {s}", .{ full_path, @errorName(e) });
            return e;
        };
    }

    pub fn loadImage(self: *AssetsLib, path: []const u8) !ImageData {
        const full_path = try std.mem.concat(self.allocator, u8, &.{ image_path, path });
        defer self.allocator.free(full_path);

        return ImageData.loadFromFile(marshal.ref_allocator, self.io, full_path) catch |e| {
            self.diagnostic.set("failed to load image from '{s}': {s}", .{ full_path, @errorName(e) });
            return e;
        };
    }

    pub fn loadAudio(self: *AssetsLib, path: []const u8) !AudioData {
        const full_path = try std.mem.concat(self.allocator, u8, &.{ audio_path, path });
        defer self.allocator.free(full_path);

        return AudioData.loadFromFile(marshal.ref_allocator, self.io, full_path) catch |e| {
            self.diagnostic.set("failed to load sound from '{s}': {s}", .{ full_path, @errorName(e) });
            return e;
        };
    }
};
