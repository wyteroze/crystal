// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../gpu/gpu.zig");
const Source = @import("sources/Source.zig");
const DirSource = @import("sources/DirSource.zig");
const asset_sources = @import("sources/sources.zig").sources;
pub const AssetData = @import("AssetData.zig");
pub const AssetUri = @import("AssetUri.zig");
pub const types = @import("types.zig");

pub const AssetHandle = struct { 
    id: u64, 
    assets: *Assets,

    pub fn hasCpuData(self: AssetHandle) bool {
        if (self.assets.getCpuData(self.id)) |_| true else |_| false;
    }

    pub fn hasGpuData(self: AssetHandle) bool {
        if (self.assets.getGpuData(self.id)) |_| true else |_| false;
    }

    // handling functions for these errors at every call site would be
    // annoying, it's better to handle it here instead of bubbling it up to the caller
    pub fn cpuClone(self: AssetHandle) AssetHandle {
        self.assets.cpuRef(self.id) catch {
            std.log.warn("attempt to clone cpu data when none exists", .{});
        };
        return self;
    }

    pub fn cpuRelease(self: AssetHandle) void {
        self.assets.cpuDeref(self.id) catch {
            std.log.warn("attempt to release cpu data when none exists", .{});
        };
    }
    
    pub fn gpuClone(self: AssetHandle) AssetHandle {
        self.assets.gpuRef(self.id) catch {
            std.log.warn("attempt to clone gpu data when none exists", .{});
        };
        return self;
    }

    pub fn gpuRelease(self: AssetHandle) void {
        self.assets.gpuDeref(self.id) catch {
            std.log.warn("attempt to release gpu data when none exists", .{});
        };
    }

    pub fn cpuGet(self: AssetHandle, comptime asset_type: AssetData.AssetType) !switch (asset_type) {
        .mesh => types.Mesh,
        .image => types.Image,
        .script_source => types.ScriptSource
    } {
        const data = try self.assets.getCpuData(self.id);
        const a_type = @as(AssetData.AssetType, data);
        if (a_type != asset_type) return error.WrongAssetKind; 

        return @field(data, @tagName(asset_type));
    }

    pub fn gpuGet(self: AssetHandle, comptime asset_type: AssetData.AssetType) !switch (asset_type) {
        .mesh => types.GpuMesh,
        .image => types.GpuImage,
        .script_source => unreachable
    } {
        const data = try self.assets.getGpuData(self.id);
        const a_type = @as(AssetData.AssetType, data);
        if (a_type != asset_type) return error.WrongAssetKind; 
        if (!a_type.uploadable()) return error.UnuploadableAssetKind;

        return @field(data, @tagName(asset_type));
    }

    pub const __lua = .val;
    pub const __opaque = true;
    pub fn format(self: AssetHandle, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "Asset {f}", .{ self.id })
            catch "Asset ?";
    }
};

// cpu_data = null and gpu_data = null is an invalid state
// cpu_data without cpu_data_refcount or gpu_data without gpu_data_refcount
// is also an invalid state
pub const AssetEntry = struct {
    cpu_data: ?AssetData.CpuAssetData,
    gpu_data: ?AssetData.GpuAssetData = null,
    cpu_data_refcount: ?u32,
    gpu_data_refcount: ?u32 = null,
    path: []const u8,

    pub fn deinit(self: AssetEntry, allocator: std.mem.Allocator) void {
        if (self.cpu_data) |d| d.deinit(allocator);
        if (self.gpu_data) |d| d.deinit();
        allocator.free(self.path);
    }
};

const hash_seed = 1337;

const Assets = @This();
io: std.Io,
allocator: std.mem.Allocator,
gpu_device: *gpu.GpuDevice,
slots: std.AutoHashMap(u64, AssetEntry),
sources: std.StringHashMap(*DirSource),

pub fn init(allocator: std.mem.Allocator, io: std.Io, gpu_device: *gpu.GpuDevice, proj_path: ?[]const u8) !Assets {
    var sources: std.StringHashMap(*DirSource) = .init(allocator);

    inline for (asset_sources) |s| {
        const src_ptr = try allocator.create(DirSource);
        src_ptr.* = try s.init(allocator, io);
        if (std.mem.eql(u8, s.scheme, "assets") and proj_path != null) {
            const path = try std.Io.Dir.path.join(allocator, &.{ proj_path.?, "assets" });
            defer allocator.free(path);
            src_ptr.*.base_dir = try .openDir(.cwd(), io, path, .{});
        }

        try sources.put(s.scheme, src_ptr);
    }

    return .{
        .io = io,
        .allocator = allocator,
        .gpu_device = gpu_device,
        .slots = .init(allocator),
        .sources = sources
    };
}

