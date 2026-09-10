// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const builtin = @import("builtin");
const engine = @import("engine");
const Platform = engine.Platform;
const gpu = engine.gpu;
const ecs = engine.ecs;
const math = engine.core.math;
const scripting = engine.scripting;
const Os = engine.Os;
const core = engine.core;
const toml = engine.toml;
const Scheduler = engine.Scheduler;

const target_fps = 120;
const fps_seconds: f32 = 1.0 / @as(f32, @floatCast(target_fps));
const asset_purge_rate_seconds: std.Io.Duration = .fromSeconds(1);
const clear_color: core.Color = .fromRgbFloat(0.1, 0.1, 0.1, 1.0);

const RenderCtx = struct { 
    gpu_device: *gpu.GpuDevice, 
    pipeline: gpu.GpuDevice.GpuPipeline, 
    mesh: engine.Assets.types.GpuMesh,
    ubuf: gpu.GpuDevice.GpuBuffer,
    light_ubuf: gpu.GpuDevice.GpuBuffer,
    img: engine.Assets.types.GpuImage,
    sampler: gpu.GpuDevice.GpuSampler,
    mesh_id: ecs.ComponentId, 
    pos_id: ecs.ComponentId, 
    rot_id: ecs.ComponentId, 
    surface_size: *[2]u32, 
    scene_entity: ecs.Entity, 
    proj: math.Mat4, 
    clock: f32,
    light_params: LightParams
};

const Position = math.Vec3;
const Rotation = math.Vec3;
const Scene = struct { cam: ?ecs.Entity };

const LightParams = struct { 
    dir: core.math.Vec3, 
    color: core.Color,
    ambient: core.Color
};

