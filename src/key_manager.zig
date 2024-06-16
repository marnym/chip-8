const raylib = @import("raylib.zig");

pub const KeyManager = @This();

pub fn isKeyPressed(_: KeyManager, key: u4) bool {
    const raylib_key = switch (key) {
        0x0 => raylib.KEY_ZERO,
        0x1 => raylib.KEY_ONE,
        0x2 => raylib.KEY_TWO,
        0x3 => raylib.KEY_THREE,
        0x4 => raylib.KEY_FOUR,
        0x5 => raylib.KEY_FIVE,
        0x6 => raylib.KEY_SIX,
        0x7 => raylib.KEY_SEVEN,
        0x8 => raylib.KEY_EIGHT,
        0x9 => raylib.KEY_NINE,
        0xA => raylib.KEY_A,
        0xB => raylib.KEY_B,
        0xC => raylib.KEY_C,
        0xD => raylib.KEY_D,
        0xE => raylib.KEY_E,
        0xF => raylib.KEY_F,
    };
    return raylib.IsKeyDown(raylib_key);
}

pub fn getKey(_: KeyManager) ?u4 {
    return switch (raylib.GetKeyPressed()) {
        raylib.KEY_ZERO => 0x0,
        raylib.KEY_ONE => 0x1,
        raylib.KEY_TWO => 0x2,
        raylib.KEY_THREE => 0x3,
        raylib.KEY_FOUR => 0x4,
        raylib.KEY_FIVE => 0x5,
        raylib.KEY_SIX => 0x6,
        raylib.KEY_SEVEN => 0x7,
        raylib.KEY_EIGHT => 0x8,
        raylib.KEY_NINE => 0x9,
        raylib.KEY_A => 0xA,
        raylib.KEY_B => 0xB,
        raylib.KEY_C => 0xC,
        raylib.KEY_D => 0xD,
        raylib.KEY_E => 0xE,
        raylib.KEY_F => 0xF,
        else => null,
    };
}

pub fn empty_keys_pressed(self: KeyManager) void {
    var key: ?u4 = 0;
    while (key != null) : (key = self.getKey()) {}
}
