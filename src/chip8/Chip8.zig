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
    // TODO: Remove hardcoded halt instruction for IBM
    if (opcode == 0x1228) {
        return true;
    }
    try self.execute(opcode);

    if (self.delay_timer > 0) {
        self.delay_timer -= 1;
    }
    if (self.sound_timer > 0) {
        std.debug.print("BEEP!\n", .{});
        self.sound_timer -= 1;
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
    const x: u16 = @truncate((opcode & 0x0F00) >> 8); // 2nd nibble
    const y: u16 = @truncate((opcode & 0x00F0) >> 4); // 3rd nibble
    const n: u16 = @truncate((opcode & 0x000F)); // 4th nibble
    const nn: u16 = @truncate(opcode & 0x00FF); // 3rd and 4th nibbles
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
        else => unreachable,
    };
}
