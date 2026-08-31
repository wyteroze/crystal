// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const util = @import("util.zig");
const recipes = @import("recipes.zig");
const Binding = @import("Binding.zig").Binding;
const Lua = zlua.Lua;

pub fn reference(l: *Lua, comptime T: type, comptime recipe: recipes.LuaReferenceRecipe) void {
    const bind = Binding(T, true);
    l.newMetatable(bind.type_name) catch unreachable;

    _ = l.pushStringZ(switch (recipe.name) { .auto => util.shortTypeName(T), .named => |n| n });
    l.setField(-2, "__name");

    l.newTable();
    inline for (recipe.methods) |m| {
        m.push(l);
        l.setField(-2, m.name);
    }
    l.setField(-2, "__methods");

    if (recipe.properties != null) {
        l.pushFunction(zlua.wrap(struct {
            fn c(lua: *Lua) i32 {
                const key = lua.checkString(2);
                if (recipe.properties) |props| {
                    switch (props) {
                        .prop_fields => |flds| {
                            inline for (flds) |f| {
                                if (f.get) |getter| if (std.mem.eql(u8, key, f.name)) {
                                    getter(lua);
                                    lua.pushValue(1);
                                    lua.call(.{ .args = 1, .results = 1 });
                                    return 1;
                                };
                            }
                        },
                        .custom_fns => |fns| {
                            if (fns[0]) |getter| {
                                getter(lua);
                                lua.pushValue(1);
                                lua.pushValue(2);
                                lua.call(.{ .args = 2, .results = 1 });
                                return 1;
                            }
                        },
                        .custom_lua_fns => |lua_fns| {
                            if (lua_fns[0]) |lua_getter| {
                                return lua_getter(lua);
                            }
                        }
                    }
                }
                lua.getMetatable(1) catch return 0;
                l.getField(-1, "__methods");
                l.pushValue(2);
                _ = l.getTable(-2);

                return 1;
            }
        }.c));
        l.setField(-2, "__index");

        l.pushFunction(zlua.wrap(struct {
            fn c(lua: *Lua) i32 {
                const key = lua.checkString(2);
                if (recipe.properties) |props| {
                    switch (props) {
                        .prop_fields => |flds| {
                            inline for (flds) |f| {
                                if (f.set) |setter| if (std.mem.eql(u8, key, f.name)) {
                                    setter(lua);
                                    lua.pushValue(1);
                                    lua.pushValue(3);
                                    lua.call(.{ .args = 2, .results = 0 });
                                    return 0;
                                };

                                lua.raiseErrorStr("attempt to set read-only property '%s'", .{ key.ptr });
                            }
                        },
                        .custom_fns => |fns| {
                            if (fns[1]) |setter| {
                                setter(lua);
                                lua.pushValue(1);
                                lua.pushValue(2);
                                lua.pushValue(3);
                                lua.call(.{ .args = 3, .results = 0 });
                                return 0;
                            }
                            lua.raiseErrorStr("attempt to set read-only property '%s'", .{ key.ptr });
                        },
                        .custom_lua_fns => |lua_fns| {
                            if (lua_fns[1]) |lua_setter| {
                                return lua_setter(lua);
                            }
                            lua.raiseErrorStr("attempt to set read-only property '%s'", .{ key.ptr });
                        }
                    }
                }

                lua.raiseErrorStr("attempt to set unknown field '%s'", .{ key.ptr });
            }
        }.c));
        l.setField(-2, "__newindex");
    } else {
        _ = l.getField(-1, "__methods");
        l.setField(-2, "__index");
    }

    switch (recipe.eq) {
        .identity => {
            l.pushFunction(zlua.wrap(util.identityEq(bind)));
            l.setField(-2, "__eq");
        },
        .custom_fn => |func| {
            func(l);
            l.setField(-2, "__eq");
        }
    }
    switch (recipe.tostring) {
        .identity => {
            l.pushFunction(zlua.wrap(util.identityToString(bind)));
            l.setField(-2, "__tostring");
        },
        .custom_fn => |func| {
            func(l);
            l.setField(-2, "__tostring");
        }
    }
    
    if (recipe.gc) |gc| {
        gc.push(l);
        l.setField(-2, "__gc");
    }

    l.pop(1);

    l.newTable();
    inline for (recipe.constructors) |m| {
        m.push(l);
        l.setField(-2, m.name);
    }
    switch (recipe.scope) {
        .global => l.setGlobal(switch (recipe.name) { .auto => util.shortTypeName(T), .named => |nm| nm }),
        .module => |mod_name| util.moduleRegister(l, mod_name, switch (recipe.name) { .auto => util.shortTypeName(T), .named => |nm| nm }),
        .top_level_module => util.registerTopLevelModule(l, switch (recipe.name) { .auto => util.shortTypeName(T), .named => |nm| nm})
    }
}
