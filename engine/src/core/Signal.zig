// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub fn SignalConnection(comptime SignalType: type) type {
    return struct {
        const Self = @This();

        signal: *SignalType,
        id: usize,

        pub fn disconnect(self: Self) void {
            self.signal.disconnect(self.id) catch |e| {
                std.log.err("Failed to disconnect callback: {s}", .{ @errorName(e) });
            };
        }

        pub const __lua = .val;
    };
}

pub fn Signal(comptime ArgTypes: anytype) type {
    return struct {
        const Self = @This();

        pub const Args = @Tuple(&ArgTypes);
        pub const Connection = SignalConnection(Self);
        pub const Callback = struct {
            func: *const fn (*anyopaque, Args) void,
            ctx: *anyopaque
        };

        arena: std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,
        callbacks: std.AutoHashMap(usize, Callback),
        next_id: usize = 0,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .arena = .init(allocator),
                .allocator = allocator,
                .callbacks = .init(allocator)
            };
        }

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
            self.callbacks.deinit();
        }

        pub fn fire(self: *Self, args: Args) void {
            var iter = self.callbacks.valueIterator();
            while (iter.next()) |cb| cb.func(cb.ctx, args);
        }

        // To be used by zig
        pub fn connect(self: *Self, comptime func: anytype, ctx: anytype) !Connection {
            const Ctx = @TypeOf(ctx);
            const wrapped = struct {
                fn c(ctx_ptr: *anyopaque, args: Args) void {
                    const ctx_typed: Ctx = @ptrCast(@alignCast(ctx_ptr));
                    @call(.auto, func, .{ ctx_typed } ++ args);
                }
            }.c;
            const id = self.next_id;
            self.next_id += 1;

            try self.callbacks.put(id, .{ .func = wrapped, .ctx = ctx });
            return .{ .signal = self, .id = id };
        }

        // To be used by lua
        pub fn rawConnect(self: *Self, comptime func: anytype, ctx: anytype) !Connection {
            const Ctx = @TypeOf(ctx);
            const FuncInfo = @typeInfo(@TypeOf(func)).@"fn";
            if (FuncInfo.params.len != 2 or FuncInfo.params[1].type.? != Args) {
                @compileError("rawConnect callback must be fn (Ctx, " ++ @typeName(Args) ++ ") void");
            }

            const wrapped = struct {
                fn c(ctx_ptr: *anyopaque, args: Args) void {
                    const typed_ctx: Ctx = @ptrCast(@alignCast(ctx_ptr));
                    func(typed_ctx, args);
                }
            }.c;

            const id = self.next_id;
            self.next_id += 1;

            try self.callbacks.put(id, .{ .func = wrapped, .ctx = ctx });
            return .{ .signal = self, .id = id };
        }

        pub fn disconnect(self: *Self, id: usize) !void {
            if (!self.callbacks.remove(id)) return error.NoSuchCallback;
        }

        pub const __lua = .ref;
    };
}
