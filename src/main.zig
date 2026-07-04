// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl = @import("zsdl2");
const zlua = @import("zlua");

const types         = @import("types.zig");
const log           = @import("log.zig").engine;
const Platform      = @import("Platform.zig").Platform;
const Renderer      = @import("Renderer.zig").Renderer;
const Mesh          = @import("Mesh.zig").Mesh;
const Sprite        = @import("Sprite.zig").Sprite;
const Camera        = @import("Camera.zig").Camera;
const Object        = @import("object.zig").Object;
const ScriptEngine  = @import("script/ScriptEngine.zig").ScriptEngine;
const SceneRegistry = @import("SceneRegistry.zig").SceneRegistry;

const fps = 120;
const fps_ms = 1000 / fps;
const width = 384;
const height = 360;

// You can customize this to filter what types of logs
// are actually seen in the output
pub const std_options: std.Options = .{
    // Default log level
    .log_level = .debug,

    // Filters for scopes
    .log_scope_levels = &.{
        .{ .scope = .script, .level = .debug },
        .{ .scope = .render, .level = .debug },
        .{ .scope = .parse, .level = .debug },
        .{ .scope = .engine, .level = .debug }
    }
};

fn isPressed(state: []const u8, scancode: sdl.Scancode) bool {
    return state[@intFromEnum(scancode)] != 0;
}

pub fn main(init: std.process.Init) !void {
    log.info("Initializing...", .{});
    const allocator = init.gpa;
    const io = init.io;

    var platform = try Platform.init();
    defer platform.deinit();

    var window = try platform.createWindow("kebab", .centered, .{ .x = width*2, .y = height*2 });
    defer window.destroy();

    var renderer = try Renderer.init(allocator, window, .{ .x = width, .y = height }, true);
    defer renderer.deinit();

    var sceneRegistry = SceneRegistry.init(allocator);
    var scriptEngine = try ScriptEngine.init(allocator, io, &sceneRegistry);
    defer sceneRegistry.deinit();
    defer scriptEngine.deinit();

    scriptEngine.runFile("src/assets/scripts/main.lua");
    log.info("Initialized", .{});

    var running = true;
    var lastTimeMs: u64 = sdl.getPerformanceCounter();
    const frequency = @as(f32, @floatFromInt(sdl.getPerformanceFrequency()));

    log.info("Starting loop", .{});
    while (running) {
        const currentTime = sdl.getPerformanceCounter();
        const dt = @as(f32, @floatFromInt(currentTime - lastTimeMs)) / frequency;
        lastTimeMs = currentTime;

        // events
        var event: sdl.Event = undefined;
        while (sdl.pollEvent(&event)) {
            switch (event.type) {
                .quit => running = false,
                else => {}
            }
        }

        // rendering
        renderer.drawBackground();

        const scene = sceneRegistry.current_scene;
        if (scene) |s| {
            s.update(dt);
            try renderer.drawScene(s);
        }

        try renderer.present();
    }
}
