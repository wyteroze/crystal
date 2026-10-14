// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const util = @import("util.zig");
const types = @import("types.zig");
const names = @import("names.zig");
const recipes = @import("recipes.zig");
const Host = @import("Host.zig");
const ecs = @import("../../ecs/ecs.zig");
const Codec = ecs.Codec;
pub const registry = @import("registry.zig");
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

fn isGetter(comptime m: types.Member) bool { return m.kind == .prop or m.kind == .signal; }

fn instanceEntries(comptime r: anytype) []const InstanceEntry { comptime {
    var out: []const InstanceEntry = &.{};
    const T = @TypeOf(r);

    if (@hasField(T, "fields")) { for (r.fields) |f| out = out ++ .{ InstanceEntry{ .field = .{ .zig = f, .lua = names.pascal(f) } } }; }
    if (@hasField(T, "props")) { for (r.props) |p| out = out ++ .{ InstanceEntry{ .prop = p } }; }
    if (@hasField(T, "methods")) { for (r.methods) |m| out = out ++ .{ InstanceEntry{ .method = m } }; }
    if (@hasField(T, "signals")) { for (r.signals) |s| out = out ++ .{ InstanceEntry{ .prop = s } }; }

    return out;
} }

pub fn Binder(comptime api: anytype) type {
    const R = registry.Registry(api);
    const M = Marshal(R);
    const W = Wrap(M);

    return struct {
        const Self = @This();
        l: *zlua.Lua,
        host: *Host,

        const codecs: []const Codec = blk: {
            var out: []const Codec = &.{};
            for (R.entries) |e| switch (e.member.kind) {
                .value, .handle, .record => out = out ++ .{ codecFor(e) },
                else => {}
            };

            break :blk out;
        };

        pub fn init(l: *zlua.Lua, host: *Host) Self {
            host.attach(l);
            host.codecs = codecs;

            return .{ .l = l, .host = host };
        }

        pub fn install(self: *Self) void {
            const l = self.l;
            const base = l.getTop();
            defer std.debug.assert(l.getTop() == base);

            inline for (R.entries) |e| switch (e.member.kind) {
                .value => installValueMeta(l, e.T, e.member.impl.recipe),
                .handle => installHandleMeta(l, e.T, e.member.impl.recipe),
                else => {}
            };

            // globals
            inline for (api) |entry| if (entry.kind == .globals) {
                l.pushGlobalTable();
                std.log.debug("---- Registered {d} globals:", .{ entry.impl.recipe.members.len });
                fillTable(l, entry.impl.recipe.members, false);
                std.log.debug("---- Globals done", .{});

                l.pop(1);
            };

            // modules (build require table)
            l.newTable();
            inline for (api) |entry| if (entry.kind == .module) {
                l.newTable();
                std.log.debug("---- Registered module '{s}' with entries:", .{ entry.name });
                fillTable(l, entry.impl.recipe.members, true);
                installModuleProps(l, entry.impl.recipe.members);
                std.log.debug("---- Module entries done", .{});
                l.setReadonly(-1, true);

                // Builtin modules in Luau are prefixed by the @ symbol.
                l.setField(-2, "@" ++ entry.name);
            };
            l.setReadonly(-1, true);

            l.pushClosure(zlua.wrap(require), 1, "require");
            l.setGlobal("require");
        }

        fn codecFor(comptime e: registry.Entry) Codec {
            const T = e.T;
            const is_record = e.member.kind == .record;
            const H: ?type = if (is_record) e.member.impl.recipe.handle else null;

            return .{
                .type_name = @typeName(T),
                .size = @sizeOf(T),
                .read = struct {
                    fn f(l: *zlua.Lua, idx: i32, out: []u8) void {
                        const v = M.parse(T, l, idx);
                        @memcpy(out[0..@sizeOf(T)], std.mem.asBytes(&v));
                    }
                }.f,
                .push = struct {
                    fn f(l: *zlua.Lua, bytes: []const u8) void {
                        var v: T = undefined;
                        @memcpy(std.mem.asBytes(&v), bytes[0..@sizeOf(T)]);
                        M.push(l, v);
                    }
                }.f,
                .push_component = if (is_record) struct {
                    fn f(l: *zlua.Lua, entity: ecs.Entity, id: ecs.ComponentId, _: []const u8) void {
                        if (H) |Handle| {
                            M.push(l, Handle.fromComponent(Host.fromState(l), entity));
                        } else {
                            M.push(l, ecs.lua_components.ComponentRef{ .entity = entity, .id = id });
                        }
                    }
                }.f else null,
            };
        }

        pub fn pushValue(_: *Self, l: *zlua.Lua, val: anytype) void {
            M.push(l, val);
        }

        pub fn parseValue(_: *Self, l: *zlua.Lua, comptime T: type, idx: i32) *T {
            M.parse(T, l, idx);
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

        fn fillTable(l: *zlua.Lua, comptime members: []const types.Member, comptime allow_props: bool) void {
            const top = l.getTop();
            // Table to fill should be at top of stack
            inline for (members) |m| {
                switch (m.kind) {
                    .func => { l.pushFunction(W.cFn(m.impl.function, .{}), m.name); l.setField(-2, m.name); },
                    .constant => { M.push(l, m.impl.val); l.setField(-2, m.name); },
                    .value => { pushTypeTable(l, m); l.setField(-2, m.name); },
                    .handle, .object => if (m.impl.recipe.statics.len > 0) {
                        pushTypeTable(l, m);
                        l.setField(-2, m.name);
                    },
                    .prop => if (!allow_props)
                        @compileError("props are not allowed here: " ++ m.name),

                    .record, .variant => {},
                    else => @compileError(std.fmt.comptimePrint("Type not allowed here: {s}", .{ m.name })),
                }

                std.log.debug("{s} '{s}'", .{ @tagName(m.kind), m.name });
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
            const Map: std.StaticStringMap(u16) = comptime blk: {
                var kv: [E.len]struct { []const u8, u16 } = undefined;
                for (E, 0..) |e, i| kv[i] = .{ entryName(e), i };
                
                break :blk .initComptime(kv);
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

        fn newindexFn(comptime T: type, comptime E: []const InstanceEntry) zlua.CFn {
            const Map = comptime entryMap(E);

            return zlua.wrap(struct {
                fn f(l: *zlua.Lua) i32 {
                    if (l.typeOf(2) != .string) l.raiseErrorStr("member name must be a string", .{});

                    const key = l.toString(2) catch unreachable;
                    const i = Map.get(key) orelse l.raiseErrorStr("'%s' is not a valid member", .{ key.ptr });

                    switch (i) {
                        inline 0...E.len - 1 => |k| switch (E[k]) {
                            .field => |fd| {
                                // Needs pointer to userdata, not copy
                                const self = l.toUserdata(T, 1) catch unreachable;
                                const F = @TypeOf(@field(self.*, fd.zig));
                                @field(self.*, fd.zig) = M.parse(F, l, 3);

                                return 0;
                            },
                            .prop => |p| {
                                if (!@hasDecl(p.impl, "setter"))
                                    l.raiseErrorStr("'%s' is read-only", .{ key.ptr });

                                l.remove(2);
                                return W.Gen(p.impl.setter, .{}).call(l);
                            },
                            
                            .method => l.raiseErrorStr("'%s' is a method and cannot be assigned to", .{ key.ptr }),
                        },
                        else => unreachable,
                    }
                }
            }.f);
        }

        fn entryMap(comptime E: []const InstanceEntry) std.StaticStringMap(u16) {
            comptime {
                var kv: [E.len]struct { []const u8, u16 } = undefined;
                for (E, 0..) |e, i| kv[i] = .{ entryName(e), i };

                return .initComptime(kv);
            }
        }

        fn modulePropIndexFn(comptime members: []const types.Member) zlua.CFn {
            const props = comptime blk: {
                var out: []const types.Member = &.{};
                for (members) |m| if (isGetter(m)) { out = out ++ .{ m }; };
                break :blk out;
            };

            const Map = comptime blk: {
                var kv: [props.len]struct { []const u8, u16 } = undefined;
                for (props, 0..) |p, i| kv[i] = .{ p.name, i };

                break :blk std.StaticStringMap(u16).initComptime(kv);
            };

            return zlua.wrap(struct {
                fn f(l: *zlua.Lua) i32 {
                    if (l.typeOf(2) != .string) { l.pushNil(); return 1; }

                    const key = l.toString(2) catch unreachable;
                    const i = Map.get(key) orelse { l.pushNil(); return 1; };

                    l.setTop(0);

                    switch (i) {
                        inline 0...props.len - 1 => |k| return W.Gen(props[k].impl.getter, .{}).call(l),
                        else => unreachable,
                    }
                }
            }.f);
        }

        /// Expects the module table at the top of the stack.
        fn installModuleProps(l: *zlua.Lua, comptime members: []const types.Member) void {
            comptime var count = 0;
            inline for (members) |m| if (comptime isGetter(m)) { count += 1; };
            if (count == 0) return;

            l.newTable();
            l.pushFunction(modulePropIndexFn(members), "moduleIndexFn");
            l.setField(-2, "__index");
            l.setReadonly(-1, true);
            l.setMetatable(-2);
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
                    const allocator = l.allocator();
                    
                    const s = (if (@hasDecl(T, "format"))
                        allocator.print("{f}", .{ self })
                    else
                        allocator.print("{s}", .{ l.typeNameIndex(1) })) catch @panic("Out of memory");
                    defer allocator.free(s);
                    
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
            
            const name = r.name orelse names.shortTypeName(T);
            _ = l.pushStringZ(name);
            l.setField(-2, "__type");

            if (E.len > 0) {
                l.pushFunction(indexFn(T, E), "indexFn");
                l.setField(-2, "__index");

                l.pushFunction(newindexFn(T, E), "newindexFn");
                l.setField(-2, "__newindex");
            }

            pushOps(l, T, r);

            l.pushValue(-1);
            l.setField(zlua.registry_index, std.fmt.comptimePrint("__bind_meta_{s}", .{ @typeName(T) }));

            refMeta(l, T);
            l.setUserdataMetatable(R.tagOf(T));
            std.log.debug("Registered value '{s}'", .{ name });
        }

        fn installHandleMeta(l: *zlua.Lua, comptime T: type, comptime r: recipes.HandleRecipe) void {
            const base = l.getTop();
            defer std.debug.assert(l.getTop() == base);

            const E = comptime instanceEntries(r);
            const tag = R.tagOf(T);
            l.newTable();

            const name = r.name orelse names.shortTypeName(T);
            _ = l.pushStringZ(name);
            l.setField(-2, "__type");

            if (E.len > 0) {
                l.pushFunction(indexFn(T, E), "indexFn");
                l.setField(-2, "__index");

                l.pushFunction(newindexFn(T, E), "newindexFn");
                l.setField(-2, "__newindex");
            }

            pushOps(l, T, r);

            if (r.release) |rel| {
                l.setUserdataDtor(tag, handleDtorFn(T, rel.impl.function));
            }

            refMeta(l, T);
            l.setUserdataMetatable(tag);
            std.log.debug("Registered handle '{s}'", .{ name });
        }

        /// Refs the metatable at the top of the stack so that Lua never collects it.
        fn refMeta(l: *zlua.Lua, comptime T: type) void {
            l.pushValue(-1);
            l.setField(zlua.registry_index, "__bind_meta_" ++ @typeName(T));
        }

        fn handleDtorFn(comptime T: type, comptime func: fn (T) void) zlua.CUserdataDtorFn {
            return struct {
                fn dtorFn(_: *zlua.LuaState, userdata: *anyopaque) callconv(.c) void {
                    const h: *T = @ptrCast(@alignCast(userdata));
                    func(h.*);
                }
            }.dtorFn;
        }

        fn pushOps(l: *zlua.Lua, comptime T: type, comptime r: anytype) void {
            inline for (@typeInfo(types.Ops).@"struct".field_names) |nm| {
                if (@field(r.ops, nm)) |op| {
                    l.pushFunction(opFn(T, nm, op), nm);
                    l.setField(-2, "__" ++ nm);
                }
            }
        }
    };
}