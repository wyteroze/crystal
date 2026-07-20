// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const sdl3 = @import("sdl3");
const log = @import("../log.zig").engine;
const Callback = @import("../script/shared.zig").Callback;
const ThreadRegistry = @import("ThreadRegistry.zig").ThreadRegistry;
const Platform = @import("Platform.zig").Platform;
const WindowManager = @import("WindowManager.zig").WindowManager;
const Renderer = @import("../render/Renderer.zig").Renderer;
const AudioEngine = @import("../audio/AudioEngine.zig").AudioEngine;
const WidgetRegistry = @import("WidgetRegistry.zig").WidgetRegistry;
const SceneRegistry = @import("SceneRegistry.zig").SceneRegistry;
const ColorRegistry = @import("ColorRegistry.zig").ColorRegistry;
const ScriptEngine = @import("../script/ScriptEngine.zig").ScriptEngine;
const MemoryRegistry = @import("memory/MemoryRegistry.zig").MemoryRegistry;
const Profiler = @import("Profiler.zig").Profiler;
const Font = @import("../ui/Font.zig").Font;
const Scene = @import("../Scene.zig").Scene;
const Color = @import("../Color.zig").Color;
const perf = @import("../profile/perf.zig");

const DEFAULT_FONT_PATH = "src/assets/fonts/Oaboe/";

pub const CloseReason = enum {
    os_request,
    game_request,
    no_windows
};

pub const Engine = struct {
    io: std.Io,
    allocator: std.mem.Allocator,

    platform: Platform,
    thread_registry: ThreadRegistry,
    window_manager: WindowManager,
    renderer: Renderer,
    audio_engine: AudioEngine,
    widget_registry: WidgetRegistry,
    memory_registry: MemoryRegistry,
    scene_registry: SceneRegistry,
    color_registry: ColorRegistry,
    script_engine: ScriptEngine,
    default_font: *Font,

    target_fps: usize,
    last_time_ms: u64,
    frequency: f32,

    fps: f32 = 0,
    frame: usize = 0,
    running: bool = true,
    close_reason: ?CloseReason = null,
    pre_step_callbacks: std.ArrayList(Callback),
    post_step_callbacks: std.ArrayList(Callback),

    pub fn init(self: *Engine, allocator: std.mem.Allocator, io: std.Io) !void {
        log.info("Initializing", .{});
        var memory_registry = MemoryRegistry.init(allocator);

        self.* = .{
            .io = io,
            .allocator = allocator,
            .pre_step_callbacks = .empty,
            .post_step_callbacks =.empty,
            .thread_registry = .init(io),
            .platform = try .init(),
            .target_fps = 120,
            .window_manager = undefined,
            .renderer = try .init(try memory_registry.createCategory("Render")),
            .audio_engine = try .init(try memory_registry.createCategory("Audio engine")),
            .widget_registry = .init(try memory_registry.createCategory("Widget registry")),
            .scene_registry = .init(try memory_registry.createCategory("Scene registry")),
            .color_registry = try .init(try memory_registry.createCategory("Color registry"), io),
            .script_engine = undefined,
            .default_font = try .loadFromFile(allocator, io, DEFAULT_FONT_PATH),
            .last_time_ms = sdl3.timer.getPerformanceCounter(),
            .frequency = @floatFromInt(sdl3.timer.getPerformanceFrequency()),
            .memory_registry = memory_registry
        };

        self.window_manager = .init(try memory_registry.createCategory("Window manager"), &self.platform, self);
        self.script_engine = try .init(try memory_registry.createCategory("Script engine"), io, &self.scene_registry, &self.platform, &self.audio_engine, &self.window_manager, &self.color_registry, self);

        // SceneRegistry automatically handles deinitializing of skybox mesh
        Scene.skybox_mesh = try .loadFromFile(allocator, io, "src/assets/models/skybox.obj");
        Color.registry = &self.color_registry;

        self.script_engine.runFile("src/assets/scripts/main.lua");
        log.info("Initialized", .{});
    }

    pub fn step(self: *Engine) !void {
        const currentTime = sdl3.timer.getPerformanceCounter();
        const dt = @as(f32, @floatFromInt(currentTime - self.last_time_ms)) / self.frequency;
        self.last_time_ms = currentTime;

        self.preStep();

        try perf.beginFrame("main"); {
            // events
            perf.start("events"); {
                self.window_manager.pumpEvents();
                if (!self.running) return;
            } perf.stop();

            // render scene
            perf.start("scenes"); {
                const cam = if (self.window_manager.focused) |f|
                    if (f.camera) |f_cam|
                        switch (f_cam.data) {
                            .camera => |c| c.camera,
                            else => null,
                        }
                    else null
                 else null;

                for (self.scene_registry.scenes.items) |s| {
                    perf.start("update"); { s.update(dt); } perf.stop();
                    perf.start("audio"); { try self.audio_engine.tick(s, cam); } perf.stop();
                }
            } perf.stop();

            perf.start("windows"); {
                for (self.window_manager.windows.items) |w| {
                    w.update(dt);
                }
            } perf.stop();

            // submit
            perf.start("render"); {
                try self.window_manager.renderAll(&self.renderer, self.default_font);
            } perf.stop();
        } perf.endFrame();

        const frameTime = sdl3.timer.getPerformanceCounter() - currentTime;
        const frameTimeNs: f32 = @as(f32, @floatFromInt(frameTime)) * 1_000_000_000.0 / self.frequency;

        // fill out engine info for this frame
        self.frame += 1;
        self.fps = 1.0 / (@as(f32, @floatFromInt(frameTime)) / self.frequency);

        self.postStep();

        // frame limiter
        const fps_ns: f32 = 1_000_000_000.0 / @as(f32, @floatFromInt(self.target_fps));
        if (frameTimeNs < fps_ns) {
            sdl3.timer.delayNanosecondsPrecise(@intFromFloat(fps_ns - frameTimeNs));
        }
    }

    pub fn deinit(self: *Engine) void {
        const close_reason = if (self.close_reason) |cr| @tagName(cr) else null;
        log.info("Closing (reason: {?s})", .{ close_reason });

        for (self.pre_step_callbacks.items) |cb| cb.deinit();
        for (self.post_step_callbacks.items) |cb| cb.deinit();
        self.pre_step_callbacks.deinit(self.allocator);
        self.post_step_callbacks.deinit(self.allocator);

        self.thread_registry.deinit();
        self.platform.deinit();
        self.window_manager.deinit();
        self.renderer.deinit();
        self.audio_engine.deinit();
        self.widget_registry.deinit();
        self.scene_registry.deinit();
        self.color_registry.deinit();
        self.default_font.deinit();

        // calling this last is important!
        self.script_engine.deinit();
    }

    pub fn quit(self: *Engine, reason: CloseReason) void {
        self.running = false;
        self.close_reason = reason;
    }

    pub fn preStep(self: *Engine) void {
        for (self.pre_step_callbacks.items) |cb| {
            cb.call(.{});
        }
    }

    pub fn postStep(self: *Engine) void {
        for (self.post_step_callbacks.items) |cb| {
            cb.call(.{});
        }
    }
};
