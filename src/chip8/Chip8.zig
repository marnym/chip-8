const std = @import("std");
const Display = @import("Display.zig").Display;
const Stack = @import("Stack.zig").Stack;
const KeyManager = @import("../key_manager.zig").KeyManager;

pub const Chip8 = @This();

const IsKeyPressedFn = fn (key: u4) bool;

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
const font_offset = 0x50;

var prng = std.rand.DefaultPrng.init(8);
const rand = prng.random();

memory: [4096]u8,
registers: [16]u8,
index: u16,
program_counter: u16,
display: Display,
stack: Stack,
delay_timer: u8,
sound_timer: u8,
key_manager: KeyManager,

pub fn init(stack_mem: *[32]u8, key_manager: KeyManager) !Chip8 {
    var chip8 = Chip8{
        .memory = std.mem.zeroes([4096]u8),
        .registers = std.mem.zeroes([16]u8),
        .index = 0,
        .program_counter = 0,
        .display = std.mem.zeroes(Display),
        .stack = try Stack.init(stack_mem),
        .delay_timer = 0,
        .sound_timer = 0,
        .key_manager = key_manager,
    };

    for (font, font_offset..0xA0) |f, i| {
        chip8.memory[i] = f;
    }

    return chip8;
}

pub fn deinit(self: *Chip8) void {
    self.stack.deinit();
}

pub fn loadRom(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const cwd = std.fs.cwd();
    return try cwd.readFileAlloc(allocator, filename, 4096);
}

pub fn load(self: *Chip8, rom: []const u8) void {
    const load_location = 0x200;
    std.mem.copyForwards(u8, self.memory[load_location..], rom);
    self.program_counter = load_location;
}

/// returns `true` if this should be the last cycle
pub fn cycle(self: *Chip8) !bool {
    const opcode = self.fetch();
    try self.execute(opcode);

    if (self.delay_timer > 0) {
        self.delay_timer -= 1;
    }
    if (self.sound_timer > 0) {
        std.debug.print("BEEP!\n", .{});
        self.sound_timer -= 1;
    }

    const is_key_pressed_opcode = (opcode & 0xF0FF) == 0xF00A;
    if (!is_key_pressed_opcode) {
        self.key_manager.empty_keys_pressed();
    }

    return false;
}

/// shortcut for `self.registers[z]`
fn V(self: *Chip8, z: u16) *u8 {
    return &self.registers[z];
}

/// the F register
fn VF(self: *Chip8) *u8 {
    return &self.registers[0xF];
}

/// program counter
fn PC(self: *Chip8) *u16 {
    return &self.program_counter;
}

fn fetch(self: *Chip8) u16 {
    const pc = self.PC();
    defer pc.* += 2;
    var opcode: u16 = 0;
    opcode |= self.memory[pc.*];
    opcode <<= 8;
    opcode |= self.memory[pc.* + 1];
    // std.debug.print("pc = 0x{X:0>4}\topcode = 0x{X:0>4}\n", .{ pc.*, opcode });
    return opcode;
}

