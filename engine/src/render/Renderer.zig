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
pub const max_lights = 256;
pub const tile_size = 16;
pub const max_lights_per_tile = 256;

const Renderer = @This();
allocator: std.mem.Allocator,
/// Freed at the end of every frame. Always use this instead
/// of a regular allocator when possible because it's way faster.
frame_allocator: std.heap.ArenaAllocator,
gpu_device: *gpu.GpuDevice,
scene_graph: RenderGraph,
ui_graph: RenderGraph,
default_sampler: gpu.GpuDevice.GpuSampler,
default_image: gpu.GpuDevice.GpuImage,
default_quad: assets.types.GpuMesh,
lights_ssbo: gpu.GpuDevice.GpuBuffer,
render_views: std.AutoHashMap(u64, RenderView),
windows: std.AutoHashMap(u64, types.RenderWindow),

pub fn init(allocator: std.mem.Allocator, gpu_device: *gpu.GpuDevice, skybox_cubemap: gpu.GpuDevice.GpuImage) !Renderer {
    var scene_graph: RenderGraph = .init(allocator);
    errdefer scene_graph.deinit();
    var ui_graph: RenderGraph = .init(allocator);
    errdefer ui_graph.deinit();

    const depth_shader = try gpu_device.createShader(gpu.shaders.depthPrepassShaderDesc());
    const depth_prepass = try allocator.create(pass.DepthPrepassPass);
    errdefer allocator.destroy(depth_prepass);
    depth_prepass.* = try .init(gpu_device, depth_shader);

    const skybox_shader = try gpu_device.createShader(gpu.shaders.skyboxShaderDesc());
    const skybox_pass = try allocator.create(pass.SkyboxPass);
    errdefer allocator.destroy(skybox_pass);
    skybox_pass.* = try .init(gpu_device, skybox_shader, skybox_cubemap);

    const light_cull_shader = try gpu_device.createShader(gpu.shaders.lightCullShaderDesc());
    const light_cull_pass = try allocator.create(pass.LightCullPass);
    errdefer allocator.destroy(light_cull_pass);
    light_cull_pass.* = try .init(gpu_device, light_cull_shader);

    const forward_shader = try gpu_device.createShader(gpu.shaders.basicShaderDesc());
    const forward_pass = try allocator.create(pass.ForwardPass);
    errdefer allocator.destroy(forward_pass);
    forward_pass.* = try .init(gpu_device, forward_shader);

    const ui_shader = try gpu_device.createShader(gpu.shaders.uiShaderDesc());
    const ui_pass = try allocator.create(pass.UiPass);
    errdefer allocator.destroy(ui_pass);
    ui_pass.* = try .init(gpu_device, ui_shader);

    try scene_graph.addNode(depth_prepass.node());
    try scene_graph.addNode(skybox_pass.node());
    try scene_graph.addNode(light_cull_pass.node());
    try scene_graph.addNode(forward_pass.node());
    try scene_graph.markExternal(resource.lights_buffer);
    try scene_graph.markExternal(resource.default_sampler);
    try scene_graph.markExternal(resource.default_image);
    try scene_graph.markExternal(resource.color_target);
    try scene_graph.markExternal(resource.depth_buffer);
    try scene_graph.markExternal(resource.depth_texture);
    try scene_graph.markExternal(resource.light_grid);
    try scene_graph.markExternal(resource.light_index_list);
    try scene_graph.compile();

    try ui_graph.addNode(ui_pass.node());
    try ui_graph.markExternal(resource.color_target);
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
        .windows = .init(allocator),
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
    };
}

pub fn deinit(self: *Renderer) void {
    var win_iter = self.windows.valueIterator();
    while (win_iter.next()) |win| win.swapchain.deinit();
    var rv_iter = self.render_views.valueIterator();
    while (rv_iter.next()) |rv| rv.deinit();
    
    self.windows.deinit();
    self.render_views.deinit();
    self.lights_ssbo.deinit();
    self.scene_graph.deinit();
    self.ui_graph.deinit();
    self.default_sampler.deinit();
    self.default_image.deinit();
    self.default_quad.deinit();
    self.frame_allocator.deinit();
}

