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
const render = engine.render;
const Input = engine.Input;

const target_fps = 120;
const fps_seconds: f32 = 1.0 / @as(f32, @floatCast(target_fps));
const asset_purge_rate_seconds: std.Io.Duration = .fromSeconds(1);
const clear_color: core.Color = .fromRgbFloat(0.1, 0.1, 0.1, 1.0);

const Scene = struct { cam: ?ecs.Entity };

fn submitToRenderer(w: *ecs.World, ui_world: *ecs.World, renderer: *render.Renderer) void {
    const allocator = renderer.frame_allocator.allocator();

    const mesh_id = w.components.id("Mesh").?;
    const image_id = w.components.id("Image").?;
    const pos_id = w.components.id("Position").?;
    const rot_id = w.components.id("Rotation").?;
    const scale_id = w.components.id("Scale").?;
    const scene_id = w.components.id("Scene").?;
    const light_id = w.components.id("Light").?;

    var ui_objects: std.ArrayList(render.types.UiObject) = .empty;
    var objects: std.ArrayList(render.types.RenderObject) = .empty;
    var lights: std.ArrayList(gpu.types.GpuLight) = .empty;

    // 2D world (for UI)
    {
        const pos_2d_id = ui_world.components.id("Position").?;
        const size_2d_id = ui_world.components.id("Size").?;
        const color_id = ui_world.components.id("Color").?;

        const query = ui_world.query(&.{ pos_2d_id, size_2d_id });
        var iter = query.iterator();
        while (iter.next()) |entity| {
            const pos: math.Vec2 = if (ui_world.getComponent(entity, pos_2d_id, math.Vec2)) |p| p.* else .zero;
            const size: math.Vec2 = if (ui_world.getComponent(entity, size_2d_id, math.Vec2)) |p| p.* else .zero;
            const color: core.Color = if (ui_world.getComponent(entity, color_id, core.Color)) |c| c.* else .fromRgbFloat(0.0, 0.0, 0.0, 1.0);

            ui_objects.append(allocator, .{
                .pos = pos.arr(),
                .size = size.arr(),
                .color = color
            }) catch @panic("Out of memory");
        }
    }

    // 3D world

    const camera = blk: {
        var iter = w.query(&.{ scene_id }).iterator();
        break :blk if (iter.next()) |entity| if (w.getComponent(entity, scene_id, Scene)) |scene| scene.cam else null else null;
    };
    const cam_pos = blk: {
        const cam = camera orelse break :blk math.Vec3.zero;
        const pos = w.getComponent(cam, pos_id, math.Vec3) orelse break :blk math.Vec3.zero;
        break :blk pos.*;
    };
    const cam_rot = blk: {
        const cam = camera orelse break :blk math.Vec3.zero;
        const rot = w.getComponent(cam, rot_id, math.Vec3) orelse break :blk math.Vec3.zero;
        break :blk rot.*;
    };

    const view = math.Mat4.fromTRS(cam_pos, .fromEuler(cam_rot.toRadians()), .one).invertRT();
    const proj: math.Mat4 = .perspective(
        90.0 * (std.math.pi / 180.0), 
        @as(f32, @floatFromInt(renderer.surface_size[0])) / @as(f32, @floatFromInt(renderer.surface_size[1])), 
        0.1,
        100.0
    );

    const light_query = w.query(&.{ light_id });
    var light_iter = light_query.iterator();
    while (light_iter.next()) |entity| {
        const l = w.getComponent(entity, light_id, render.types.Light).?;
        const pos: math.Vec3 = if (w.getComponent(entity, pos_id, math.Vec3)) |p| p.* else .zero;
        const rot: math.Vec3 = if (w.getComponent(entity, rot_id, math.Vec3)) |r| r.* else .zero;

        const pos_or_dir = switch (l.kind) {
            .point => pos,
            .directional => blk: {
                const rot_mat = math.Quat.fromEuler(rot.toRadians()).toMat4();
                break :blk rot_mat.transformDirection(.new(0, 0, 1)).normalize();
            }
        };

        lights.append(allocator, .{
            .position_or_dir = pos_or_dir.arr(),
            .kind = @intFromEnum(l.kind),
            .color = .{ l.color.r(), l.color.g(), l.color.b() },
            .intensity = l.intensity,
            .radius = switch (l.kind) { .point => |pp| pp.radius, .directional => 0 },
        }) catch @panic("Out of memory");
    }


    // TODO: Make querying better. Quite limited right now
    const query = w.query(&.{ mesh_id, image_id });
    var iter = query.iterator();
    while (iter.next()) |entity| {
        const mesh = w.getComponent(entity, mesh_id, engine.Assets.AssetHandle);
        const image = w.getComponent(entity, image_id, engine.Assets.AssetHandle);

        // No visual appearance
        if (mesh == null and image == null) continue;

        // Upload to GPU if not already on it
        if (mesh != null and !mesh.?.hasGpuData()) mesh.?.upload(.{}) catch @panic("Failed to upload mesh to GPU");
        if (image != null and !image.?.hasGpuData()) image.?.upload(.{}) catch @panic("Failed to upload image to GPU");

        // This is so that if you have an image with no mesh, it's like a 2d plane in 3d space.
        // Could probably be convenient for 2D games, idk
        const mesh_data = if (mesh) |m| m.gpuGet(.mesh) catch continue else renderer.default_quad;
        // Mesh with no image = plain white
        const image_data = if (image) |i| i.gpuGet(.image) catch continue else renderer.default_image;
        
        const rot: math.Vec3 = if (w.getComponent(entity, rot_id, math.Vec3)) |r| r.* else .zero;
        const pos: math.Vec3 = if (w.getComponent(entity, pos_id, math.Vec3)) |p| p.* else .zero;
        const scale: math.Vec3 = if (w.getComponent(entity, scale_id, math.Vec3)) |scale| scale.* else .one;
        // Not visible (or invalid), don't waste resources rendering it.
        if (scale.x <= 0 or scale.y <= 0 or scale.z <= 0) continue;
        
        const model: math.Mat4 = .fromTRS(pos, .fromEuler(rot.toRadians()), scale);

        objects.append(allocator, .{ 
            .model = model, 
            .mesh = mesh_data, 
            .material = .{ 
                .image = image_data, 
                .sampler = renderer.default_sampler 
            }
        }) catch @panic("Out of memory");
    }

    renderer.render(
        .{ 
            .view_matrix = view,
            .proj_matrix = proj, 
            .viewport_size = renderer.surface_size 
        }, .{ 
            .ui_objects = ui_objects,
            .objects = objects,
            .lights = lights,
        }
    ) catch |e| std.log.err("render() failed: {s}", .{ @errorName(e) });
}

