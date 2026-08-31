// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const builtin = @import("builtin");
const engine = @import("engine");
const Platform = engine.Platform;
const gfx = engine.gfx;
const ecs = engine.ecs;
const assets = engine.assets;
const math = engine.core.math;
const scripting = engine.scripting;
const Os = engine.Os;
const core = engine.core;
const toml = engine.toml;

const target_fps = 120;
const fps_seconds: f32 = 1.0 / @as(f32, @floatCast(target_fps));
const asset_purge_rate_seconds: f32 = 0.5;

const RenderCtx = struct { 
    renderer: *gfx.Renderer, 
    pipeline: gfx.types.PipelineHandle, 
    vbuf: gfx.types.BufferHandle, 
    ibuf: gfx.types.BufferHandle, 
    mesh_id: ecs.ComponentId, 
    pos_id: ecs.ComponentId, 
    rot_id: ecs.ComponentId, 
    surface_size: *[2]u32, 
    scene_entity: ecs.Entity, 
    proj: math.Mat4, 
    clock: f32 
};

const Position = math.Vec3;
const Rotation = math.Vec3;
const Scene = struct { cam: ?ecs.Entity };

fn render(w: *ecs.World, dt: f32, ctx: *RenderCtx) void {
    ctx.clock += dt;

    ctx.renderer.beginPass(.{ .clear_color = .{ 0.1, 0.1, 0.1, 1.0 }, .width = ctx.surface_size[0], .height = ctx.surface_size[1] });
    ctx.renderer.applyPipeline(ctx.pipeline);

    const scene = w.getComponent(ctx.scene_entity, w.components.id("Scene").?, Scene).?.*;
    const view = if (scene.cam) |cam| blk: {
        const pos = (w.getComponent(cam, w.components.id("Position").?, Position) orelse &math.Vec3.zero);
        const rot = (w.getComponent(cam, w.components.id("Rotation").?, Rotation) orelse &math.Vec3.zero);

        break :blk math.Mat4.fromTRS(pos.*, .fromEuler(.fromSimd(rot.*.simd() * @as(math.Vec3.Simd3, @splat(std.math.pi / 180.0)))), .one).invertRT();
    } else math.Mat4.identity;

    var q = w.query(&.{ ctx.mesh_id, ctx.pos_id, ctx.rot_id });
    var it = q.iterator();
    while (it.next()) |entity| {
        const mesh = w.getComponent(entity, w.components.id("Mesh").?, assets.types.Mesh) orelse continue;
        const pos = w.getComponent(entity, ctx.pos_id, Position).?.*;
        const rot = w.getComponent(entity, ctx.rot_id, Rotation).?.*;

        const model: math.Mat4 = .fromTRS(pos, .fromEuler(.fromSimd(rot.simd() * @as(math.Vec3.Simd3, @splat(std.math.pi / 180.0)))), .one);
        const vs_params: gfx.shaders.program.VsParams = .{ .model = @bitCast(model.transpose()), .view = @bitCast(view.transpose()), .proj = @bitCast(ctx.proj.transpose()) };

        ctx.renderer.applyBindings(.{ .vertex_buffers = .{ ctx.vbuf, null, null, null }, .index_buffer = ctx.ibuf });
        ctx.renderer.applyUniforms(.{ .slot = gfx.shaders.program.UB_vs_params, .data = std.mem.asBytes(&vs_params) });

        ctx.renderer.draw(0, @intCast(mesh.indices.len), 1);
    }

    ctx.renderer.endPass();
    ctx.renderer.commit();
}

fn updateScripts(w: *ecs.World, dt: f32, _: *void) void {
    const script_component = w.components.id("Script").?;

    const scripts = w.query(&.{ script_component });
    var iter = scripts.iterator();
    while (iter.next()) |e| {
        const scr = w.getComponent(e, script_component, scripting.Script) orelse continue;
        _ = scr.callMethod("OnUpdate", &.{}, &.{ dt }) catch {};
    }
}

