const std = @import("std");
const Display = @import("Display.zig").Display;
const Stack = @import("Stack.zig").Stack;
const KeyManager = @import("../key_manager.zig").KeyManager;
const op_code = @import("op_code.zig");
const OpCode = op_code.OpCode;
const Nibble = op_code.Nibble;

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

pub fn loadRomFromFile(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const cwd = std.fs.cwd();
    return try cwd.readFileAlloc(allocator, filename, 4096);
}

pub fn loadRom(self: *Chip8, rom: []const u8) void {
    const load_location = 0x200;
    std.mem.copyForwards(u8, self.memory[load_location..], rom);
    self.program_counter = load_location;
}

pub fn cycle(self: *Chip8) !void {
    const instruction = self.fetch();
    const opcode = decode(instruction);
    try self.execute(opcode);

    if (self.delay_timer > 0) {
        self.delay_timer -= 1;
    }
    if (self.sound_timer > 0) {
        std.debug.print("BEEP!\n", .{});
        self.sound_timer -= 1;
    }

    if (opcode == OpCode.get_key) {
        self.key_manager.empty_keys_pressed();
    }
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
    return opcode;
}

fn decode(instruction: u16) OpCode {
    const kind: Nibble = @truncate((instruction & 0xF000) >> 12); // 1st nibble
    const x: Nibble = @truncate((instruction & 0x0F00) >> 8); // 2nd nibble
    const y: Nibble = @truncate((instruction & 0x00F0) >> 4); // 3rd nibble
    const n: Nibble = @truncate((instruction & 0x000F)); // 4th nibble
    const nn: u8 = @truncate(instruction & 0x00FF); // 3rd and 4th nibbles
    const nnn: u12 = @truncate(instruction & 0x0FFF); // 2nd, 3rd and 4th nibbles

    return switch (kind) {
        0x0 => switch (n) { // check last nibble
            0x0 => OpCode{ .clear_screen = .{ .opcode = instruction } },
            0xE => OpCode{ .subroutine_return = .{ .opcode = instruction } },
            else => OpCode{ .invalid = .{ .opcode = instruction } },
        },
        0x1 => OpCode{ .jump = .{ .opcode = instruction, .nnn = nnn } },
        0x2 => OpCode{ .subroutine_call = .{ .opcode = instruction, .nnn = nnn } },
        0x3 => OpCode{ .skip_if_vx_eq_nn = .{ .opcode = instruction, .x = x, .nn = nn } },
        0x4 => OpCode{ .skip_if_vx_neq_nn = .{ .opcode = instruction, .x = x, .nn = nn } },
        0x5 => OpCode{ .skip_if_vx_eq_vy = .{ .opcode = instruction, .x = x, .y = y } },
        0x6 => OpCode{ .set_vx_to_nn = .{ .opcode = instruction, .x = x, .nn = nn } },
        0x7 => OpCode{ .add_no_carry = .{ .opcode = instruction, .x = x, .nn = nn } },
        0x8 => switch (n) { // check last nibble
            0x0 => OpCode{ .set_vx_to_vy = .{ .opcode = instruction, .x = x, .y = y } },
            0x1 => OpCode{ .binary_or = .{ .opcode = instruction, .x = x, .y = y } },
            0x2 => OpCode{ .binary_and = .{ .opcode = instruction, .x = x, .y = y } },
            0x3 => OpCode{ .logical_xor = .{ .opcode = instruction, .x = x, .y = y } },
            0x4 => OpCode{ .add_carry = .{ .opcode = instruction, .x = x, .y = y } },
            0x5 => OpCode{ .subtract_vx_vy = .{ .opcode = instruction, .x = x, .y = y } },
            0x6 => OpCode{ .shift_right = .{ .opcode = instruction, .x = x, .y = y } },
            0x7 => OpCode{ .subtract_vy_vx = .{ .opcode = instruction, .x = x, .y = y } },
            0xE => OpCode{ .shift_left = .{ .opcode = instruction, .x = x, .y = y } },
            else => OpCode{ .invalid = .{ .opcode = instruction } },
        },
        0x9 => OpCode{ .skip_if_vx_neq_vy = .{ .opcode = instruction, .x = x, .y = y } },
        0xA => OpCode{ .set_index = .{ .opcode = instruction, .nnn = nnn } },
        0xB => OpCode{ .jump_offset = .{ .opcode = instruction, .nnn = nnn } },
        0xC => OpCode{ .random = .{ .opcode = instruction, .x = x, .nn = nn } },
        0xD => OpCode{ .display = .{ .opcode = instruction, .x = x, .y = y, .n = n } },
        0xE => switch (n) { // check last nibble
            0x1 => OpCode{ .skip_if_pressed = .{ .opcode = instruction, .x = x } },
            0xE => OpCode{ .skip_if_not_pressed = .{ .opcode = instruction, .x = x } },
            else => OpCode{ .invalid = .{ .opcode = instruction } },
        },
        0xF => switch (nn) { // check last two nibbles
            0x07 => OpCode{ .timer_delay_get = .{ .opcode = instruction, .x = x } },
            0x15 => OpCode{ .timer_delay_set = .{ .opcode = instruction, .x = x } },
            0x18 => OpCode{ .timer_sound_set = .{ .opcode = instruction, .x = x } },
            0x1E => OpCode{ .add_to_index = .{ .opcode = instruction, .x = x } },
            0x0A => OpCode{ .get_key = .{ .opcode = instruction, .x = x } },
            0x29 => OpCode{ .font_char = .{ .opcode = instruction, .x = x } },
            0x33 => OpCode{ .binary_decimal_conversion = .{ .opcode = instruction, .x = x } },
            0x55 => OpCode{ .mem_store = .{ .opcode = instruction, .x = x } },
            0x65 => OpCode{ .mem_load = .{ .opcode = instruction, .x = x } },
            else => OpCode{ .invalid = .{ .opcode = instruction } },
        },
    };
}

