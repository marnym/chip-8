const std = @import("std");
const Display = @import("Display.zig").Display;
const Stack = @import("Stack.zig").Stack;

pub const Chip8 = @This();

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
registers: [16]u8,
index: u16,
program_counter: u16,
display: Display,
stack: Stack,
delay_timer: u8,
sound_timer: u8,

pub fn init(stack_mem: *[32]u8) !Chip8 {
    var chip8 = Chip8{
        .memory = std.mem.zeroes([4096]u8),
        .registers = std.mem.zeroes([16]u8),
        .index = 0,
        .program_counter = 0,
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
    const opcode = self.fetch();
    self.execute(opcode);
}

fn fetch(self: Chip8) u16 {
    defer self.program_counter += 2;
    return self.memory[self.program_counter] << 8 | self.memory[self.program_counter + 1];
}

fn execute(self: *Chip8, opcode: u16) void {
    const kind = opcode & 0xF000; // 1st nibble
    const x = opcode & 0x0F00; // 2nd nibble
    const y = opcode & 0x00F0; // 3rd nibble
    const n = opcode & 0x000F; // 4th nibble
    const nn = opcode & 0x00FF; // 3rd and 4th nibbles
    const nnn = opcode & 0x0FFF; // 2nd, 3rd and 4th nibbles

    return switch (kind) {
        0x0 => switch (n) {
            0x0 => { // clear screen
                self.display.clear();
            },
            0xE => { // return from subroutine

            },
            else => unreachable,
        },
        0x1 => { // jump
            self.pc = nnn;
        },
        0x6 => { // set
            self.registers[x] = nn;
        },
        0x7 => { // add
            self.registers[x] += nn;
        },
        0xA => { // set index
            self.I = nnn;
        },
        0xD => { // display
            var vx = self.registers[x] % Display.x_dim;
            const vy = self.registers[y] % Display.y_dim;

            const vf = &self.registers[0xF];
            vf.* = 0;

            for (0..n) |i| {
                const sprite_row = self.memory[self.index + i];
                for (7..0) |bit| {
                    const sprite_on = sprite_row & (1 << bit) == 1;
                    if (sprite_on and self.display.getXY(vx, vy)) {
                        self.display.turnOff(vx, vy);
                        vf.* = 1;
                    } else if (sprite_on and !self.display.getXY(vx, vy)) {
                        self.display.turnOn(vx, vy);
                    }

                    if (vx == Display.Display.x_dim) {
                        break;
                    }

                    vx += 1;
                }
                vy += 1;

                if (vy == Display.Display.y_dim) {
                    break;
                }
            }
        },
        else => unreachable,
    };
}
