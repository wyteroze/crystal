// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const log = @import("../log.zig").script;
const libs = @import("libs/libs.zig");
const objects = @import("objects/objects.zig");
const reflect = @import("reflect/reflect.zig");

const SceneRegistry = @import("../engine/SceneRegistry.zig").SceneRegistry;
const WidgetRegistry = @import("../engine/WidgetRegistry.zig").WidgetRegistry;
const AudioEngine = @import("../audio/AudioEngine.zig").AudioEngine;
const ColorRegistry = @import("../engine/ColorRegistry.zig").ColorRegistry;
const WindowManager = @import("../engine/WindowManager.zig").WindowManager;
const Platform = @import("../engine/Platform.zig").Platform;
const Engine = @import("../engine/Engine.zig").Engine;

pub const ScriptEngine = struct {
    lua: *Lua,
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        sceneRegistry: *SceneRegistry,
        platform: *Platform,
        audioEngine: *AudioEngine,
        windowManager: *WindowManager,
        colorRegistry: *ColorRegistry,
        engine: *Engine,
    ) !ScriptEngine {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);

        reflect.marshal.allocator = allocator;
        reflect.marshal.ref_allocator = arena.allocator();

        var lua = try Lua.init(allocator);
        lua.openLibs();

        try reflect.registerAllLibs(lua, libs, .{ allocator, io, sceneRegistry, platform, audioEngine, windowManager, colorRegistry, engine });
        try reflect.registerAllObjects(lua, objects);

        // load core systems
        lua.doFile("src/assets/scripts/core/core.lua") catch {
            log.err("failed to load core.lua: '{s}'", .{ lua.toString(-1) catch "unknown error" });
        };

        return .{ .lua = lua, .arena = arena, .allocator = allocator };
    }

    // Runs a script from the given path. Handles all errors
    pub fn runFile(self: *ScriptEngine, file: [:0]const u8) void {
        log.info("loading script '{s}'", .{file});

        self.lua.doFile(file) catch {
            const msg = self.lua.toString(-1) catch "unknown error";
            var formatted = false;

            // find the ": "
            if (std.mem.indexOf(u8, msg, ": ")) |msg_sep| {
                // search backwards in order to find the separator of file and line
                if (std.mem.findScalarLast(u8, msg[0..msg_sep], ':')) |line_sep| {
                    const filename = msg[0..line_sep];
                    const line = msg[line_sep+1 .. msg_sep];
                    const err_msg = msg[msg_sep + 2 ..]; // skip ":"

                    log.err("{s}\n    in {s} (line {s})", .{ err_msg, filename, line });
                    formatted = true;
                }
            }

            if (!formatted) {
                log.err("{s}", .{ msg });
            }

            self.lua.pop(1);
        };
    }

    pub fn deinit(self: *ScriptEngine) void {
        self.arena.deinit();
        self.allocator.destroy(self.arena);
        self.lua.deinit();
    }
};
