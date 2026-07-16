// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const zlua = @import("zlua");

const types         = @import("types.zig");
const log           = @import("log.zig").engine;
const Platform      = @import("Platform.zig").Platform;
const Renderer      = @import("Renderer.zig").Renderer;
const MeshData      = @import("MeshData.zig").MeshData;
const ImageData     = @import("ImageData.zig").ImageData;
const Camera        = @import("Camera.zig").Camera;
const Object        = @import("object.zig").Object;
const ScriptEngine  = @import("script/ScriptEngine.zig").ScriptEngine;
const SceneRegistry = @import("SceneRegistry.zig").SceneRegistry;
const InputLib      = @import("script/libs/InputLib.zig");
const AudioEngine   = @import("audio/AudioEngine.zig").AudioEngine;
const Config        = @import("Config.zig").Config;
const scene         = @import("Scene.zig");

const config_path = "config.toml";

// You can customize this to filter what types of logs
// are actually seen in the output
pub const std_options: std.Options = .{
    // Default log level
    .log_level = .info,

    // Filters for scopes
    .log_scope_levels = &.{
        .{ .scope = .script, .level = .info },
        .{ .scope = .render, .level = .info },
        .{ .scope = .parse, .level = .info },
        .{ .scope = .engine, .level = .info }
    }
};

fn isPressed(state: []const u8, scancode: sdl3.Scancode) bool {
    return state[@intFromEnum(scancode)] != 0;
}

pub fn main(init: std.process.Init) !void {
    log.info("Initializing...", .{});
    const allocator = init.gpa;
    const io = init.io;

    const config = try Config.load(allocator, io, config_path);

    // SceneRegistry automatically handles deinitializing of skybox mesh
    scene.skybox_mesh = try MeshData.loadFromFile(allocator, io, "src/assets/models/skybox.obj");

    var platform = try Platform.init();
    defer platform.deinit();

    var window = try platform.createWindow("kebab", .{ .centered = null }, .{ .centered = null }, .{ .x = config.width*2, .y = config.height*2 });
    defer window.deinit();

    var renderer = try Renderer.init(allocator, window, .{ .x = config.width, .y = config.height });
    defer renderer.deinit();

    var audioEngine = try AudioEngine.init(allocator);
    defer audioEngine.deinit();

    var sceneRegistry = SceneRegistry.init(allocator);
    var scriptEngine = try ScriptEngine.init(allocator, io, &sceneRegistry, window, &audioEngine);
    defer scriptEngine.deinit();
    defer sceneRegistry.deinit();

    scriptEngine.runFile("src/assets/scripts/main.lua");
    log.info("Initialized", .{});

    var running = true;
    var lastTimeMs: u64 = sdl3.timer.getPerformanceCounter();
    const frequency = @as(f32, @floatFromInt(sdl3.timer.getPerformanceFrequency()));

    log.info("Starting loop", .{});
    while (running) {
        const currentTime = sdl3.timer.getPerformanceCounter();
        const dt = @as(f32, @floatFromInt(currentTime - lastTimeMs)) / frequency;
        lastTimeMs = currentTime;

        // events
        while (sdl3.events.poll()) |e| {
            switch (e) {
                .quit => running = false,

                else => if (InputLib.current) |c| c.dispatch(e)
            }
        }

        // rendering
        renderer.drawBackground();

        const current_scene = sceneRegistry.current_scene;
        if (current_scene) |s| {
            s.update(dt);

            try audioEngine.tick(s);
            try renderer.drawScene(s);
        }

        try renderer.present();

        // frame limiter
        const fps_ms = config.fps / 1000;
        const frameTime = sdl3.timer.getPerformanceCounter() - currentTime;
        const frameTimeMs = (frameTime * 1000) / @as(u64, @intFromFloat(frequency));
        if (frameTimeMs < fps_ms) {
            sdl3.timer.delayMilliseconds(@intCast(fps_ms - frameTimeMs));
        }
    }
}