pub fn main(init: std.process.Init) !void {
    var tracked = core.TrackedAllocator.init(init.gpa, "Overall");
    const allocator = tracked.allocator();
    const io = init.io;

    var project_path: ?[]const u8 = null;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    for (args) |a| {
        if (std.mem.find(u8, a, "--project=") != null) {
            project_path = std.mem.trimStart(u8, a, "--project=");
            break;
        }
    }

    const boot = try core.boot.BootInfo.resolveBootInfo(io, allocator) orelse blk: {
        if (project_path) |path| {
            var parser: toml.Parser(struct { project: struct { package: []const u8, name: []const u8 } }) = .init(allocator);
            defer parser.deinit();

            const toml_path = try std.Io.Dir.path.join(allocator, &.{ path, "Crystal.toml" });
            defer allocator.free(toml_path);

            var result = try parser.parseFile(init.io, toml_path);
            defer result.deinit();

            const package_id = try init.arena.allocator().dupe(u8, result.value.project.package);

            break :blk core.boot.BootInfo{ .package_id = package_id, .payload_offset = 0, .payload_len = 0 };
        } else {
            @panic("Failed to find boot info. This means either the executable wasn't built as a baked project when it should have been, or the 'game.crypak' file was deleted or moved.");
        }
    };
    
    const os: Os = try .init(init, builtin.os.tag, boot.package_id);

    var lua_allocator: core.TrackedAllocator = .init(allocator, "LuaRuntime");
    const runtime: scripting.Runtime = try .init(lua_allocator.allocator());
    defer runtime.deinit();
    runtime.setGenerational();

    var asset_allocator: core.TrackedAllocator = .init(allocator, "AssetRegistry");
    var asset_registry: assets.AssetRegistry = try .init(asset_allocator.allocator(), io, os, project_path);
    defer asset_registry.deinit();

    // Create the world
    var ecs_allocator: core.TrackedAllocator = .init(allocator, "ECSWorld");
    var world: ecs.World = .init(ecs_allocator.allocator());
    defer world.deinit();

    // Register components
    const scene_component = try world.registerComponentNative(Scene, "Scene"); // For organizing collections of entities
    const mesh_component = try world.registerComponentNative(assets.types.Mesh, "Mesh"); // For giving an entity a mesh appearance
    const pos_component = try world.registerComponentNativeShaped(Position, "Position"); // For moving entities
    const rot_component = try world.registerComponentNativeShaped(Rotation, "Rotation"); // For rotating entites (Euler)
    const script_component = try world.registerComponentNative(scripting.Script, "Script"); // For giving entities behavior

    // Create a scene inside of the world
    const scene = try world.spawnEntity();

    // Make a camera for the scene
    const camera = try world.spawnEntity();
    try world.addComponent(camera, pos_component, Position, .new(0, 0, 0));
    try world.addComponent(camera, rot_component, Rotation, .new(0, 0, 0));

    try world.addComponent(scene, scene_component, Scene, .{ .cam = camera });

    // Spawn a new entity
    const entity = try world.spawnEntity();

    // Load teapot model
    var model = try asset_registry.load("file://models/shortandstout.glb");
    defer model.release();
    const mesh = try model.mesh();

    // Give the entity the teapot mesh
    try world.addComponent(entity, mesh_component, assets.types.Mesh, mesh.*);

    // Parent the component under the scene
    try entity.setParent(scene);

    // Give the entity a position and rotation
    try world.addComponent(entity, pos_component, Position, .zero);
    try world.addComponent(entity, rot_component, Rotation, .zero);

    // Add a script to the component
    const source = try asset_registry.load("file://scripts/teapot.lua");
    defer source.release();
    const script = try runtime.loadScript((try source.scriptSource()).*);

    try world.addComponent(entity, script_component, scripting.Script, script);
    const stored_script = world.getComponent(entity, script_component, scripting.Script).?;
    try stored_script.instantiate(entity);

    var platform: Platform = try .init(.initSdl());
    defer platform.deinit();

    var surface_size: [2]u32 = .{ 1280, 720 };
    const surface = try platform.createSurface(.{ .title = "crystal", .width = surface_size[0], .height = surface_size[1], .target = .primary });
    defer platform.destroySurface(surface);

    var renderer_allocator: core.TrackedAllocator = .init(allocator, "Renderer");
    var renderer: gfx.Renderer = .init(.initSokol(renderer_allocator.allocator()));
    defer renderer.deinit();

    const shader = renderer.createShader(gfx.shaders.basicShaderDesc());

    const sab = std.mem.sliceAsBytes(mesh.vertices);
    const iab = std.mem.sliceAsBytes(mesh.indices);
    const vbuf = renderer.createBuffer(.{ .type = .vertex, .data = sab, .size = sab.len });
    const ibuf = renderer.createBuffer(.{ .type = .index, .data = iab, .size = iab.len });

    const pipeline = renderer.createPipeline(.{
        .shader = shader,
        .index_type = .uint32,
        .cull_mode = .front,
        .depth_write = true,
        .layout = &.{ .{ .offset = 0, .format = .float3 }, .{ .offset = 12, .format = .float3 }, .{ .offset = 24, .format = .float2 } },
    });

    const proj = math.Mat4.perspective(90.0 * (std.math.pi / 180.0), @as(f32, @floatFromInt(surface_size[0])) / @as(f32, @floatFromInt(surface_size[1])), 0.1, 100.0);

    var render_ctx = RenderCtx{ .renderer = &renderer, .pipeline = pipeline, .vbuf = vbuf, .ibuf = ibuf, .surface_size = &surface_size, .mesh_id = mesh_component, .pos_id = pos_component, .rot_id = rot_component, .scene_entity = scene, .proj = proj, .clock = 0 };
    try world.registerSystem("Render", RenderCtx, render, &render_ctx);

    // dear god
    try world.registerSystem("UpdateScripts", void, updateScripts, @constCast(&{}));

    var running = true;
    var last_time = platform.getElapsedSeconds();
    var last_asset_tick = platform.getElapsedSeconds();
    while (running) {
        const start = platform.getElapsedSeconds();
        const dt: f32 = @floatCast(start - last_time);
        last_time = start;

        while (platform.pollEvent()) |e| {
            switch (e) {
                .quit => running = false,
                .surface_resize => |sz| {
                    surface_size[0] = sz.width;
                    surface_size[1] = sz.height;
                },
            }
        }

        world.tickAllSystems(dt);
        try platform.swapBuffers(surface);

        const end = platform.getElapsedSeconds();

        if (end > last_asset_tick + asset_purge_rate_seconds) {
            const purged = asset_registry.cache.tick();
            last_asset_tick = end;

            if (purged > 0) std.log.debug("Purged {d} assets", .{ purged });
            std.log.info("-----Allocators ({f} tracked, {f} total)-----", .{ core.SizeFormatter.fmtSize( 
                lua_allocator.currentUsage() + 
                asset_allocator.currentUsage() + 
                ecs_allocator.currentUsage() +
                renderer_allocator.currentUsage()
            ), core.SizeFormatter.fmtSize(tracked.currentUsage()) });

            std.log.info("{f}", .{ lua_allocator });
            std.log.info("{f}", .{ asset_allocator });
            std.log.info("{f}", .{ ecs_allocator });
            std.log.info("{f}", .{ renderer_allocator });

            std.log.info("[Lua GC]: {f}", .{ core.SizeFormatter.fmtSize( @intCast( runtime.gcCount() * 1024 ) ) });
        }

        const frame_time = end - start;
        if (fps_seconds > frame_time) {
            platform.waitSeconds(@floatCast(fps_seconds - frame_time));
        }
    }
}
