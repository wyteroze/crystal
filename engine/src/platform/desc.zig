// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const SurfaceDesc = struct {
    title: [:0]const u8,
    width: u32,
    height: u32,
    target: enum { primary, secondary }
};

pub const PlatformEvent = union(enum) {
    quit: void,
    surface_resize: struct { width: u32, height: u32 },

};
