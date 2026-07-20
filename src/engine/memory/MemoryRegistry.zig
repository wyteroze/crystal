// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const TrackedAllocator = @import("TrackedAllocator.zig").TrackedAllocator;

/// MemoryRegistry is used to create memory categories and audit their info.
pub const MemoryRegistry = struct {
    allocator: std.mem.Allocator,
    categories: std.StringHashMap(*TrackedAllocator),

    pub fn init(allocator: std.mem.Allocator) MemoryRegistry {
        return .{ .allocator = allocator, .categories = .init(allocator) };
    }

    /// Creates a category and returns its associated allocator. All allocations and deallocations
    /// are tracked; retrieve the usage info via `MemoryRegistry.getCategoryUsage()`
    pub fn createCategory(self: *MemoryRegistry, category: []const u8) !std.mem.Allocator {
        if (self.categories.get(category) != null) return error.CategoryAlreadyExists;

        var allocator = try self.allocator.create(TrackedAllocator);
        allocator.* = TrackedAllocator.init(self.allocator);

        try self.categories.put(category, allocator);
        return allocator.allocator();
    }

    /// Returns the current memory usage in bytes of the given memory category.
    pub fn getCategoryUsage(self: MemoryRegistry, category: []const u8) !usize {
        var allocator = self.categories.get(category) orelse return error.CategoryNotCreated;
        return allocator.currentUsage();
    }

    /// Returns the total bytes allocated of the given memory category.
    pub fn getCategoryBytesAllocated(self: MemoryRegistry, category: []const u8) !usize {
        const allocator = self.categories.get(category) orelse return error.CategoryNotCreated;
        return allocator.bytes_allocated;
    }

    /// Returns the total bytes freed of the given memory category.
    pub fn getCategoryBytesFreed(self: MemoryRegistry, category: []const u8) !usize {
        const allocator = self.categories.get(category) orelse return error.CategoryNotCreated;
        return allocator.bytes_freed;
    }


    /// Returns the current memory usage in bytes across all registered memory categories.
    pub fn getAllCategoriesUsage(self: MemoryRegistry) !usize {
        var iter = self.categories.iterator();
        var total: usize = 0;

        while (iter.next()) |e| {
            total += e.value_ptr.currentUsage();
        }

        return total;
    }

    /// Returns the total bytes allocated across all registered memory categories.
    pub fn getAllCategoriesBytesAllocated(self: MemoryRegistry) !usize {
        var iter = self.categories.iterator();
        var total: usize = 0;

        while (iter.next()) |e| {
            total += e.value_ptr.bytes_allocated;
        }

        return total;
    }

    /// Returns the total bytes freed across all registered memory categories.
    pub fn getAllCategoriesBytesFreed(self: MemoryRegistry) !usize {
        var iter = self.categories.iterator();
        var total: usize = 0;

        while (iter.next()) |e| {
            total += e.value_ptr.bytes_freed;
        }

        return total;
    }
};
