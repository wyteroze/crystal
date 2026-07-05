// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const log = @import("../../log.zig").lua;
const Lua = zlua.Lua;

pub fn LuaSignal(comptime Args: type, comptime Filter: type) type {
    return struct {
        const Self = @This();
        pub const has_filter = Filter != void;
        pub const FilterArg = if (has_filter) ?Filter else void;

        pub const Connection = struct {
            lua: *Lua,
            ref: i32,
            filter: FilterArg,
            disconnected: bool = false,

            // Calls le connection if not disconnected
            // pushArgs: pushes call arguments and returns number of args pushed
            pub fn call(
                self: *Connection,
                args: Args,
                comptime pushArgs: fn (*Lua, Args) i32,
                comptime err_ctx: []const u8
            ) void {
                if (self.disconnected) return;
                const l = self.lua;

                _ = l.getIndexRaw(zlua.registry_index, self.ref);
                const n_args = pushArgs(l, args);
                l.protectedCall(.{ .args = n_args, .results = 0 }) catch {
                    log.err(err_ctx ++ " callback errror: {s}", .{ l.toString(-1) catch "???" });
                    l.pop(1);
                };
            }

            // Disconnects le signal
            pub fn disconnect(self: *Connection, l: *Lua) void {
                if (self.disconnected) return;

                self.disconnected = true;
                l.unref(zlua.registry_index, self.ref);
            }
        };

        allocator: std.mem.Allocator,
        connections: std.ArrayList(*Connection) = .empty,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self, l: *Lua) void {
            for (self.connections.items) |c| {
                c.disconnect(l);
                self.allocator.destroy(c);
            }

            self.connections.deinit(self.allocator);
        }

        // Connects function at idx and pushes a disconnect function
        pub fn connect(self: *Self, l: *Lua, idx: i32, filter: FilterArg) i32 {
            l.checkType(idx, .function);
            l.pushValue(idx);
            const ref = l.ref(zlua.registry_index);

            const c = self.allocator.create(Connection) catch {
                l.unref(zlua.registry_index, ref);
                l.raiseErrorStr("out of memory creating signal", .{});
                return 0;
            };
            c.* = .{ .lua = l, .ref = ref, .filter = filter };

            self.connections.append(self.allocator, c) catch {
                l.unref(zlua.registry_index, ref);
                self.allocator.destroy(c);

                l.raiseErrorStr("out of memory creating signal", .{});
                return 0;
            };

            l.pushLightUserdata(c);
            l.pushClosure(zlua.wrap(disconnect), 1);
            return 1;
        }

        fn disconnect(l: *Lua) i32 {
            const c = @as(*Connection, @ptrCast(@alignCast(
                l.toUserdata(anyopaque, Lua.upvalueIndex(1)) catch unreachable
            )));
            c.disconnect(l);

            return 1;
        }

        pub fn fire(
            self: *Self,
            args: Args,
            filter_value: if (has_filter) Filter else void,
            comptime pushArgs: fn (*Lua, Args) i32,
            comptime err_ctx: []const u8
        ) void {
            for (self.connections.items) |c| {
                if (comptime has_filter) {
                    if (c.filter) |f| {
                        if (f != filter_value) continue;
                    }
                }

                c.call(args, pushArgs, err_ctx);
            }
        }
    };
}