pub fn deinit(self: *Assets) void {
    var slots_iter = self.slots.iterator();
    while (slots_iter.next()) |s| s.value_ptr.deinit(self.allocator);
    self.slots.deinit();

    var sources_iter = self.sources.iterator();
    while (sources_iter.next()) |s| self.allocator.destroy(s.value_ptr.*);
    self.sources.deinit();
}

pub fn load(self: *Assets, path: []const u8) !AssetHandle {
    const uri: AssetUri = try .parse(self.allocator, path);
    defer uri.deinit(self.allocator);

    const source = self.sources.get(uri.scheme) orelse {
        std.log.err("unknown scheme '{s}://'", .{ uri.scheme });
        return error.UnknownScheme;
    };
    const id = std.hash.Wyhash.hash(hash_seed, path);
    if (self.slots.getPtr(id)) |slot| if (slot.cpu_data != null) {
        slot.cpu_data_refcount.? += 1;
        return .{ .id = id, .assets = self };
    };

    const bytes = try source.source().read(uri.path);
    const data: AssetData.CpuAssetData = try .parse(self.allocator, self.io, path, bytes);
    try self.slots.put(id, .{ .cpu_data = data, .cpu_data_refcount = 1, .path = try self.allocator.dupe(u8, path) });

    return .{ .id = id, .assets = self };
}

pub fn upload(self: *Assets, handle: AssetHandle) !void {
    const entry = self.slots.getPtr(handle.id) orelse return error.InvalidHandle;
    if (entry.gpu_data != null) {
        entry.gpu_data_refcount.? += 1;
        return;
    }

    if (entry.cpu_data == null) return error.NoCpuData;
    const asset_type = std.meta.activeTag(entry.cpu_data.?);
    if (!asset_type.uploadable()) return error.IncompatibleAssetType;

    const gpu_data: AssetData.GpuAssetData = 
        try .fromCpuData(entry.cpu_data.?, entry.path, self.allocator, self.gpu_device);

    entry.gpu_data = gpu_data;
    entry.gpu_data_refcount = 1;
}

pub fn tick(self: *Assets) usize {
    var purged: usize = 0;

    var it = self.slots.iterator();
    while (it.next()) |e| {
        const entry = e.value_ptr;
        if (entry.cpu_data) |data| if (entry.cpu_data_refcount == 0) {
            purged += 1;
            data.deinit(self.allocator);
            entry.cpu_data = null;
        };

        if (entry.gpu_data) |data| if (entry.gpu_data_refcount == 0) {
            purged += 1;
            data.deinit();
            entry.gpu_data = null;
        };

        if (entry.cpu_data == null and entry.gpu_data == null) {
            e.value_ptr.deinit(self.allocator);
            _ = self.slots.remove(e.key_ptr.*);
        }
    }

    return purged;
}

pub fn cpuRef(self: *Assets, id: u64) !void {
    (self.slots.getPtr(id).?.cpu_data_refcount orelse return error.NoCpuData) += 1;
}

pub fn cpuDeref(self: *Assets, id: u64) !void {
    (self.slots.getPtr(id).?.cpu_data_refcount orelse return error.NoCpuData) -= 1;
}

pub fn gpuRef(self: *Assets, id: u64) !void {
    (self.slots.getPtr(id).?.gpu_data_refcount orelse return error.NoGpuData) += 1;
}

pub fn gpuDeref(self: *Assets, id: u64) !void {
    (self.slots.getPtr(id).?.gpu_data_refcount orelse return error.NoGpuData) += 1;
}

pub fn getCpuData(self: *Assets, id: u64) !AssetData.CpuAssetData {
    return self.slots.get(id).?.cpu_data orelse return error.NoCpuData;
}

pub fn getGpuData(self: *Assets, id: u64) !AssetData.GpuAssetData {
    return self.slots.get(id).?.gpu_data orelse return error.NoGpuData;
}

pub const registerLua = struct {
    const zlua = @import("zlua");
    const linker = @import("../scripting/linker/linker.zig");
    const Runtime = @import("../scripting/runtime/Runtime.zig");
    const HandleBind = linker.Binding(AssetHandle, false);

    fn luaLoadAsset(l: *zlua.Lua) !i32 {
        const r: *Runtime = .fromState(l);
        const uri = l.toString(1) catch |e| linker.util.luaErr(l, e, .{ []const u8, 1 });
        const handle = try r.assets.load(uri);

        HandleBind.push(l, handle);
        return 1;
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.reference(l, AssetHandle, .{
            .name = .auto,
            .scope = .{ .module = "assets.types" }
        });

        linker.module(l, .{
            .name = "assets",
            .functions = &.{
                .custom("load", luaLoadAsset)
            },
        });

    }
}.registerLua;