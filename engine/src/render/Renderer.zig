// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const gpu = @import("../gpu/gpu.zig");
const ecs = @import("../ecs/ecs.zig");
const assets = @import("../assets/Assets.zig");
const types = @import("types.zig");
const core = @import("../core/core.zig");
const RenderGraph = @import("RenderGraph.zig");
const RenderView = @import("RenderView.zig");
const resource = @import("resource.zig");
const pass = @import("pass/pass.zig");
const math = core.math;
const Color = core.Color;

// Max size of the lights ssbo. In the future
// the buffer should be able to resize, so this
// would be unneeded.
const max_lights = 256;

const Renderer = @This();
allocator: std.mem.Allocator,
/// Freed at the end of every frame. Always use this instead
/// of a regular allocator when possible because it's way faster.
frame_allocator: std.heap.ArenaAllocator,
gpu_device: *gpu.GpuDevice,
scene_graph: RenderGraph,
ui_graph: RenderGraph,
default_sampler: gpu.GpuDevice.GpuSampler,
surface_pixel_size: [2]u32,
surface_logical_size: [2]u32,
surface_scale: f32,
default_image: gpu.GpuDevice.GpuImage,
default_quad: assets.types.GpuMesh,
lights_ssbo: gpu.GpuDevice.GpuBuffer,
depth_image: gpu.GpuDevice.GpuImage,
render_views: std.AutoHashMap(u64, RenderView),

pub fn init(allocator: std.mem.Allocator, surface_pixel_size: [2]u32, surface_logical_size: [2]u32, surface_scale: f32, gpu_device: *gpu.GpuDevice, skybox_cubemap: gpu.GpuDevice.GpuImage) !Renderer {
    var scene_graph: RenderGraph = .init(allocator);
    errdefer scene_graph.deinit();
    var ui_graph: RenderGraph = .init(allocator);
    errdefer ui_graph.deinit();

    const clear_color: core.Color = .fromRgbFloat(0.1, 0.1, 0.1, 1.0);

    const depth_shader = try gpu_device.createShader(gpu.shaders.depthPrepassShaderDesc());
    const depth_prepass = try allocator.create(pass.DepthPrepassPass);
    errdefer allocator.destroy(depth_prepass);
    depth_prepass.* = try .init(gpu_device, depth_shader, clear_color);

    const skybox_shader = try gpu_device.createShader(gpu.shaders.skyboxShaderDesc());
    const skybox_pass = try allocator.create(pass.SkyboxPass);
    errdefer allocator.destroy(skybox_pass);
    skybox_pass.* = try .init(gpu_device, skybox_shader, skybox_cubemap);

    const light_cull_shader = try gpu_device.createShader(gpu.shaders.lightCullShaderDesc());
    const light_cull_pass = try allocator.create(pass.LightCullPass);
    errdefer allocator.destroy(light_cull_pass);
    light_cull_pass.* = try .init(gpu_device, light_cull_shader, surface_logical_size);

    const forward_shader = try gpu_device.createShader(gpu.shaders.basicShaderDesc());
    const forward_pass = try allocator.create(pass.ForwardPass);
    errdefer allocator.destroy(forward_pass);
    forward_pass.* = try .init(gpu_device, forward_shader, clear_color);

    const ui_shader = try gpu_device.createShader(gpu.shaders.uiShaderDesc());
    const ui_pass = try allocator.create(pass.UiPass);
    errdefer allocator.destroy(ui_pass);
    ui_pass.* = try .init(gpu_device, ui_shader, surface_pixel_size, surface_scale);

    try scene_graph.addNode(depth_prepass.node());
    try scene_graph.addNode(skybox_pass.node());
    try scene_graph.addNode(light_cull_pass.node());
    try scene_graph.addNode(forward_pass.node());
    try scene_graph.markExternal(resource.lights_buffer);
    try scene_graph.markExternal(resource.default_sampler);
    try scene_graph.markExternal(resource.default_image);
    try scene_graph.markExternal(resource.color_target);
    try scene_graph.compile();

    try ui_graph.addNode(ui_pass.node());
    try ui_graph.markExternal(resource.default_sampler);
    try ui_graph.markExternal(resource.default_image);
    try ui_graph.compile();

    return .{ 
        .allocator = allocator, 
        .frame_allocator = .init(allocator),
        .render_views = .init(allocator),
        .gpu_device = gpu_device,
        .scene_graph = scene_graph,
        .ui_graph = ui_graph,
        .default_sampler = try gpu_device.createSampler(.{}),
        .surface_pixel_size = surface_pixel_size,
        .surface_logical_size = surface_logical_size,
        .surface_scale = surface_scale,
        .default_image = try gpu_device.createImage(.{
            .name = "Default image",
            .width = 1, .height = 1,
            .format = .rgba8,
            .data = &.{ 0xFF, 0xFF, 0xFF, 0xFF }
        }),
        .default_quad = .{
            .vertex_buffer = try gpu_device.createBuffer(.{
                .name = "Default quad vertex buffer",
                .data = std.mem.sliceAsBytes(([_]assets.types.Vertex{
                    .{ .position = .{ -0.5,  0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 0 } },
                    .{ .position = .{  0.5,  0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 0 } },
                    .{ .position = .{ -0.5, -0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 0, 1 } },
                    .{ .position = .{  0.5, -0.5, 0 }, .normal = .{ 0, 0, 1 }, .uv = .{ 1, 1 } },
                })[0..]),
                .size = 4,
            }),
            .index_buffer = try gpu_device.createBuffer(.{
                .name = "Default quad index buffer",
                .type = .index,
                .data = std.mem.sliceAsBytes(([_]u32{
                    0, 2, 1,
                    1, 2, 3
                })[0..])
            }),
            .vertex_count = 4,
            .index_count = 6
        },
        .lights_ssbo = try gpu_device.createBuffer(.{
            .name = "Lights storage buffer",
            .type = .storage,
            .usage = .default,
            .size = max_lights * @sizeOf(gpu.types.GpuLight),
            .stride = @sizeOf(gpu.types.GpuLight)
        }),
        .depth_image = try gpu_device.createImage(.{
            .name = "Depth buffer",
            .width = surface_logical_size[0],
            .height = surface_logical_size[1],
            .format = .d32
        }),
    };
}

