// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

pub const SurfaceHandle = struct { id: usize, handle: ?*anyopaque };
pub const AudioStreamHandle = struct { handle: *anyopaque };
pub const AudioDeviceHandle = struct { id: u32 };