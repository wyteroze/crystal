// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const engine = @import("engine");
const Platform = engine.Platform;
const gfx = engine.gfx;
const ecs = engine.ecs;
const assets = engine.assets;

const project_root = "demos/example/";

const RenderCtx = struct {
    renderer: *gfx.Renderer,
    pipeline: gfx.types.PipelineHandle,
    vbuf: gfx.types.BufferHandle,
    mesh_id: ecs.ComponentId,
    surface_size: *[2]u32
};

fn render(w: *ecs.World, _: f32, ctx: *RenderCtx) void {
    ctx.renderer.beginPass(.{ .clear_color = .{ 0.1, 0.1, 0.1, 1.0 }, .width = ctx.surface_size[0], .height = ctx.surface_size[1] });
    ctx.renderer.applyPipeline(ctx.pipeline);
    ctx.renderer.applyBindings(.{ .vertex_buffers = .{ ctx.vbuf, null, null, null } });

    var q = w.query(&.{ ctx.mesh_id });
    var it = q.iterator();
    while (it.next() != null) {
        ctx.renderer.draw(0, 3, 1);
    }

    ctx.renderer.endPass();
    ctx.renderer.commit();
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    _ = io;

    var world: ecs.World = .init(allocator);
    defer world.deinit();

    const model_path = try std.Io.Dir.path.joinZ(allocator, &.{ project_root, "assets", "models", "shortandstout.glb" });
    defer allocator.free(model_path);

    var model = try assets.importMesh(allocator, model_path);
    defer model.deinit(allocator);

    const entity = try world.spawnEntity();

    const mesh_component = try world.registerComponentNative(assets.Mesh, "Mesh");
    try world.addComponent(entity, mesh_component, assets.Mesh, model);

    var platform: Platform = try .init(.initSdl());
    defer platform.deinit();

    var surface_size: [2]u32 = .{ 1280, 720 };
    const surface = try platform.createSurface(.{ .title = "crystal", .width = surface_size[0], .height = surface_size[1], .target = .primary });
    defer platform.destroySurface(surface);

    var renderer: gfx.Renderer = .init(.initSokol());
    defer renderer.deinit();

    const shader = gfx.shaders.basic(&renderer);

    const sab = std.mem.sliceAsBytes(model.vertices);
    const vbuf = renderer.createBuffer(.{
        .type = .vertex,
        .data = sab,
        .size = sab.len
    });

    const pipeline = renderer.createPipeline(.{
        .shader = shader,
        .layout = &.{
            .{ .offset = 0, .format = .float3 },
            .{ .offset = 12, .format = .float4 }
        }
    });

    var render_ctx = RenderCtx{
        .renderer = &renderer,
        .pipeline = pipeline,
        .vbuf = vbuf,
        .surface_size = &surface_size,
        .mesh_id = mesh_component
    };
    try world.registerSystem("Render", RenderCtx, render, &render_ctx);

    var running = true;
    while (running) {
        while (platform.pollEvent()) |e| {
            switch (e) {
                .quit => running = false,
                .surface_resize => |sz| { surface_size[0] = sz.width; surface_size[1] = sz.height; }
            }
            if (e == .quit) running = false;
        }

        world.tickAllSystems(0);

        try platform.swapBuffers(surface);
    }
}
