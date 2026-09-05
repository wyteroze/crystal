// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const builtin = @import("builtin");
const Fiber = @import("../Fiber.zig");

pub const Registers = extern struct {
    sp: usize = 0,
    x18: usize = 0, // thanks apple
    x19: usize = 0, x20: usize = 0, x21: usize = 0, x22: usize = 0, x23: usize = 0, 
    x24: usize = 0, x25: usize = 0, x26: usize = 0, x27: usize = 0, x28: usize = 0,
    fp: usize = 0,
    lr: usize = 0,
    d8: u64 = 0, d9: u64 = 0, d10: u64 = 0, d11: u64 = 0, d12: u64 = 0, d13: u64 = 0,
    d14: u64 = 0, d15: u64 = 0,
};

pub fn swap(_: *Registers, _: *Registers) callconv(.naked) void {
    asm volatile (
        // x0 = from, x1 = to
        \\ mov x9, sp
        \\ str x9,  [x0, #0x00]
        \\ str x18, [x0, #0x08]
        \\ stp x19, x20, [x0, #0x10]
        \\ stp x21, x22, [x0, #0x20]
        \\ stp x23, x24, [x0, #0x30]
        \\ stp x25, x26, [x0, #0x40]
        \\ stp x27, x28, [x0, #0x50]
        \\ stp x29, x30, [x0, #0x60]
        \\ stp d8,  d9,  [x0, #0x70]
        \\ stp d10, d11, [x0, #0x80]
        \\ stp d12, d13, [x0, #0x90]
        \\ stp d14, d15, [x0, #0xa0]
        \\
        \\ ldr x9,  [x1, #0x00]
        \\ mov sp, x9
        \\ ldr x18, [x1, #0x08]
        \\ ldp x19, x20, [x1, #0x10]
        \\ ldp x21, x22, [x1, #0x20]
        \\ ldp x23, x24, [x1, #0x30]
        \\ ldp x25, x26, [x1, #0x40]
        \\ ldp x27, x28, [x1, #0x50]
        \\ ldp x29, x30, [x1, #0x60]
        \\ ldp d8,  d9,  [x1, #0x70]
        \\ ldp d10, d11, [x1, #0x80]
        \\ ldp d12, d13, [x1, #0x90]
        \\ ldp d14, d15, [x1, #0xa0]
        \\ ret
    );
}

// shit gets fucked badly if this is ever inlined
pub noinline fn doSwap(from: *Registers, to: *Registers) void {
    const sym = comptime if (builtin.target.os.tag.isDarwin()) "bl _swap" else "bl swap";
    asm volatile (sym
        :
        : [from] "{x0}" (from), [to] "{x1}" (to)
        : .{
            .x0 = true, .x1 = true, .x9 = true,
            .x19 = true, .x20 = true, .x21 = true, .x22 = true,
            .x23 = true, .x24 = true, .x25 = true, .x26 = true,
            .x27 = true, .x28 = true, .x29 = true, .lr = true,
            .d8 = true, .d9 = true, .d10 = true, .d11 = true,
            .d12 = true, .d13 = true, .d14 = true, .d15 = true,
            .memory = true
        }
    );
}

pub fn trampoline() callconv(.naked) noreturn {
    asm volatile (
        \\ mov x0, x19
        \\ bl %[land]
        :
        : [land] "X" (&Fiber.trampolineLand)
    );
}

pub inline fn readx18() usize {
    return asm volatile ("mov %[out], x18"
        : [out] "=r" (-> usize)
    );
}

pub fn initRegs(sp: usize, self: *anyopaque) Registers {
    return .{
        .sp = sp,
        .x18 = readx18(),
        .lr = @intFromPtr(&trampoline),
        .x19 = @intFromPtr(self)
    };
}