// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const program = @import("shaders");
const Renderer = @import("Renderer.zig");
const gfx = @import("sokol").gfx;

// Export shader stuff
pub fn basicShaderDesc() gfx.ShaderDesc {
    return program.basicShaderDesc(gfx.queryBackend());
}
