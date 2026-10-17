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
const Ui = engine.Ui;
const Audio = engine.Audio;

const target_fps = 120;
const fps_seconds: f32 = 1.0 / @as(f32, @floatCast(target_fps));
const asset_purge_rate_seconds: std.Io.Duration = .fromMilliseconds(500);

const WindowInfo = struct { surface: Platform.types.SurfaceHandle, entity: ecs.Entity };
const Camera = struct {
    fov: f32 = 90,
    near_plane: f32 = 0.1,
};

fn openWindow(platform: *Platform, renderer: *render.Renderer, ui: *Ui, windows: *std.AutoHashMap(u64, WindowInfo), title: [:0]const u8, w: u32, h: u32) !ecs.Entity {
    const surface = try platform.createSurface(.{ .title = title, .width = w, .height = h, .target = .primary });

    const id: u64 = surface.id;
    const pixel = try platform.getSurfacePixelSize(surface);
    const logical = try platform.getSurfaceLogicalSize(surface);
    const scale = try platform.getSurfaceScale(surface);

    try renderer.createWindow(id, surface.handle, pixel, scale);

    const entity = try ui.world.spawnEntity();
    try ui.world.set(entity, ui.component_ids.window, Ui.types.Window, .{ .id = id, .scale = scale });
    try ui.world.set(entity, ui.component_ids.position, math.Vec2, .new(0, 0));
    try ui.world.set(entity, ui.component_ids.size, Ui.types.SizeMode, .fixed(@floatFromInt(logical[0]), @floatFromInt(logical[1])));
    try windows.put(id, .{ .surface = surface, .entity = entity });

    return entity;
}

fn syncWindow(platform: *Platform, renderer: *render.Renderer, ui: *Ui, windows: *std.AutoHashMap(u64, WindowInfo), id: u64) void {
    const info = windows.get(id) orelse return;
    const pixel = platform.getSurfacePixelSize(info.surface) catch return;
    const logical = platform.getSurfaceLogicalSize(info.surface) catch return;
    const scale = platform.getSurfaceScale(info.surface) catch return;

    renderer.resizeWindow(id, pixel, scale) catch |e| std.log.err("Failed to resized window: {s}", .{ @errorName(e) });

    if (ui.world.getComponent(info.entity, ui.component_ids.window, Ui.types.Window)) |w| w.scale = scale;
    ui.world.set(info.entity, ui.component_ids.size, Ui.types.SizeMode,
        .fixed(@floatFromInt(logical[0]), @floatFromInt(logical[1]))) catch {};
}

fn rootOf(e: ecs.Entity) ecs.Entity {
    var r = e;
    while (r.getParent()) |p| r = p;

    return r;
}

