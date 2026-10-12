// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const util = @import("util.zig");
const types = @import("types.zig");

pub const ValueRecipe = struct {
    name: ?[:0]const u8 = null,
    mutable: bool = false,
    fields: []const [:0]const u8 = &.{},
    props: []const types.Member = &.{},
    statics: []const types.Member = &.{},
    methods: []const types.Member = &.{},
    signals: []const types.Member = &.{},
    ops: types.Ops = .{}
};

pub const HandleRecipe = struct {
    name: ?[:0]const u8 = null,
    /// For handles that Lua doesn't own. This is called when used to ensure the handle is alive.
    alive: ?types.Member = null,
    /// For handles that Lua owns. This is called on garbage-collection.
    release: ?types.Member = null,
    props: []const types.Member = &.{},
    statics: []const types.Member = &.{},
    methods: []const types.Member = &.{},
    signals: []const types.Member = &.{},
    ops: types.Ops = .{},
};

pub const ObjectRecipe = struct {
    name: ?[:0]const u8 = null,
    retain: ?types.Member = null, 
    release: ?types.Member = null,
    identity: bool = false,
    props: []const types.Member = &.{}, 
    statics: []const types.Member = &.{}, 
    methods: []const types.Member = &.{},
    signals: []const types.Member = &.{},
    ops: types.Ops = .{},
};

pub const RecordRecipe = struct {
    name: ?[:0]const u8 = null,
    handle: ?type = null,
};

pub const ModuleRecipe = struct {
    kind: union(enum) { library, singleton: type } = .library,
    members: []const types.Member = &.{},
    signals: []const types.Member = &.{},
};

pub const GlobalsRecipe = struct {
    members: []const types.Member = &.{},
};