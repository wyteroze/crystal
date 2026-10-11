// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const ecs = @import("../../ecs/ecs.zig");
const Assets = @import("../../assets/Assets.zig");
const Input = @import("../../input/Input.zig");
const Ui = @import("../../ui/Ui.zig");
const Audio = @import("../../audio/Audio.zig");

var key: u8 = 0;
const Host = @This();
// These are singletons that need a way
// to access themselves from Lua calls. They do
// `Runtime.fromState(l).binder` and access themselves.
world: *ecs.World, 
assets: *Assets, 
input: *Input, 
ui: *Ui, 
audio: *Audio,

pub fn attach(self: *Host, l: *zlua.Lua) void {
    l.pushLightUserdata(self);
    l.setPtrRaw(zlua.registry_index, &key);
}

pub fn fromState(l: *zlua.Lua) *Host {
    _ = l.getPtrRaw(zlua.registry_index, &key);
    defer l.pop(1);
    
    return l.toUserdata(Host, -1) catch unreachable;
}