fn collectUiObjects(
    ui: *Ui,
    entity: ecs.Entity,
    objs: *std.ArrayList(render.types.UiObject),
    alloc: std.mem.Allocator,
) void {
    const cids = ui.component_ids;
    if (!ui.world.hasComponent(entity, cids.render_view)) {
        const pos: math.Vec2 = if (ui.world.getComponent(entity, cids.computed_position, math.Vec2)) |p| p.* else .zero;
        const size: math.Vec2 = if (ui.world.getComponent(entity, cids.computed_size, math.Vec2)) |p| p.* else .zero;
        const corners = if (ui.world.getComponent(entity, cids.corner_radii, Ui.types.CornerRadii)) |c| c.* else null;
        const borders = if (ui.world.getComponent(entity, cids.borders, Ui.types.Borders)) |b| b.* else null;
        const image = if (ui.world.getComponent(entity, cids.image, Ui.types.Image)) |i| i.* else null;
        const color: core.Color = if (ui.world.getComponent(entity, cids.color, core.Color)) |c| c.*
            else if (image != null) .fromRgbFloat(1.0, 1.0, 1.0, 1.0)
            else .fromRgbFloat(1.0, 1.0, 1.0, 0.0);

        const texture = if (image) |i| blk: { break :blk ((i.source orelse break :blk null).ensureGpuGet(.image, .{}) catch break :blk null).handle; } else null;
        const uv_pos: math.Vec2 = if (image) |i| i.crop.min else .zero;
        const uv_size: math.Vec2 = if (image) |i| i.crop.max.sub(i.crop.min) else .one;

        objs.append(alloc, .{
            .pos = pos.arr(),
            .size = size.arr(),
            .color = color.srgbDecode(),
            .texture = texture,
            .uv_pos = uv_pos.arr(),
            .uv_size = uv_size.arr(),
            .corners = if (corners) |c| blk: {
                const m = @min(size.x/2, size.y/2);
                break :blk .{
                    @min(c.top_left, m),
                    @min(c.top_right, m),
                    @min(c.bottom_left, m),
                    @min(c.bottom_right, m)
                };
            } else @splat(0),
            .borders = if (borders) |b| blk: {
                // Max, should probably be in a better place.
                const m = 100;
                break :blk .{
                    @min(b.top, m),
                    @min(b.bottom, m),
                    @min(b.left, m),
                    @min(b.right, m)
                };
            } else @splat(0),
            .border_color = if (borders) |b| b.color else .fromRgbFloat(0, 0, 0, 0)
        }) catch @panic("Out of memory");

        if (ui.world.getComponent(entity, cids.text, Ui.types.Text)) |txt| {
            if (ui.world.getComponent(entity, cids.computed_text_layout, Ui.types.ComputedTextLayout)) |ct| {
                if (txt.font) |f| if (f.ensureGpuGet(.font, .{}) catch null) |atlas| {
                    for (ct.quads) |quad| {
                        objs.append(alloc, .{
                            .pos = quad.pos,
                            .size = quad.size,
                            .color = txt.color.srgbDecode(),
                            .uv_pos = quad.uv_pos,
                            .uv_size = quad.uv_size,
                            .sampler = atlas.sampler.handle,
                            .texture = atlas.texture.handle,
                            .is_text = true,
                        }) catch @panic("Out of memory");
                    }
                };
            }
        }
    }

    for (entity.getChildren()) |child| {
        collectUiObjects(ui, child, objs, alloc);
    }
}