const render = struct {
    fn renderMeshTextured() void {

    }

    fn renderMesh() void {

    }

    fn renderImage() void {

    }

    pub fn render(w: *ecs.World, dt: f32, ctx: *RenderCtx) void {
        ctx.clock += dt;

        ctx.gpu_device.beginPass(.{ 
            .clear_color = clear_color.srgbDecode(), 
            .clear_depth = 1.0,
            .width = ctx.surface_size[0], 
            .height = ctx.surface_size[1]
        });
        ctx.pipeline.apply();

        const scene = w.getComponent(ctx.scene_entity, w.components.id("Scene").?, Scene).?.*;
        const view = if (scene.cam) |cam| blk: {
            const pos = (w.getComponent(cam, w.components.id("Position").?, Position) orelse &math.Vec3.zero);
            const rot = (w.getComponent(cam, w.components.id("Rotation").?, Rotation) orelse &math.Vec3.zero);

            break :blk math.Mat4.fromTRS(pos.*, .fromEuler(.fromSimd(rot.*.simd() * @as(math.Vec3.Simd3, @splat(std.math.pi / 180.0)))), .one).invertRT();
        } else math.Mat4.identity;

        var q = w.query(&.{ ctx.mesh_id, ctx.pos_id, ctx.rot_id });
        var it = q.iterator();
        while (it.next()) |entity| {
            if (entity.getParent() == null) continue;
            const pos = w.getComponent(entity, ctx.pos_id, Position).?.*;
            const rot = w.getComponent(entity, ctx.rot_id, Rotation).?.*;
            
            const model: math.Mat4 = .fromTRS(pos, .fromEuler(.fromSimd(rot.simd() * @as(math.Vec3.Simd3, @splat(std.math.pi / 180.0)))), .one);
            const vs_params: [3][4][4]f32 = .{
                @bitCast(model.transpose()),
                @bitCast(view.transpose()),
                @bitCast(ctx.proj.transpose()),
            };

            const l = ctx.light_params;
            const light_params_flattened: [3][4]f32 = .{
                .{ l.dir.x, l.dir.y, l.dir.z, 0 }, // Last value is padding
                .{ l.color.r(), l.color.g(), l.color.b(), 0 }, // Last value is padding
                .{ l.ambient.r(), l.ambient.g(), l.ambient.b(), 0 }, // Last value is padding
            };
            
            ctx.pipeline.applyBindings(.{ 
                .vertex_buffers = .{ ctx.mesh.vertex_buffer.handle, null, null, null }, 
                .index_buffer = ctx.mesh.index_buffer.handle,
                .uniform_buffers = .{ ctx.ubuf.handle, ctx.light_ubuf.handle, null, null },
                .images = .{ ctx.img.handle.handle, null, null, null },
                .samplers = .{ ctx.sampler.handle, null, null, null }
            });
            ctx.ubuf.update(std.mem.asBytes(&vs_params));
            ctx.light_ubuf.update(std.mem.asBytes(&light_params_flattened));

            ctx.pipeline.draw(0, @intCast(ctx.mesh.index_count), 1);
        }

        ctx.gpu_device.endPass();
        ctx.gpu_device.present();
    }
}.render;

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

    var platform: Platform = try .init(.initSdl());
    defer platform.deinit();

    var scheduler: Scheduler = undefined;
    try scheduler.init(allocator, io, &os);
    defer scheduler.deinit();

    var surface_size: [2]u32 = .{ 1280, 720 };
    const surface = try platform.createSurface(.{ .title = "crystal", .width = surface_size[0], .height = surface_size[1], .target = .primary });
    defer platform.destroySurface(surface);

    var gpu_allocator: core.TrackedAllocator = .init(allocator, "Gpu");
    var gpu_device: gpu.GpuDevice = .init(.initDiligent(surface.handle, surface_size));
    defer gpu_device.deinit();

    var asset_allocator: core.TrackedAllocator = .init(allocator, "Assets");
    var assets: engine.Assets = try .init(asset_allocator.allocator(), io, &gpu_device, project_path);
    defer assets.deinit();

    // Create the world
    var ecs_allocator: core.TrackedAllocator = .init(allocator, "ECSWorld");
    var world: ecs.World = .init(ecs_allocator.allocator());
    defer world.deinit();

    var lua_allocator: core.TrackedAllocator = .init(allocator, "LuaRuntime");
    var runtime: scripting.Runtime = try .init(lua_allocator.allocator(), &world, &assets);
    defer runtime.deinit();
    runtime.setGenerational();
    runtime.linkState();

    // Register components
    const scene_component = try world.registerComponentNative(Scene, "Scene"); // For organizing collections of entities
    const mesh_component = try world.registerComponentNativeShaped(engine.Assets.AssetHandle, "Mesh"); // For giving an entity a mesh appearance
    const image_component = try world.registerComponentNativeShaped(engine.Assets.AssetHandle, "Image"); // For giving an entity an image appearance (or a texture, if it has a mesh)
    const pos_component = try world.registerComponentNativeShaped(Position, "Position"); // For moving entities
    const rot_component = try world.registerComponentNativeShaped(Rotation, "Rotation"); // For rotating entites (Euler)
    const script_component = try world.registerComponentNative(scripting.Script, "Script"); // For giving entities behavior
    _ = try world.registerComponentNativeShaped([]const u8, "Name"); // For naming an entity (we don't use it, but lua does)

    // Create a scene inside of the world
    const scene = try world.spawnEntity();

    // Make a camera for the scene
    const camera = try world.spawnEntity();
    try world.addComponent(camera, pos_component, Position, .new(0, 0, 0));
    try world.addComponent(camera, rot_component, Rotation, .new(0, 0, 0));

    try world.addComponent(scene, scene_component, Scene, .{ .cam = camera });

    // Spawn a new entity
    const entity = try world.spawnEntity();

    // Parent the component under the scene
    try entity.setParent(scene);

    // Add a script to the component
    const source = try assets.load("assets://scripts/teapot.lua");
    defer source.cpuRelease();
    const script = try runtime.loadScript(try source.cpuGet(.script_source));

    try world.addComponent(entity, script_component, scripting.Script, script);
    const stored_script = world.getComponent(entity, script_component, scripting.Script).?;
    try stored_script.instantiate(entity);

    const shader = try gpu_device.createShader(gpu.shaders.basicShaderDesc());

    const mesh_asset = world.getComponent(entity, mesh_component, engine.Assets.AssetHandle) orelse unreachable;
    const image_asset = world.getComponent(entity, image_component, engine.Assets.AssetHandle) orelse unreachable;
    try assets.upload(mesh_asset.*);
    try assets.upload(image_asset.*);
    defer mesh_asset.gpuRelease();
    defer image_asset.gpuRelease();
    mesh_asset.cpuRelease();
    image_asset.cpuRelease();

    const mesh = try mesh_asset.gpuGet(.mesh);
    const image = try image_asset.gpuGet(.image);

    const ubuf = try gpu_device.createBuffer(.{ .name = "teapot ubuf", .type = .uniform, .usage = .dynamic, .size = @sizeOf([3]math.Mat4) });
    const light_ubuf = try gpu_device.createBuffer(.{ .name = "light ubuf", .type = .uniform, .usage = .dynamic, .size = 48 });

    const sampler = try gpu_device.createSampler(.{});
    const pipeline = try gpu_device.createPipeline(.{
        .name = "Teapot",
        .shader = shader.handle,
        .index_type = .uint32,
        .cull_mode = .none,
        .depth_write = true,
        .layout = &.{ 
            .{ .offset = 0, .format = .float3 }, // position
            .{ .offset = 12, .format = .float3 }, // normal
            .{ .offset = 24, .format = .float2 }  // uv
        },
    });

    const proj: math.Mat4 = .perspective(
        90.0 * (std.math.pi / 180.0), 
        @as(f32, @floatFromInt(surface_size[0])) / @as(f32, @floatFromInt(surface_size[1])), 
        0.1,
        100.0
    );

    var render_ctx = RenderCtx{ 
        .gpu_device = &gpu_device, 
        .pipeline = pipeline, 
        .mesh = mesh,
        .ubuf = ubuf,
        .light_ubuf = light_ubuf,
        .img = image,
        .sampler = sampler,
        .surface_size = &surface_size, 
        .mesh_id = mesh_component, 
        .pos_id = pos_component, 
        .rot_id = rot_component, 
        .scene_entity = scene, 
        .proj = proj, 
        .clock = 0,
        .light_params = .{
            .dir = core.math.Vec3.new(0, 0.5, -0.5).normalize(),
            .color = core.Color.fromRgbFloat(1.0, 1.0, 1.0, 1.0),
            .ambient = core.Color.fromRgbFloat(0.05, 0.05, 0.05, 0.0)
        }
    };
    try world.registerSystem("Render", RenderCtx, render, &render_ctx);

    // dear god
    try world.registerSystem("UpdateScripts", void, updateScripts, @constCast(&{}));

    var running = true;
    var last_time = std.Io.Clock.awake.now(io);
    var last_asset_tick = std.Io.Clock.awake.now(io);
    while (running) {
        const start = std.Io.Clock.awake.now(io);
        const dt = last_time.durationTo(start);
        const dt_seconds: f32 = @floatCast(@as(f32, @floatFromInt(dt.toNanoseconds())) / std.time.ns_per_s);
        last_time = start;

        var frame_root: Scheduler.Counter = .{};

        scheduler.waitBlocking(&frame_root);

        while (platform.pollEvent()) |e| {
            switch (e) {
                .quit => running = false,
                .surface_resize => |sz| {
                    surface_size[0] = sz.width;
                    surface_size[1] = sz.height;
                },
            }
        }

        world.tickAllSystems(dt_seconds);

        const end = std.Io.Clock.awake.now(io);

        if (end.nanoseconds > last_asset_tick.addDuration(asset_purge_rate_seconds).nanoseconds) {
            const purged = assets.tick();
            last_asset_tick = end;

            if (purged > 0) std.log.debug("Purged {d} assets", .{ purged });
            std.log.info("-----Allocators ({f} tracked, {f} total)-----", .{ core.SizeFormatter.fmtSize( 
                lua_allocator.currentUsage() + 
                asset_allocator.currentUsage() + 
                ecs_allocator.currentUsage() +
                gpu_allocator.currentUsage()
            ), core.SizeFormatter.fmtSize(tracked.currentUsage()) });

            std.log.info("{f}", .{ lua_allocator });
            std.log.info("{f}", .{ asset_allocator });
            std.log.info("{f}", .{ ecs_allocator });
            std.log.info("{f}", .{ gpu_allocator });

            std.log.info("[Lua GC]: {f}", .{ core.SizeFormatter.fmtSize( @intCast( runtime.gcCount() * 1024 ) ) });
        }

        const frame_time = start.durationTo(end);
        if (frame_time.toNanoseconds() > 0) {
            try io.sleep(frame_time, .awake);
        }
    }
}
