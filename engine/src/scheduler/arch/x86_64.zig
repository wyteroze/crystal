// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const builtin = @import("builtin");
const Fiber = @import("../Fiber.zig");

pub const Registers = extern struct {
    sp: usize = 0,
    rbx: usize = 0, rbp: usize = 0,
    r12: usize = 0, r13: usize = 0, r14: usize = 0, r15: usize = 0,
    ip: usize = 0
};

pub fn swap(_: *Registers, _: *Registers) callconv(.naked) void {
    asm volatile (
        // rdi = from, rsi = to
        \\ mov %%rsp, 0x00(%%rdi)
        \\ mov %%rbx, 0x08(%%rdi)
        \\ mov %%rbp, 0x10(%%rdi)
        \\ mov %%r12, 0x18(%%rdi)
        \\ mov %%r13, 0x20(%%rdi)
        \\ mov %%r14, 0x28(%%rdi)
        \\ mov %%r15, 0x30(%%rdi)
        \\ mov (%%rsp), %%rax
        \\ mov %%rax, 0x38(%%rdi)
        \\
        \\ mov 0x08(%%rsi), %%rbx
        \\ mov 0x10(%%rsi), %%rbp
        \\ mov 0x18(%%rsi), %%r12
        \\ mov 0x20(%%rsi), %%r13
        \\ mov 0x28(%%rsi), %%r14
        \\ mov 0x30(%%rsi), %%r15
        \\ mov 0x00(%%rsi), %%rsp
        \\ jmp *0x38(%%rsi)
    );  
}

pub fn doSwap(from: *Registers, to: *Registers) void {
    const sym = comptime if (builtin.target.os.tag.isDarwin()) "call _swap" else "call swap";
    asm volatile (sym
        :
        : [from] "{rdi}" (from), [to] "{rsi}" (to)
        : .{
            .rax = true, .rdi = true, .rsi = true,
            .rbx = true, .rbp = true,
            .r12 = true, .r13 = true, .r14 = true, .r15 = true,
            .memory = true
        }
    );
}

pub fn trampoline() callconv(.naked) noreturn {
    asm volatile (
        \\ mov %%rbx, %%rdi
        \\ jmp *%[land]
        :
        : [land] "X" (&Fiber.trampolineLand)
    );
}

pub fn initRegs(sp: usize, self: *anyopaque) Registers {
    return .{
        .sp = sp,
        .ip = @intFromPtr(&trampoline),
        .rbx = @intFromPtr(self)
    };
}