fn submitUiToRenderer(w: *ecs.World, _: f32, renderer: *render.Renderer) void {
    _ = w; _ = renderer;
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

    var scheduler: Scheduler = undefined;
    try scheduler.init(allocator, io, &os);
    defer scheduler.deinit();

    var platform_allocator: core.TrackedAllocator = .init(allocator, "Platform");
    var platform: Platform = try .init(platform_allocator.allocator(), .initSdl());
    defer platform.deinit();

    var input_allocator: core.TrackedAllocator = .init(allocator, "Input");
    var input: Input = undefined;
    try input.init(input_allocator.allocator(), &platform);
    defer input.deinit();

    var surface_size: [2]u32 = .{ 1280, 720 };
    const surface = try platform.createSurface(.{ .title = "crystal", .width = surface_size[0], .height = surface_size[1], .target = .primary });
    defer platform.destroySurface(surface);

    var gpu_allocator: core.TrackedAllocator = .init(allocator, "Gpu");
    var gpu_device: gpu.GpuDevice = try .init(gpu_allocator.allocator(), .initDiligent(surface.handle, surface_size));
    defer gpu_device.deinit();

    var asset_allocator: core.TrackedAllocator = .init(allocator, "Assets");
    var assets: engine.Assets = try .init(asset_allocator.allocator(), io, &gpu_device, project_path);
    defer assets.deinit();
    
    // Skybox
    const skybox_cubemap = try assets.load("assets://images/skybox_island.png");
    try skybox_cubemap.upload(.{ .is_cubemap = true });

    var renderer_allocator: core.TrackedAllocator = .init(allocator, "Renderer");
    var renderer: render.Renderer = try .init(renderer_allocator.allocator(), surface_size, &gpu_device, try skybox_cubemap.gpuGet(.image));
    defer renderer.deinit();

    // Create the world
    var ecs_allocator: core.TrackedAllocator = .init(allocator, "ECSWorld");
    var world: ecs.World = .init(ecs_allocator.allocator());
    defer world.deinit();

    // Create the UI world
    var ecs_ui_allocator: core.TrackedAllocator = .init(allocator, "ECSWorld (UI)");
    var ui_world: ecs.World = .init(ecs_ui_allocator.allocator());
    defer ui_world.deinit();

    var lua_allocator: core.TrackedAllocator = .init(allocator, "LuaRuntime");
    var runtime: scripting.Runtime = try .init(lua_allocator.allocator(), &world, &assets, &input);
    defer runtime.deinit();
    runtime.setGenerational();
    runtime.linkState();

    // Register components
    // TODO: Register these once somewhere, and access them there
    // instead of having to do world.components.id() over and over again.
    const scene_component = try world.registerComponentNative(Scene, "Scene"); // For organizing collections of entities
    _ = try world.registerComponentNativeShaped(engine.Assets.AssetHandle, "Mesh"); // For giving an entity a mesh appearance
    _ = try world.registerComponentNativeShaped(engine.Assets.AssetHandle, "Image"); // For giving an entity an image appearance (or a texture, if it has a mesh)
    const pos_component = try world.registerComponentNativeShaped(math.Vec3, "Position"); // For moving entities
    const rot_component = try world.registerComponentNativeShaped(math.Vec3, "Rotation"); // For rotating entites (Euler)
    const scale_component = try world.registerComponentNativeShaped(math.Vec3, "Scale"); // For scaling entities
    const script_component = try world.registerComponentNative(scripting.Script, "Script"); // For giving entities behavior
    const light_component = try world.registerComponentNativeShaped(render.types.Light, "Light"); // For creating sources of illumination
    _ = try world.registerComponentNativeShaped([]const u8, "Name"); // For naming an entity (we don't use it, but lua does)

    // Create a scene inside of the world
    const scene = try world.spawnEntity();

    // Make a camera for the scene
    const camera = try world.spawnEntity();
    try world.addComponent(camera, pos_component, math.Vec3, .new(0, 0, 0));
    try world.addComponent(camera, rot_component, math.Vec3, .new(0, 0, 0));
    try world.addComponent(camera, scale_component, math.Vec3, .new(1, 1, 1));

    // Camera script
    {
        const source = try assets.load("assets://scripts/camera.lua");
        defer source.cpuRelease();
        const script = try runtime.loadScript(try source.cpuGet(.script_source));

        try world.addComponent(camera, script_component, scripting.Script, script);
        const stored_script = world.getComponent(camera, script_component, scripting.Script).?;
        try stored_script.instantiate(camera);
    }

    try world.addComponent(scene, scene_component, Scene, .{ .cam = camera });

    // Spawn a new entity
    const entity = try world.spawnEntity();

    const light = try world.spawnEntity();
    try world.addComponent(light, light_component, render.types.Light, .{
        .color = .fromRgbFloat(1.0, 1.0, 1.0, 1.0),
        .intensity = 5,
        .kind = .{ .point = .{ .radius = 10 } }
    });
    try world.addComponent(light, pos_component, math.Vec3, .zero);
    try light.setParent(scene);

    // Parent the component under the scene
    try entity.setParent(scene);

    // Add a script to the component
    const source = try assets.load("assets://scripts/teapot.lua");
    defer source.cpuRelease();
    const script = try runtime.loadScript(try source.cpuGet(.script_source));

    try world.addComponent(entity, script_component, scripting.Script, script);
    const stored_script = world.getComponent(entity, script_component, scripting.Script).?;
    try stored_script.instantiate(entity);

    // 2D world + components for UI
    const pos_2d_component = try ui_world.registerComponentNativeShaped(math.Vec2, "Position");
    const size_2d_component = try ui_world.registerComponentNativeShaped(math.Vec2, "Size");
    const color_component = try ui_world.registerComponentNativeShaped(core.Color, "Color");

    const ui_entity = try ui_world.spawnEntity();
    try ui_world.addComponent(ui_entity, pos_2d_component, math.Vec2, .zero);
    try ui_world.addComponent(ui_entity, size_2d_component, math.Vec2, .new(640.0, 360.0));
    try ui_world.addComponent(ui_entity, color_component, core.Color, .fromRgbFloat(0.0, 0.0, 0.0, 0.5));

    var running = true;

    const event_con = try platform.platform_event.connect(struct {
        fn c(ctx: anytype, e: Platform.desc.PlatformEvent) void {
            switch (e) {
                .quit => ctx[0].* = false,
                .surface_resize => |sz| {
                    ctx[1].*[0] = sz.width;
                    ctx[1].*[1] = sz.height;
                },

                else => {}
            }
        }
    }.c, @constCast(&.{ &running, &surface_size }));
    defer event_con.disconnect();

    var last_time = std.Io.Clock.awake.now(io);
    var last_asset_tick = std.Io.Clock.awake.now(io);
    while (running) {
        const start = std.Io.Clock.awake.now(io);
        const dt = last_time.durationTo(start);
        const dt_seconds: f32 = @floatCast(@as(f32, @floatFromInt(dt.toNanoseconds())) / std.time.ns_per_s);
        last_time = start;

        input.tick();
        platform.poll();
        world.update(dt_seconds);
        submitToRenderer(&world, &ui_world, &renderer);

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
            io.sleep(frame_time, .awake) catch {};
        }
    }
}
