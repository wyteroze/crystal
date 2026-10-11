// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const util = @import("util.zig");
const types = @import("types.zig");
const names = @import("names.zig");
const recipes = @import("recipes.zig");
const Host = @import("Host.zig");
pub const Registry = @import("registry.zig").Registry;
pub const Marshal = @import("marshal.zig").Marshal;
pub const Wrap = @import("wrap.zig").Wrap;

const InstanceEntry = union(enum) {
    field: struct { zig: []const u8, lua: [:0]const u8 },
    prop: types.Member,
    method: types.Member,
};


fn entryName(comptime e: InstanceEntry) []const u8 {
    return switch (e) { .field => |f| f.lua, .prop => |p| p.name, .method => |m| m.name };
}

fn instanceEntries(comptime r: recipes.ValueRecipe) []const InstanceEntry {
    comptime {
        var out: []const InstanceEntry = &.{};
        for (r.fields) |f| out = out ++ &[_]InstanceEntry{ .{ .field = .{ .zig = f, .lua = names.pascal(f) } } };
        for (r.props) |p| out = out ++ &[_]InstanceEntry{ .{ .prop = p } };
        for (r.methods) |m| out = out ++ &[_]InstanceEntry{ .{ .method = m } };
        return out;
    }
}

pub fn Binder(comptime api: anytype) type {
    const R = Registry(api);
    const M = Marshal(R);
    const W = Wrap(M);

    return struct {
        const Self = @This();
        l: *zlua.Lua,
        host: *Host,

        pub fn init(l: *zlua.Lua, host: *Host) Self {
            host.attach(l);
            return .{ .l = l, .host = host };
        }

        pub fn install(self: *Self) void {
            const l = self.l;
            const base = l.getTop();
            defer std.debug.assert(l.getTop() == base);

            inline for (R.entries) |e| switch (e.member.kind) {
                .value => installValueMeta(l, e.T, e.member.impl.recipe),
                else => {}
            };

            inline for (api) |entry| if (entry.kind == .globals) {
                l.pushGlobalTable();
                fillTable(l, entry.impl.recipe.members);
                l.pop(1);
            };

            l.newTable();
            inline for (api) |entry| if (entry.kind == .module) {
                l.newTable();
                fillTable(l, entry.impl.recipe.members);
                l.setReadonly(-1, true);

                // Builtin modules in Luau are prefixed by the @ symbol.
                l.setField(-2, "@" ++ entry.name);
            };
            l.setReadonly(-1, true);

            l.pushClosure(zlua.wrap(require), 1, "require");
            l.setGlobal("require");
        }

        pub fn pushValue(self: *Self, val: anytype) void {
            M.push(self.l, val);
        }

        pub fn parseValue(self: *Self, comptime T: type, idx: i32) *T {
            M.parse(T, self.l, idx);
        }

        fn loader(comptime mod: types.Member) fn (*zlua.Lua) i32 {
            return struct {
                fn c(l: *zlua.Lua) i32 {
                    l.newTable();
                    inline for (mod.impl.recipe.members) |m| switch (m.kind) {
                        .func => { l.pushFunction(W.cFn(m.impl.function, .{}), m.name); l.setField(-2, m.name); },
                        .constant => { M.push(l, m.impl.val); l.setField(-2, m.name); },
                        .value => { pushTypeTable(l, m); l.setField(-2, m.name); },
                        else => {},
                    };
                    l.setReadonly(-1, true);

                    return 1;
                }
            }.c;
        }

        fn buildModule(l: *zlua.Lua, comptime mod: types.Member) void {
            l.newTable();
            fillTable(l, mod);
        }

        fn fillTable(l: *zlua.Lua, comptime members: []const types.Member) void {
            const top = l.getTop();
            // Table to fill should be at top of stack
            inline for (members) |m| {
                switch (m.kind) {
                    .func => { l.pushFunction(W.cFn(m.impl.function, .{}), m.name); l.setField(-2, m.name); },
                    .constant => { M.push(l, m.impl.val); l.setField(-2, m.name); },
                    .value => { pushTypeTable(l, m); l.setField(-2, m.name); },

                    else => @compileError(std.fmt.comptimePrint("Type not allowed here: {s}", .{ m.name })),
                }

                std.debug.assert(l.getTop() == top);
            }
        }

        fn require(l: *zlua.Lua) i32 {
            const name = l.checkString(1);
            
            const loaded = zlua.Lua.upvalueIndex(1);
            if (l.getField(loaded, name) == .nil) {
                l.raiseErrorStr("module '%s' not found", .{name.ptr});
            }
            
            return 1;
        }

        fn pushTypeTable(l: *zlua.Lua, comptime m: types.Member) void {
            l.newTable();
            inline for (m.impl.recipe.statics) |s| {
                switch (s.kind) {
                    .func => l.pushFunction(W.cFn(s.impl.function, .{}), m.name),
                    .constant => M.push(l, s.impl.val),
                    else => @compileError("statics may only be functions or constants: " ++ s.name),
                }
                l.setField(-2, s.name);
            }
            l.setReadonly(-1, true);
        }

        fn indexFn(comptime T: type, comptime E: []const InstanceEntry) zlua.CFn {
            const Map = comptime blk: {
                var kv: [E.len]struct { []const u8, u16 } = undefined;
                for (E, 0..) |e, i| kv[i] = .{ entryName(e), i };
                
                break :blk std.StaticStringMap(u16).initComptime(kv);
            };

            return zlua.wrap(struct {
                fn f(l: *zlua.Lua) i32 {
                    const self = M.parse(T, l, 1);
                    if (l.typeOf(2) != .string) { l.pushNil(); return 1; }

                    const key = l.toString(2) catch unreachable;
                    const i = Map.get(key) orelse { l.pushNil(); return 1; };

                    switch (i) {
                        inline 0...E.len - 1 => |k| switch (E[k]) {
                            .field => |fd| { M.push(l, @field(self, fd.zig)); return 1; },
                            .prop => |p| return W.Gen(p.impl.getter, .{}).call(l),
                            .method => |m| { l.pushFunction(W.cFn(m.impl.function, .{}), m.name); return 1; },
                        },

                        else => unreachable,
                    }
                }
            }.f);
        }

        fn opFn(comptime T: type, comptime name: []const u8, comptime op: types.Op) zlua.CFn {
            switch (op) {
                .member => |m| return W.cFn(m.impl.function, .{}),
                .auto => {
                    if (comptime std.mem.eql(u8, name, "eq"))
                        return W.cFn(struct { fn f(a: T, b: T) bool { return std.meta.eql(a, b); } }.f, .{});
                    if (comptime std.mem.eql(u8, name, "tostring")) return zlua.wrap(autoToString(T));

                    @compileError("ops." ++ name ++ " = .auto is only valid for eq and tostring");
                },
            }
        }

        fn autoToString(comptime T: type) fn (*zlua.Lua) i32 {
            return struct {
                fn f(l: *zlua.Lua) i32 {
                    const self = M.parse(T, l, 1);
                    var buf: [128]u8 = undefined;
                    
                    const s = (if (@hasDecl(T, "format"))
                        std.fmt.bufPrint(&buf, "{f}", .{ self })
                    else
                        std.fmt.bufPrint(&buf, "{any}", .{ self })) catch "<too long>";
                    
                    _ = l.pushString(s);
                    return 1;
                }
            }.f;
        }

        fn installValueMeta(l: *zlua.Lua, comptime T: type, comptime r: recipes.ValueRecipe) void {
            const base = l.getTop();
            defer std.debug.assert(l.getTop() == base);
            const E = comptime instanceEntries(r);
            l.newTable();

            _ = l.pushStringZ(r.name orelse names.shortTypeName(T));
            l.setField(-2, "__type");

            if (E.len > 0) {
                l.pushFunction(indexFn(T, E), "__index");
                l.setField(-2, "__index");
            }

            inline for (@typeInfo(types.Ops).@"struct".field_names) |nm| {
                if (@field(r.ops, nm)) |op| {
                    l.pushFunction(opFn(T, nm, op), nm);
                    l.setField(-2, "__" ++ nm);
                }
            }

            l.setUserdataMetatable(R.tagOf(T));
        }
    };
}