pub fn deinit(self: *Renderer) void {
    var rv_iter = self.render_views.valueIterator();
    while (rv_iter.next()) |rv| rv.deinit();
    
    self.scene_graph.deinit();
    self.ui_graph.deinit();
    self.default_sampler.deinit();
    self.default_image.deinit();
    self.default_quad.deinit();
    self.frame_allocator.deinit();
    self.depth_image.deinit();
    self.render_views.deinit();
}

pub fn render(self: *Renderer, views: []const types.RenderViewRequest, ui_objects: []types.UiObject) !void {
    for (views) |req| {
        std.debug.assert(req.scene.lights.len <= max_lights);
        self.lights_ssbo.update(std.mem.sliceAsBytes(req.scene.lights));

        self.scene_graph.resources.map.clearRetainingCapacity();
        try self.scene_graph.resources.put(resource.lights_buffer, .{ .storage_buffer = self.lights_ssbo.handle });
        try self.scene_graph.resources.put(resource.depth_buffer, .{ .image = self.depth_image.handle });
        try self.scene_graph.resources.put(resource.default_image, .{ .image = self.default_image.handle });
        try self.scene_graph.resources.put(resource.default_sampler, .{ .sampler = self.default_sampler.handle });
        if (req.target) |t| try self.scene_graph.resources.put(resource.color_target, .{ .image = t });

        const ctx: pass.PassContext = .{
            .device = self.gpu_device,
            .view = &req.frame,
            .scene = &req.scene,
            .resources = &self.scene_graph.resources,
            .frame_allocator = self.frame_allocator.allocator()
        };

        self.scene_graph.execute(ctx);
    }
    
    const ui_scene: types.RenderScene = .{ .ui_objects = ui_objects, .objects = &.{}, .lights = &.{} };
    const ui_frame: types.RenderFrame = .{ .view_matrix = .identity, .proj_matrix = .identity, .viewport_size = self.surface_pixel_size };

    self.ui_graph.resources.map.clearRetainingCapacity();
    try self.ui_graph.resources.put(resource.default_image, .{ .image = self.default_image.handle });
    try self.ui_graph.resources.put(resource.default_sampler, .{ .sampler = self.default_sampler.handle });

    const ui_ctx: pass.PassContext = .{
        .device = self.gpu_device,
        .view = &ui_frame,
        .scene = &ui_scene,
        .resources = &self.ui_graph.resources,
        .frame_allocator = self.frame_allocator.allocator()
    };
    self.ui_graph.execute(ui_ctx);

    self.gpu_device.present();
    if (!self.frame_allocator.reset(.retain_capacity)) std.log.err("Frame allocator reset failed", .{});
}

pub fn createView(self: *Renderer, id: u64, size: [2]u32, camera: ecs.Entity) !RenderView {
    // Zero-sized RenderViews are not allowed by the GPU.
    std.debug.assert(size[0] > 0 and size[1] > 0);
    const rv: RenderView = try .init(self, size, id, camera);
    try self.render_views.put(id, rv);

    return rv;
}

pub fn getView(self: *Renderer, id: u64) ?RenderView {
    return self.render_views.get(id);
}

pub fn destroyView(self: *Renderer, id: u64) void {
    const view = self.render_views.fetchRemove(id) orelse return;
    view.value.deinit();
}