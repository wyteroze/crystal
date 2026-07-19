// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const zlua = @import("zlua");

const types         = @import("types.zig");
const log           = @import("log.zig").engine;
const Platform      = @import("Platform.zig").Platform;
const Renderer      = @import("render/Renderer.zig").Renderer;
const RenderTarget  = @import("render/RenderTarget.zig").RenderTarget;
const UIPainter     = @import("render/UIPainter.zig");
const MeshData      = @import("MeshData.zig").MeshData;
const ImageData     = @import("ImageData.zig").ImageData;
const Camera        = @import("Camera.zig").Camera;
const Object        = @import("object.zig").Object;
const ScriptEngine  = @import("script/ScriptEngine.zig").ScriptEngine;
const SceneRegistry = @import("SceneRegistry.zig").SceneRegistry;
const WidgetRegistry= @import("WidgetRegistry.zig").WidgetRegistry;
const ColorRegistry = @import("ColorRegistry.zig").ColorRegistry;
const ThreadRegistry= @import("ThreadRegistry.zig").ThreadRegistry;
const WindowManager = @import("WindowManager.zig").WindowManager;
const AudioEngine   = @import("audio/AudioEngine.zig").AudioEngine;
const Config        = @import("Config.zig").Config;
const Color         = @import("Color.zig").Color;
const Font          = @import("ui/Font.zig").Font;
const Widget        = @import("ui/Widget.zig").Widget;
const Engine        = @import("engine/Engine.zig").Engine;
const widget        = @import("ui/Widget.zig");
const scene         = @import("Scene.zig");
const perf          = @import("profile/perf.zig");

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

pub fn main(init: std.process.Init) !void {
    log.info("Initializing...", .{});
    const allocator = init.gpa;
    const io = init.io;

    var engine: Engine = undefined;
    try engine.init(allocator, io);
    defer engine.deinit();

    var threadRegistry = ThreadRegistry.init(io);
    defer threadRegistry.deinit();

    perf.registry = &threadRegistry;
    perf.frequency = sdl3.timer.getPerformanceFrequency();
    perf.enabled = true;

    const config = try Config.load(allocator, io, config_path);

    // SceneRegistry automatically handles deinitializing of skybox mesh
    scene.skybox_mesh = try MeshData.loadFromFile(allocator, io, "src/assets/models/skybox.obj");

    var platform = try Platform.init();
    defer platform.deinit();

    var windowManager = WindowManager.init(allocator, &platform, &engine);

    var renderer = try Renderer.init(allocator);
    defer renderer.deinit();

    var audioEngine = try AudioEngine.init(allocator);
    defer audioEngine.deinit();

    var widgetRegistry = WidgetRegistry.init(allocator);
    var sceneRegistry = SceneRegistry.init(allocator);
    var colorRegistry = try ColorRegistry.init(allocator, io);
    Color.registry = &colorRegistry;

    var scriptEngine = try ScriptEngine.init(allocator, io, &sceneRegistry, &platform, &audioEngine, &windowManager, &colorRegistry, &engine);
    defer scriptEngine.deinit();

    // Deinit these first, their lua callbacks need to be unrefed while lua is still alive.
    defer windowManager.deinit();
    defer widgetRegistry.deinit();
    defer sceneRegistry.deinit();
    defer colorRegistry.deinit();

    scriptEngine.runFile("src/assets/scripts/main.lua");
    log.info("Initialized", .{});

    var lastTimeMs: u64 = sdl3.timer.getPerformanceCounter();
    const frequency = @as(f32, @floatFromInt(sdl3.timer.getPerformanceFrequency()));

    const font = try Font.loadFromFile(allocator, io, "src/assets/fonts/ProggyClean/");
    defer font.deinit();

    const fps_ns: f32 = 1_000_000_000.0 / @as(f32, @floatFromInt(config.fps));

    log.info("Starting loop", .{});
    while (engine.running) {
        const currentTime = sdl3.timer.getPerformanceCounter();
        const dt = @as(f32, @floatFromInt(currentTime - lastTimeMs)) / frequency;
        lastTimeMs = currentTime;

        engine.preStep();

        try perf.beginFrame("main"); {
            // events
            perf.start("events"); {
                var want_quit: bool = false;
                while (sdl3.events.poll()) |e| {
                    if (!windowManager.handleEvent(e)) {
                        want_quit = true;
                        break;
                    }
                }

                if (want_quit) break;
            } perf.stop();

            // render scene
            perf.start("scenes"); {
                var cam: *Camera = renderer.pipeline.default_camera;
                if (windowManager.focused) |f| if (f.camera) |f_cam| switch (f_cam.data) {
                    .camera => |c| cam = c.camera,
                    else => {},
                };

                for (sceneRegistry.scenes.items) |s| {
                    perf.start("update"); { s.update(dt); } perf.stop();
                    perf.start("audio"); { try audioEngine.tick(s, cam); } perf.stop();
                }
            } perf.stop();

            perf.start("windows"); {
                for (windowManager.windows.items) |w| {
                    w.update(dt);
                }
            } perf.stop();

            // submit
            perf.start("render"); {
                try windowManager.renderAll(&renderer, font);
            } perf.stop();
        } perf.endFrame();

        const frameTime = sdl3.timer.getPerformanceCounter() - currentTime;
        const frameTimeNs: f32 = @as(f32, @floatFromInt(frameTime)) * 1_000_000_000.0 / frequency;

        // fill out engine info for this frame
        engine.frame += 1;
        engine.fps = 1.0 / (@as(f32, @floatFromInt(frameTime)) / frequency);

        engine.postStep();

        // frame limiter
        if (frameTimeNs < fps_ns) {
            sdl3.timer.delayNanosecondsPrecise(@intFromFloat(fps_ns - frameTimeNs));
        }
    }

    const close_reason = if (engine.close_reason) |cr| @tagName(cr) else null;
    log.info("Engine closing (reason: {?s})", .{ close_reason });
}
