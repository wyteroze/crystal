// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const shd = @import("shaders");
const types = @import("types.zig");
const Renderer = @import("Renderer.zig");
const gfx = @import("sokol").gfx;

pub fn basic(r: *Renderer) types.ShaderHandle {
    return r.createShader(shd.basicShaderDesc(gfx.queryBackend()));
}