fn submitToRenderer(w: *ecs.World, ui: *Ui, renderer: *render.Renderer) void {
    const allocator = renderer.frame_allocator.allocator();

    const mesh_id = w.components.id("Mesh").?;
    const image_id = w.components.id("Image").?;
    const pos_id = w.components.id("Position").?;
    const rot_id = w.components.id("Rotation").?;
    const scale_id = w.components.id("Scale").?;
    const scene_id = w.components.id("Scene").?;
    const light_id = w.components.id("Light").?;
    const camera_id = w.components.id("Camera").?;

    var objects: std.ArrayList(render.types.RenderObject) = .empty;
    var lights: std.ArrayList(gpu.types.GpuLight) = .empty;

    var requests: std.ArrayList(render.types.RenderViewRequest) = .empty;

    // 3D world

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

        const rgb = l.color.srgbDecode();
        lights.append(allocator, .{
            .position_or_dir = pos_or_dir.arr(),
            .kind = @intFromEnum(l.kind),
            .color = .{ rgb.r, rgb.g, rgb.b },
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

        // This is so that if you have an image with no mesh, it's like a 2d plane in 3d space.
        // Could probably be convenient for 2D games, idk
        const mesh_data = if (mesh) |m| m.ensureGpuGet(.mesh, .{}) catch continue else renderer.default_quad;
        // Mesh with no image = plain white
        const image_data = if (image) |i| i.ensureGpuGet(.image, .{}) catch continue else renderer.default_image;
        
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

    const ui_cids = ui.component_ids;

    var window_lists: std.array_hash_map.Auto(u64, struct { id: u64, entity: ecs.Entity, objs: std.ArrayList(render.types.UiObject) }) = .{};
    {
        var it = ui.world.query(&.{ ui_cids.window }).iterator();
        while (it.next()) |e| {
            const win = ui.world.getComponent(e, ui_cids.window, Ui.types.Window).?;
            window_lists.put(allocator, e.toU64(), .{ .id = win.id, .entity = e, .objs = .empty }) catch @panic("Out of memory");
        }
    }

    // Collect RenderViews
    {
        const q =  ui.world.query(&.{ ui_cids.render_view });

        var it = q.iterator();
        while (it.next()) |entity| {
            const rv = ui.world.getComponent(entity, ui_cids.render_view, Ui.types.RenderViewOptions).?;
            if (!rv.camera.isAlive() or !rv.scene.isAlive()) continue;

            const root = rootOf(entity);
            const win = ui.world.getComponent(root, ui_cids.window, Ui.types.Window) orelse continue;
            const list = window_lists.getPtr(root.toU64()) orelse continue;

            const position = ui.world.getComponent(entity, ui_cids.computed_position, math.Vec2) orelse continue;
            const size = ui.world.getComponent(entity, ui_cids.computed_size, math.Vec2) orelse continue;

            const px: [2]u32 = .{
                @max(1, @as(u32, @intFromFloat(@round(size.x * win.scale)))),
                @max(1, @as(u32, @intFromFloat(@round(size.y * win.scale)))),
            };

            const view = renderer.getView(entity.toU64()) orelse
                (renderer.createView(entity.toU64(), px, rv.camera) catch |e| {
                    std.log.err("Failed to create view: {s}", .{ @errorName(e) });
                    continue;
                });

            view.resize(px) catch |e| {
                std.log.err("Failed to resize view: {s}", .{ @errorName(e) });
                continue;
            };

            const scene = w.getComponent(rv.scene, scene_id, Ui.types.Scene) orelse continue;
            const cam_settings = w.getComponent(rv.camera, camera_id, Camera) orelse continue;
            const cam_pos: math.Vec3 = if (w.getComponent(rv.camera, pos_id, math.Vec3)) |p| p.* else .zero;
            const cam_rot: math.Vec3 = if (w.getComponent(rv.camera, rot_id, math.Vec3)) |r| r.* else .zero;

            const view_mat = math.Mat4.fromTRS(cam_pos, .fromEuler(cam_rot.toRadians()), .one).invertRT();
            const proj: math.Mat4 = .perspectiveReversedZInf(
                std.math.degreesToRadians(cam_settings.fov),
                @as(f32, @floatFromInt(px[0])) / @as(f32, @floatFromInt(px[1])),
                cam_settings.near_plane,
            );

            requests.append(allocator, .{
                .frame = .{ .view_matrix = view_mat, .proj_matrix = proj, .viewport_size = px },
                .scene = .{ .ambient = scene.environment.ambient, .clear_color = scene.environment.clear_color,
                            .lights = lights.items, .objects = objects.items, .ui_objects = &.{} },
                .render_view_id = entity.toU64(),
            }) catch @panic("Out of memory");

            list.objs.append(allocator, .{
                .pos = position.arr(),
                .size = size.arr(),
                .texture = view.target.handle,
                .sampler = renderer.default_sampler.handle,
                .uv_size = @splat(1),
                .color = .fromRgbFloat(1, 1, 1, 1),
            }) catch @panic("Out of memory");
        }
    }

    var window_requests: std.ArrayList(render.types.RenderWindowRequest) = .empty;
    for (window_lists.values()) |*wl| {
        collectUiObjects(ui, wl.entity, &wl.objs, allocator);
        window_requests.append(allocator, .{ .window_id = wl.id, .ui_objects = wl.objs.items }) catch @panic("Out of memory");
    }

    renderer.render(requests.items, window_requests.items) catch |e| std.log.err("render() failed: {s}", .{ @errorName(e) });
}

fn submitToAudio(w: *ecs.World, audio: *Audio) void {
    const speaker_id = w.components.id("Speaker").?;
    const listener_id = w.components.id("AudioListener").?;
    const pos_id = w.components.id("Position").?;
    const rot_id = w.components.id("Rotation").?;

    const listener = blk: {
        var it = w.query(&.{ listener_id }).iterator();
        break :blk if (it.next()) |e| e else null;
    };
    const listener_pos: math.Vec3 = if (listener) |l| if (w.getComponent(l, pos_id, math.Vec3)) |p| p.* else .zero else .zero;
    const listener_rot: math.Vec3 = if (listener) |l| if (w.getComponent(l, rot_id, math.Vec3)) |r| r.* else .zero else .zero;
    const right = math.Quat.fromEuler(listener_rot.toRadians()).toMat4().transformDirection(.new(1, 0, 0)).normalize();
    audio.setListener(.{ .position = listener_pos, .right = right });

    for (0..Audio.max_voices) |i| {
        const index: u16 = @intCast(i);
        const state = audio.slot_state[index];
        if (state != .active and state != .reserved) continue;

        const t = &audio.tracks[index];
        const owner = t.owner orelse continue;
        const id = audio.getHandle(index).id;

        if (!owner.isAlive()) { audio.destroy(id); continue; }
        const speaker = w.getComponent(owner, speaker_id, Audio.Speaker) orelse {
            audio.destroy(id);
            continue;
        };

        if (state != .active) continue;

        audio.setParams(id, .{
            .position = if (w.getComponent(owner, pos_id, math.Vec3)) |p| p.* else null,
            .volume = t.volume * speaker.volume,
            .pitch = t.pitch,
            .loops = t.loops,
            .min_distance = speaker.min_distance,
            .max_distance = speaker.max_distance,
            .attenuation = speaker.attenuation,
        });
    }
}

pub fn main(init: std.process.Init) !void {
    var dba: std.heap.DebugAllocator(.{ .stack_trace_frames = 100 }) = .init;
    defer _ = &dba.detectLeaks();

    var tracked = core.TrackedAllocator.init(dba.allocator(), "Overall");
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

    var scheduler_allocator: core.TrackedAllocator = .init(allocator, "Scheduler");
    var scheduler: Scheduler = undefined;
    try scheduler.init(scheduler_allocator.allocator(), io, &os);

    var platform_allocator: core.TrackedAllocator = .init(allocator, "Platform");
    var platform: Platform = undefined;
    try platform.init(platform_allocator.allocator(), .initSdl());

    var ui_allocator: core.TrackedAllocator = .init(allocator, "Ui");
    var ui: Ui = try .init(ui_allocator.allocator());

    var input_allocator: core.TrackedAllocator = .init(allocator, "Input");
    var input: Input = undefined;
    try input.init(input_allocator.allocator(), &platform, &ui);

    var gpu_allocator: core.TrackedAllocator = .init(allocator, "Gpu");
    var gpu_device: gpu.GpuDevice = try .init(gpu_allocator.allocator(), .initDiligent());

    var asset_allocator: core.TrackedAllocator = .init(allocator, "Assets");
    var assets: engine.Assets = try .init(asset_allocator.allocator(), io, &gpu_device, project_path);
    
    // Skybox
    const skybox_cubemap = try assets.load("assets://images/skybox_island.png");
    try skybox_cubemap.upload(.{ .is_cubemap = true });

    var renderer_allocator: core.TrackedAllocator = .init(allocator, "Renderer");
    var renderer: render.Renderer = try .init(renderer_allocator.allocator(), &gpu_device, try skybox_cubemap.gpuGet(.image));

    // Create the world
    var ecs_allocator: core.TrackedAllocator = .init(allocator, "ECSWorld");
    var world: ecs.World = .init(ecs_allocator.allocator());

    var audio: Audio = undefined;
    try audio.init(io, allocator, &platform);

    var lua_allocator: core.TrackedAllocator = .init(allocator, "LuaRuntime");
    var host: scripting.bind.Host = .{ .world = &world, .assets = &assets, .input = &input, .ui = &ui, .audio = &audio };
    var runtime: scripting.Runtime = try .init(lua_allocator.allocator(), &host);

    var windows: std.AutoHashMap(u64, WindowInfo) = .init(allocator);
    const window_entity = try openWindow(&platform, &renderer, &ui, &windows, "crystal", 1280, 720);
    const window_entity_2 = try openWindow(&platform, &renderer, &ui, &windows, "crystal 2", 854, 480);
    ui.main_window = window_entity;

    defer { 
        world.deinit();
        ui.deinit();
        audio.deinit();
        renderer.deinit();
        gpu_device.deinit();
        input.deinit();
        scheduler.deinit();
        runtime.deinit();
        assets.deinit();

        var win_iter = windows.valueIterator();
        while (win_iter.next()) |i| platform.destroySurface(i.surface);
        windows.deinit();
        platform.deinit();
    }
    
    // Register components
    // TODO: Register these once somewhere, and access them there
    // instead of having to do world.components.id() over and over again.
    const scene_component = try world.registerComponent(Ui.types.Scene, "Scene"); // For organizing collections of entities
    _ = try world.registerComponent(engine.Assets.AssetHandle, "Mesh"); // For giving an entity a mesh appearance
    _ = try world.registerComponent(engine.Assets.AssetHandle, "Image"); // For giving an entity an image appearance (or a texture, if it has a mesh)
    const pos_component = try world.registerComponent(math.Vec3, "Position"); // For moving entities
    const rot_component = try world.registerComponent(math.Vec3, "Rotation"); // For rotating entites (Euler)
    const scale_component = try world.registerComponent(math.Vec3, "Scale"); // For scaling entities
    const script_component = try world.registerComponent(scripting.Script, "Script"); // For giving entities behavior
    const light_component = try world.registerComponent(render.types.Light, "Light"); // For creating sources of illumination
    _ = try world.registerComponent([]const u8, "Name"); // For naming an entity (we don't use it, but lua does)
    const listener_component = try world.registerComponent(Audio.types.AudioListener, "AudioListener");
    _ = try world.registerComponent(Audio.Speaker, "Speaker");
    const camera_component = try world.registerComponent(Camera, "Camera");

    // Create a scene inside of the world
    const scene = try world.spawnEntity();

    // Make a camera for the scene
    const camera = try world.spawnEntity();
    try world.set(camera, pos_component, math.Vec3, .new(0, 0, 0));
    try world.set(camera, rot_component, math.Vec3, .new(0, 0, 0));
    try world.set(camera, scale_component, math.Vec3, .new(1, 1, 1));
    try world.set(camera, listener_component, Audio.types.AudioListener, .{});
    try world.set(camera, camera_component, Camera, .{});

    const camera_2 = try world.spawnEntity();
    try world.set(camera_2, pos_component, math.Vec3, .new(0, 0, 0));
    try world.set(camera_2, rot_component, math.Vec3, .new(0, 0, 0));
    try world.set(camera_2, scale_component, math.Vec3, .new(1, 1, 1));
    try world.set(camera_2, camera_component, Camera, .{});

    // Camera script
    {
        const source = try assets.load("assets://scripts/camera.luau");
        defer source.cpuRelease();
        const script = try runtime.loadScript(try source.cpuGet(.script_source));

        try world.set(camera, script_component, scripting.Script, script);
        const stored_script = world.getComponent(camera, script_component, scripting.Script).?;
        stored_script.instantiate(camera) catch |e| {
            std.log.err("Failed to instantiate camera script: {s}", .{ @errorName(e) });
        };
    }

    try world.set(scene, scene_component, Ui.types.Scene, .{});

    // Spawn a new entity
    const entity = try world.spawnEntity();

    const light = try world.spawnEntity();
    try world.set(light, light_component, render.types.Light, .{
        .color = .fromRgbFloat(1.0, 1.0, 1.0, 1.0),
        .intensity = 5,
        .kind = .{ .point = .{ .radius = 10 } }
    });
    try world.set(light, pos_component, math.Vec3, .zero);
    try light.setParent(scene);

    // Parent the component under the scene
    try entity.setParent(scene);

    // Add a script to the component
    const source = try assets.load("assets://scripts/teapot.luau");
    defer source.cpuRelease();
    const script = try runtime.loadScript(try source.cpuGet(.script_source));

    try world.set(entity, script_component, scripting.Script, script);
    const stored_script = world.getComponent(entity, script_component, scripting.Script).?;
    stored_script.instantiate(entity) catch |e| {
        std.log.err("Failed to instantiate entity script: {s}", .{ @errorName(e) });
    };

    // Render at logical size for 3D, while UI renders at pixel size to stay crisp.
    const view_entity = try ui.world.spawnEntity();
    try ui.world.set(view_entity, ui.component_ids.render_view, Ui.types.RenderViewOptions, .{ .camera = camera, .scene = scene });
    try ui.world.set(view_entity, ui.component_ids.position, math.Vec2, .new(0, 0));
    try ui.world.set(view_entity, ui.component_ids.size, Ui.types.SizeMode, .{ .width = .fill, .height = .fill });
    try view_entity.setParent(window_entity);

    const view_entity_2 = try ui.world.spawnEntity();
    try ui.world.set(view_entity_2, ui.component_ids.render_view, Ui.types.RenderViewOptions, .{ .camera = camera_2, .scene = scene });
    try ui.world.set(view_entity_2, ui.component_ids.position, math.Vec2, .new(0, 0));
    try ui.world.set(view_entity_2, ui.component_ids.size, Ui.types.SizeMode, .{ .width = .fill, .height = .fill });
    try view_entity_2.setParent(window_entity_2);

    var running = true;

    var context = .{ &running, &platform, &renderer, &ui, &windows };
    const event_con = try platform.platform_event.connect(struct {
        fn c(ctx: anytype, e: Platform.desc.PlatformEvent) void {
            switch (e) {
                .quit => ctx[0].* = false,
                .surface_resize => |evt| syncWindow(ctx[1], ctx[2], ctx[3], ctx[4], evt.id),

                else => {}
            }
        }
    }.c, &context);
    defer event_con.disconnect();

    var last_time = std.Io.Clock.awake.now(io);
    var last_asset_tick = std.Io.Clock.awake.now(io);
    while (running) {
        const start = std.Io.Clock.awake.now(io);
        const dt = last_time.durationTo(start);
        const dt_seconds: f32 = @floatCast(@as(f32, @floatFromInt(dt.toNanoseconds())) / std.time.ns_per_s);
        last_time = start;

        audio.tick();
        input.tick();
        platform.poll();
        world.update(dt_seconds);
        ui.update();
        submitToRenderer(&world, &ui, &renderer);
        submitToAudio(&world, &audio);

        const end = std.Io.Clock.awake.now(io);

        if (end.nanoseconds > last_asset_tick.addDuration(asset_purge_rate_seconds).nanoseconds) {
            const purged = assets.tick();
            last_asset_tick = end;

            if (purged > 0) std.log.debug("Purged {d} assets", .{ purged });
            // std.log.info("-----Allocators ({f} tracked, {f} total)-----", .{ core.SizeFormatter.fmtSize( 
            //     scheduler_allocator.currentUsage() +
            //     platform_allocator.currentUsage() +
            //     input_allocator.currentUsage() +
            //     renderer_allocator.currentUsage() +
            //     ui_allocator.currentUsage() +
            //     lua_allocator.currentUsage() + 
            //     asset_allocator.currentUsage() + 
            //     ecs_allocator.currentUsage() +
            //     gpu_allocator.currentUsage()
            // ), core.SizeFormatter.fmtSize(tracked.currentUsage()) });

            // std.log.info("{f}", .{ scheduler_allocator });
            // std.log.info("{f}", .{ platform_allocator });
            // std.log.info("{f}", .{ input_allocator });
            // std.log.info("{f}", .{ renderer_allocator });
            // std.log.info("{f}", .{ ui_allocator });
            // std.log.info("{f}", .{ lua_allocator });
            // std.log.info("{f}", .{ asset_allocator });
            // std.log.info("{f}", .{ ecs_allocator });
            // std.log.info("{f}", .{ gpu_allocator });

            // std.log.info("[Lua GC]: {f}", .{core.SizeFormatter.fmtSize( @as(u64, @intCast(runtime.gcCount())) * 1024) });
        }
    }
}
