// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const util = @import("util.zig");
const recipes = @import("recipes.zig");
const Binding = @import("Binding.zig").Binding;
const Lua = zlua.Lua;

pub fn module(l: *Lua, comptime recipe: recipes.LuaModuleRecipe) void {
    _ = l.pushStringZ(recipe.name);
    l.setField(-2, "__name");

    // index
    l.newTable();
    inline for (recipe.functions) |f| {
        f.push(l);
        l.setField(-2, f.name);
    }

    // these technically aren't "methods", but whatever
    l.setField(-2, "__methods");

    // these are used in every `.value()`/`.reference()`/`.module()` function,
    // should probably be turned into a reusable function between them all
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

    const metatable_idx = l.getTop();

    l.newTable();
    l.pushValue(metatable_idx);
    l.setMetatable(-2);
    l.remove(metatable_idx);

    util.registerTopLevelModule(l, recipe.name);
}