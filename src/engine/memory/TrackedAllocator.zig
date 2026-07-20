// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");

/// This returns a new allocator that tracks
/// the bytes allocated and freed via `alloc` and `free`
/// Get the current memory usage in bytes with `.currentUsage()`
pub const TrackedAllocator = struct {
    child: std.mem.Allocator,
    bytes_allocated: usize = 0,
    bytes_freed: usize = 0,

    const Self = @This();

    pub fn init(child: std.mem.Allocator) Self {
        return .{ .child = child };
    }

    /// Returns an allocator, with tracked allocations and frees.
    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .free = free,
                .resize = resize,
                .remap = remap,
            }
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.child.rawAlloc(len, alignment, ret_addr);
        if (result != null) self.bytes_allocated += len;

        return result;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.child.rawFree(buf, alignment, ret_addr);
        self.bytes_freed += buf.len;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const ok = self.child.rawResize(buf, alignment, new_len, ret_addr);
        if (ok) {
            if (new_len > buf.len) self.bytes_allocated += new_len - buf.len
            else self.bytes_freed += buf.len - new_len;
        }

        return ok;
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.child.rawRemap(buf, alignment, new_len, ret_addr);
        if (result != null) {
            if (new_len > buf.len) self.bytes_allocated += new_len - buf.len
            else self.bytes_freed += buf.len - new_len;
        }

        return result;
    }

    /// Returns the current memory usage of the allocator in bytes.
    pub fn currentUsage(self: *const Self) usize {
        return self.bytes_allocated - self.bytes_freed;
    }
};