fn execute(self: *Chip8, opcode: u16) !void {
    const kind: u4 = @truncate((opcode & 0xF000) >> 12); // 1st nibble
    const x: u4 = @truncate((opcode & 0x0F00) >> 8); // 2nd nibble
    const y: u4 = @truncate((opcode & 0x00F0) >> 4); // 3rd nibble
    const n: u4 = @truncate((opcode & 0x000F)); // 4th nibble
    const nn: u8 = @truncate(opcode & 0x00FF); // 3rd and 4th nibbles
    const nnn: u16 = @truncate(opcode & 0x0FFF); // 2nd, 3rd and 4th nibbles

    return switch (kind) {
        0x0 => switch (n) { // check last nibble
            0x0 => { // clear screen
                self.display.clear();
            },
            0xE => { // return from subroutine
                self.PC().* = self.stack.pop();
            },
            else => unreachable,
        },
        0x1 => { // jump
            self.PC().* = nnn;
        },
        0x2 => { // enter subroutine
            try self.stack.push(self.PC().*);
            self.PC().* = nnn;
        },
        0x3 => { // skip if VX == NN
            if (self.V(x).* == nn) {
                self.PC().* += 2;
            }
        },
        0x4 => { // skip if VX != NN
            if (self.V(x).* != nn) {
                self.PC().* += 2;
            }
        },
        0x5 => { // skip if VX == VY
            if (self.V(x).* == self.V(y).*) {
                self.PC().* += 2;
            }
        },
        0x6 => { // set
            self.V(x).* = @truncate(nn);
        },
        0x7 => { // add
            self.V(x).* += @truncate(nn);
        },
        0x8 => switch (n) { // check last nibble
            0x0 => { // set VX to VY
                self.V(x).* = self.V(y).*;
            },
            0x1 => { // binary OR
                self.V(x).* |= self.V(y).*;
            },
            0x2 => { // binary AND
                self.V(x).* &= self.V(y).*;
            },
            0x3 => { // logical XOR
                self.V(x).* ^= self.V(y).*;
            },
            0x4 => { // add (with overflow)
                const vx = self.V(x);
                const vy = self.V(y).*;
                const result = @addWithOverflow(vx.*, vy);
                vx.* = result[0];
                self.VF().* = result[1];
            },
            0x5 => { // subtract VX - VY
                const vx = self.V(x);
                const vy = self.V(y).*;
                self.VF().* = if (vx.* >= vy) 1 else 0;
                vx.* -= vy;
            },
            0x6 => { // shift right
                const vx = self.V(x);
                vx.* = self.V(y).*;
                const outshifted_bit = vx.* & 0x1;
                vx.* >>= 1;
                self.VF().* = outshifted_bit;
            },
            0x7 => { // subtract VY - VX
                const vx = self.V(x);
                const vy = self.V(y).*;
                self.VF().* = if (vy >= vx.*) 1 else 0;
                vx.* = vy - vx.*;
            },
            0xE => { // shift left
                const vx = self.V(x);
                vx.* = self.V(y).*;
                const outshifted_bit = (vx.* >> 7) & 0x1;
                vx.* >>= 1;
                self.VF().* = outshifted_bit;
            },
            else => unreachable,
        },
        0x9 => { // skip if VX != VY
            if (self.V(x).* != self.V(y).*) {
                self.PC().* += 2;
            }
        },
        0xA => { // set index
            self.index = nnn;
        },
        0xB => { // jump with offset
            self.PC().* = nnn + self.V(0x0).*;
        },
        0xC => { // random
            self.V(x).* = rand.int(u8) & nn;
        },
        0xD => { // display
            const vx = self.V(x).* % Display.x_dim;
            var vy = self.V(y).* % Display.y_dim;

            const vf = self.VF();
            vf.* = 0;

            for (0..n) |i| {
                const sprite_row = self.memory[self.index + i];
                for (0..8) |bit| {
                    const sprite_on = (sprite_row >> @truncate(7 - bit)) & 1 == 1;
                    const x_index = vx + bit;
                    if (sprite_on and self.display.getXY(x_index, vy)) {
                        self.display.turnOff(x_index, vy);
                        vf.* = 1;
                    } else if (sprite_on and !self.display.getXY(x_index, vy)) {
                        self.display.turnOn(x_index, vy);
                    }

                    if (x_index >= Display.Display.x_dim) {
                        break;
                    }
                }
                vy += 1;

                if (vy >= Display.Display.y_dim) {
                    break;
                }
            }
        },
        0xE => {
            const key_pressed = self.key_manager.isKeyPressed(@truncate(self.V(x).*));
            switch (n) { // check last nibble
                0x1 => { // skip if key in VX is *not* pressed
                    if (!key_pressed) {
                        self.PC().* += 2;
                    }
                },
                0xE => { // skip if key in VX is pressed
                    if (key_pressed) {
                        self.PC().* += 2;
                    }
                },
                else => unreachable,
            }
        },
        0xF => {
            switch (nn) { // check last two nibbles
                0x07 => { // set VX to current value of delay timer
                    self.V(x).* = self.delay_timer;
                },
                0x15 => { // set delay timer to value in VX
                    self.delay_timer = self.V(x).*;
                },
                0x18 => { // set sound timer to value in VX
                    self.sound_timer = self.V(x).*;
                },
                0x1E => { // add to index
                    self.index += self.V(x).*;
                    // Amiga version
                    if (self.index > 0x1000) {
                        self.VF().* = 1;
                    }
                },
                0x0A => { // get key
                    if (self.key_manager.getKey()) |key| {
                        self.V(x).* = key;
                    } else {
                        self.PC().* -= 2;
                    }
                },
                0x29 => { // font character
                    // 5 bytes for each character
                    self.index = font_offset + (5 * self.V(x).*);
                },
                0x33 => { // binary-coded decimal conversion
                    const vx = self.V(x).*;
                    const index = self.index;

                    self.memory[index] = vx / 100 % 10;
                    self.memory[index + 1] = vx / 10 % 10;
                    self.memory[index + 2] = vx % 10;
                },
                0x55 => { // store memory
                    for (0..x + 1) |i| {
                        self.memory[self.index + i] = self.V(@truncate(i)).*;
                    }
                },
                0x65 => { // load memory
                    for (0..x + 1) |i| {
                        self.V(@truncate(i)).* = self.memory[self.index + i];
                    }
                },
                else => unreachable,
            }
        },
    };
}
