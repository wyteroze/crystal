// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const Connection = struct {
    signal: *anyopaque,
    id: usize,
    disconnect_fn: *const fn (signal: *anyopaque, id: usize) anyerror!void,

    pub fn disconnect(self: Connection) void {
        self.disconnect_fn(self.signal, self.id) catch |e| {
            std.log.err("Failed to disconnect callback: {s}", .{ @errorName(e) });
        };
    }
};

pub const Dispatcher = struct {
    const FlushFn = *const fn (*anyopaque) void;
    const DropFn = *const fn (*anyopaque) void;
    const Pending = struct {
        signal: *anyopaque,
        flush_fn: FlushFn,
        drop_fn: DropFn
    };

    allocator: std.mem.Allocator,
    queue: std.ArrayList(Pending),
    draining: std.ArrayList(Pending),

    pub fn init(allocator: std.mem.Allocator) Dispatcher {
        return .{ .allocator = allocator, .queue = .empty, .draining = .empty };
    }

    pub fn deinit(self: *Dispatcher) void {
        for (self.queue.items) |p| p.drop_fn(p.signal);
        self.queue.deinit(self.allocator);
        self.draining.deinit(self.allocator);
    }
    
    pub fn flush(self: *Dispatcher) void {
        std.mem.swap(std.ArrayList(Pending), &self.queue, &self.draining);
        for (self.draining.items) |p| p.flush_fn(p.signal);

        self.draining.clearRetainingCapacity();
    }

    fn enqueue(self: *Dispatcher, signal: *anyopaque, flush_fn: *const fn (*anyopaque) void, drop_fn: *const fn (*anyopaque) void) !void {
        try self.queue.append(self.allocator, .{ .signal = signal, .flush_fn = flush_fn, .drop_fn = drop_fn });
    }

    fn forget(self: *Dispatcher, signal: *anyopaque) void {
        for (self.queue.items, 0..) |p, i| if (p.signal == signal) {
            _ = self.queue.orderedRemove(i);
            return;
        };
    }
};

pub fn Signal(comptime ArgTypes: anytype) type {
    return struct {
        const Self = @This();

        pub const Args = @Tuple(&ArgTypes);
        pub const Dtor = *const fn (allocator: std.mem.Allocator, ctx: *anyopaque) void;
        pub const Callback = struct {
            id: usize,
            func: *const fn (*anyopaque, Args) void,
            ctx: *anyopaque,
            dtor: ?Dtor = null,
            active: bool = true
        };

        allocator: std.mem.Allocator,
        dispatcher: *Dispatcher,
        callbacks: std.ArrayList(Callback),
        pending: std.ArrayList(Args),
        draining: std.ArrayList(Args),
        next_id: usize = 0,
        queued: bool = false,
        dispatching: bool = false,
        needs_compact: bool = false,
        retired: bool = false,

        pub fn init(allocator: std.mem.Allocator, dispatcher: *Dispatcher) Self {
            return .{
                .allocator = allocator,
                .dispatcher = dispatcher,
                .callbacks = .empty,
                .pending = .empty,
                .draining = .empty
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.queued) self.dispatcher.forget(self);
            for (self.callbacks.items) |cb| if (cb.active) if (cb.dtor) |d| d(self.allocator, cb.ctx);
            self.callbacks.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.draining.deinit(self.allocator);
        }

        pub fn create(allocator: std.mem.Allocator, dispatcher: *Dispatcher) !*Self {
            const s = try allocator.create(Self);
            s.* = .init(allocator, dispatcher);

            return s;
        }

        pub fn destroy(self: *Self) void {
            const a = self.allocator;
            self.deinit();
            a.destroy(self);
        }

        pub fn retire(self: *Self) void {
            self.retired = true;
            if (!self.queued and !self.dispatching) self.destroy();
        }

        pub fn fire(self: *Self, args: Args) void {
            if (self.callbacks.items.len == 0) return;

            self.pending.append(self.allocator, args) catch {
                std.log.err("Signal queue out of memory, dropping event", .{});
                return;
            };

            if (self.queued) return;
            self.dispatcher.enqueue(self, flushErased, dropErased) catch {
                _ = self.pending.pop();
                std.log.err("Signal queue out of memory, dropping event", .{});
                return;
            };
            self.queued = true;
        }

        pub fn connect(self: *Self, comptime func: anytype, ctx: anytype) !Connection {
            const Ctx = @TypeOf(ctx);
            const wrapped = struct {
                fn c(ctx_ptr: *anyopaque, args: Args) void {
                    const ctx_typed: Ctx = @ptrCast(@alignCast(ctx_ptr));
                    @call(.auto, func, .{ ctx_typed } ++ args);
                }
            }.c;

            return self.add(wrapped, ctx, null);
        }

        pub fn rawConnect(self: *Self, comptime func: anytype, ctx: anytype, dtor: ?Dtor) !Connection {
            const Ctx = @TypeOf(ctx);
            const FuncInfo = @typeInfo(@TypeOf(func)).@"fn";
            if (FuncInfo.param_types.len != 2 or FuncInfo.param_types[1].? != Args) {
                @compileError("rawConnect callback must be fn (Ctx, " ++ @typeName(Args) ++ ") void");
            }

            const wrapped = struct {
                fn c(ctx_ptr: *anyopaque, args: Args) void {
                    const typed_ctx: Ctx = @ptrCast(@alignCast(ctx_ptr));
                    func(typed_ctx, args);
                }
            }.c;

            return self.add(wrapped, ctx, dtor);
        }

        pub fn disconnect(self: *Self, id: usize) !void {
            for (self.callbacks.items, 0..) |*cb, i| {
                if (cb.id != id or !cb.active) continue;
                if (cb.dtor) |d| d(self.allocator, cb.ctx);

                if (self.dispatching) {
                    cb.active = false;
                    self.needs_compact = true;
                } else {
                    _ = self.callbacks.orderedRemove(i);
                }
                return;
            }

            return error.NoSuchCallback;
        }

        fn add(self: *Self, func: *const fn (*anyopaque, Args) void, ctx: *anyopaque, dtor: ?Dtor) !Connection {
            const id = self.next_id;
            self.next_id += 1;

            try self.callbacks.append(self.allocator, .{ .id = id, .func = func, .ctx = ctx, .dtor = dtor });
            return .{ .signal = self, .id = id, .disconnect_fn = disconnectErased };
        }

        fn disconnectErased(ptr: *anyopaque, id: usize) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.disconnect(id);
        }

        fn flushErased(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.flush();
        }

        fn dropErased(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (self.retired) self.destroy();
        }

        fn flush(self: *Self) void {
            self.queued = false;
            std.mem.swap(std.ArrayList(Args), &self.pending, &self.draining);
            self.dispatching = true;

            for (self.draining.items) |args| {
                // Callbacks connected while dispatching are picked up by the next event, and disconnected ones are tombstoned
                const n = self.callbacks.items.len;
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    const cb = self.callbacks.items[i];
                    if (cb.active) cb.func(cb.ctx, args);
                }
            }

            self.draining.clearRetainingCapacity();
            self.dispatching = false;

            if (self.needs_compact) {
                var w: usize = 0;
                for (self.callbacks.items) |cb| if (cb.active) {
                    self.callbacks.items[w] = cb;
                    w += 1;
                };
                self.callbacks.shrinkRetainingCapacity(w);
                self.needs_compact = false;
            }

            if (self.retired) self.destroy();
        }
    };
}
