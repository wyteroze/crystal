// Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.

const std = @import("std");
const zlua = @import("zlua");
const shared = @import("shared.zig");
const types = @import("../types.zig");
const Lua = zlua.Lua;
const Vec2_SIMD = types.Vec2_SIMD;
const Vec3_SIMD = types.Vec3_SIMD;
const LuaTypeTag = shared.LuaTypeTag;