fn execute(self: *Chip8, opcode: OpCode) !void {
    return switch (opcode) {
        .clear_screen => {
            self.display.clear();
        },

        .jump => |op| {
            self.PC().* = op.nnn;
        },

        .subroutine_call => |op| {
            try self.stack.push(self.PC().*);
            self.PC().* = op.nnn;
        },
        .subroutine_return => {
            self.PC().* = self.stack.pop();
        },

        .skip_if_vx_eq_nn => |op| {
            if (self.V(op.x).* == op.nn) {
                self.PC().* += 2;
            }
        },
        .skip_if_vx_neq_nn => |op| {
            if (self.V(op.x).* != op.nn) {
                self.PC().* += 2;
            }
        },
        .skip_if_vx_eq_vy => |op| {
            if (self.V(op.x).* == self.V(op.y).*) {
                self.PC().* += 2;
            }
        },
        .skip_if_vx_neq_vy => |op| {
            if (self.V(op.x).* != self.V(op.y).*) {
                self.PC().* += 2;
            }
        },

        .set_vx_to_nn => |op| {
            self.V(op.x).* = @truncate(op.nn);
        },

        .add_no_carry => |op| {
            const vx = self.V(op.x);
            vx.* = @addWithOverflow(vx.*, op.nn)[0];
        },

        .set_vx_to_vy => |op| {
            self.V(op.x).* = self.V(op.y).*;
        },

        .binary_or => |op| {
            self.V(op.x).* |= self.V(op.y).*;
        },
        .binary_and => |op| {
            self.V(op.x).* &= self.V(op.y).*;
        },
        .logical_xor => |op| {
            self.V(op.x).* ^= self.V(op.y).*;
        },
        .add_carry => |op| {
            const vx = self.V(op.x);
            const vy = self.V(op.y).*;
            const result = @addWithOverflow(vx.*, vy);
            vx.* = result[0];
            self.VF().* = result[1];
        },

        .subtract_vx_vy => |op| {
            const vx = self.V(op.x);
            const vy = self.V(op.y).*;
            self.VF().* = if (vx.* >= vy) 1 else 0;
            vx.* = @subWithOverflow(vx.*, vy)[0];
        },
        .subtract_vy_vx => |op| {
            const vx = self.V(op.x);
            const vy = self.V(op.y).*;
            self.VF().* = if (vy >= vx.*) 1 else 0;
            vx.* = @subWithOverflow(vy, vx.*)[0];
        },

        .shift_right => |op| {
            const vx = self.V(op.x);
            self.VF().* = vx.* & 0x1;
            vx.* >>= 1;
        },
        .shift_left => |op| {
            const vx = self.V(op.x);
            self.VF().* = (vx.* >> 7) & 0x1;
            vx.* <<= 1;
        },

        .set_index => |op| {
            self.index = op.nnn;
        },

        .jump_offset => |op| {
            self.PC().* = op.nnn + self.V(0x0).*;
        },

        .random => |op| {
            self.V(op.x).* = rand.int(u8) & op.nn;
        },

        .display => |op| {
            const vx = self.V(op.x).* % Display.x_dim;
            var vy = self.V(op.y).* % Display.y_dim;

            const vf = self.VF();
            vf.* = 0;

            for (0..op.n) |i| {
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

        .skip_if_pressed => |op| {
            const key_pressed = self.key_manager.isKeyPressed(@truncate(self.V(op.x).*));
            if (key_pressed) {
                self.PC().* += 2;
            }
        },
        .skip_if_not_pressed => |op| {
            const key_pressed = self.key_manager.isKeyPressed(@truncate(self.V(op.x).*));
            if (!key_pressed) {
                self.PC().* += 2;
            }
        },

        .timer_delay_get => |op| {
            self.V(op.x).* = self.delay_timer;
        },
        .timer_delay_set => |op| {
            self.delay_timer = self.V(op.x).*;
        },
        .timer_sound_set => |op| {
            self.sound_timer = self.V(op.x).*;
        },

        .add_to_index => |op| {
            self.index += self.V(op.x).*;
            // Amiga version
            if (self.index > 0x1000) {
                self.VF().* = 1;
            }
        },

        .get_key => |op| {
            if (self.key_manager.getKey()) |key| {
                self.V(op.x).* = key;
            } else {
                self.PC().* -= 2;
            }
        },
        .font_char => |op| {
            // 5 bytes for each character
            self.index = font_offset + (5 * self.V(op.x).*);
        },

        .binary_decimal_conversion => |op| {
            const vx = self.V(op.x).*;
            const index = self.index;

            self.memory[index] = vx / 100 % 10;
            self.memory[index + 1] = vx / 10 % 10;
            self.memory[index + 2] = vx % 10;
        },
        .mem_store => |op| {
            for (0..op.x + 1) |i| {
                self.memory[self.index + i] = self.V(@truncate(i)).*;
            }
        },
        .mem_load => |op| {
            for (0..op.x + 1) |i| {
                self.V(@truncate(i)).* = self.memory[self.index + i];
            }
        },
        .invalid => |op| {
            std.debug.print("invalid instruction {}\n", .{op});
        },
    };
}
