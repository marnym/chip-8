const std = @import("std");
const Display = @import("Display.zig").Display;
const Stack = @import("Stack.zig").Stack;

pub const Chip8 = @This();

const OpCode = enum { not_implemented };

const font = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

memory: [4096]u8,
I: u16,
pc: u16,
display: Display,
stack: Stack,
delay_timer: u8,
sound_timer: u8,

pub fn init(stack_mem: *[32]u8) !Chip8 {
    var chip8 = Chip8{
        .memory = std.mem.zeroes([4096]u8),
        .I = 0,
        .pc = 0,
        .display = std.mem.zeroes(Display),
        .stack = try Stack.init(stack_mem),
        .delay_timer = 0,
        .sound_timer = 0,
    };

    for (font, 0x50..0xA0) |f, i| {
        chip8.memory[i] = f;
    }
    return chip8;
}

pub fn deinit(self: *Chip8) void {
    self.stack.deinit();
}

pub fn loop(self: *Chip8) void {
    const instruction = self.fetch();
    const code = self.decode(instruction);
    self.execute(code);
}

fn fetch(self: Chip8) u16 {
    return self.memory[self.pc];
}

fn decode(instruction: u16) OpCode {
    switch (instruction) {
        else => return OpCode.not_implemented,
    }
}

fn execute(code: OpCode) void {
    _ = code;
}