pub fn render(self: *Renderer, views: []const types.RenderViewRequest, windows: []types.RenderWindowRequest) !void {
    for (views) |req| {
        std.debug.assert(req.scene.lights.len <= max_lights);
        self.lights_ssbo.update(std.mem.sliceAsBytes(req.scene.lights));

        const rv = self.getView(req.render_view_id) orelse continue;

        self.scene_graph.resources.map.clearRetainingCapacity();
        try self.scene_graph.resources.put(resource.lights_buffer, .{ .storage_buffer = self.lights_ssbo.handle });
        try self.scene_graph.resources.put(resource.depth_buffer, .{ .depth_target = rv.depth.depthTarget() });
        try self.scene_graph.resources.put(resource.depth_texture, .{ .image = rv.depth.handle });
        try self.scene_graph.resources.put(resource.color_target, .{ .render_target = rv.target.renderTarget() });
        try self.scene_graph.resources.put(resource.light_grid, .{ .storage_buffer = rv.light_grid.handle });
        try self.scene_graph.resources.put(resource.light_index_list, .{ .storage_buffer = rv.light_index_list.handle });
        try self.scene_graph.resources.put(resource.default_image, .{ .image = self.default_image.handle });
        try self.scene_graph.resources.put(resource.default_sampler, .{ .sampler = self.default_sampler.handle });

        const ctx: pass.PassContext = .{
            .device = self.gpu_device,
            .view = &req.frame,
            .scene = &req.scene,
            .resources = &self.scene_graph.resources,
            .frame_allocator = self.frame_allocator.allocator()
        };

        self.scene_graph.execute(ctx);
    }

    var rendered: std.ArrayList(*types.RenderWindow) = .empty;

    for (windows) |req| {
        const win = self.getWindow(req.window_id) orelse continue;
        if (win.pixel_size[0] == 0 or win.pixel_size[1] == 0) continue;
        rendered.append(self.frame_allocator.allocator(), win) catch {};

        const scene: types.RenderScene = .{
            .ui_objects = req.ui_objects,
            .objects = &.{},
            .lights = &.{}
        };
        const frame: types.RenderFrame = .{
            .view_matrix = .identity,
            .proj_matrix = .identity,
            .viewport_size = win.pixel_size,
            .scale = win.scale
        };

        self.ui_graph.resources.map.clearRetainingCapacity();
        try self.ui_graph.resources.put(resource.color_target, .{ .render_target = win.swapchain.getBackbuffer() });
        try self.ui_graph.resources.put(resource.default_image, .{ .image = self.default_image.handle });
        try self.ui_graph.resources.put(resource.default_sampler, .{ .sampler = self.default_sampler.handle });

        self.ui_graph.execute(.{
            .device = self.gpu_device,
            .view = &frame,
            .scene = &scene,
            .resources = &self.ui_graph.resources,
            .frame_allocator = self.frame_allocator.allocator()
        });
    }

    for (rendered.items) |w| w.swapchain.present(w.vsync);

    if (!self.frame_allocator.reset(.retain_capacity)) std.log.err("Frame allocator reset failed", .{});
}

// RenderView

pub fn createView(self: *Renderer, id: u64, size: [2]u32, camera: ecs.Entity) !*RenderView {
    try self.render_views.put(id, try .init(self, size, id, camera));

    return self.render_views.getPtr(id).?;
}

pub fn getView(self: *Renderer, id: u64) ?*RenderView {
    return self.render_views.getPtr(id);
}

pub fn destroyView(self: *Renderer, id: u64) void {
    const view = self.render_views.fetchRemove(id) orelse return;
    view.value.deinit();
}

pub fn resizeView(self: *Renderer, id: u64, size: [2]u32) !void {
    const view = self.render_views.getPtr(id) orelse return error.InvalidRenderViewId;
    try view.resize(size);
}

// RenderWindow

pub fn createWindow(self: *Renderer, id: u64, handle: *anyopaque, pixel_size: [2]u32, scale: f32) !void {
    const sc = try self.gpu_device.createSwapchain(.{ .surface_handle = handle, .size = pixel_size });
    try self.windows.put(id, .{ .swapchain = sc, .pixel_size = pixel_size, .scale = scale });
}

pub fn getWindow(self: *Renderer, id: u64) ?*types.RenderWindow {
    return self.windows.getPtr(id);
}

pub fn resizeWindow(self: *Renderer, id: u64, pixel_size: [2]u32, scale: f32) !void {
    const w = self.windows.getPtr(id) orelse return error.InvalidWindowId;
    try w.resize(pixel_size, scale);
}

pub fn destroyWindow(self: *Renderer, id: u64) !void {
    const w = self.windows.fetchRemove(id) orelse return error.InvalidWindowId;
    w.value.swapchain.deinit();
}