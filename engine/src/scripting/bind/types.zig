// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");

pub const BindError = error { BadArg, Engine, Destroyed };
pub const Kind = enum { func, constant, prop, value, handle, object, module, globals };
pub const Member = struct { name: [:0]const u8, kind: Kind, impl: type };

pub const Op = union(enum) { auto, member: Member };
pub const Ops = struct {
    add: ?Op = null, sub: ?Op = null, mul: ?Op = null, div: ?Op = null,
    unm: ?Op = null, eq: ?Op = null, lt: ?Op = null, le: ?Op = null,
    len: ?Op = null, tostring: ?Op = null,
    index: ?Op = null, newindex: ?Op = null
};

pub const Diag = struct {
    buf: [256]u8 = undefined,
    len: usize = 0,

    pub fn fail(self: *Diag, comptime fmt: []const u8, args: anytype) BindError {
        const out = std.fmt.bufPrint(self.buf[0..self.buf.len-1], fmt, args) catch self.buf[0..self.buf.len-1];
        self.len = out.len;
        self.buf[out.len] = 0;
        
        return error.BadArg;
    }
    pub fn z(self: *Diag) [:0]const u8 { return self.buf[0..self.len :0]; }
};
