const std = @import("std");
const Tuple = std.meta.Tuple;

pub const Display = @This();

pub const scale = 32;
pub const x_dim = 64;
pub const y_dim = 32;

display: [x_dim][y_dim]bool,

pub fn getXY(self: Display, x: usize, y: usize) bool {
    std.debug.assert(x < x_dim);
    std.debug.assert(y < y_dim);
    return self.display[x][y];
}

pub fn getXYScaled(self: Display, x: usize, y: usize) ?Tuple(&.{ usize, usize }) {
    if (self.getXY(x, y)) {
        return .{ x * scale, y * scale };
    } else {
        return null;
    }
}

pub fn turnOn(self: *Display, x: usize, y: usize) void {
    std.debug.assert(x < x_dim);
    std.debug.assert(y < y_dim);
    self.display[x][y] = true;
}

pub fn turnOff(self: *Display, x: usize, y: usize) void {
    std.debug.assert(x < x_dim);
    std.debug.assert(y < y_dim);
    self.display[x][y] = false;
}

pub fn clear(self: *Display) void {
    for (0..x_dim) |x| {
        for (0..y_dim) |y| {
            self.display[x][y] = false;
        }
    }
}

test "getXY empty" {
    const testing = std.testing;
    const display = std.mem.zeroes(Display);

    {
        try testing.expectEqual(false, display.getXY(0, 0));
    }
    {
        try testing.expectEqual(false, display.getXY(1, 1));
    }
}

test "getXY values" {
    const testing = std.testing;
    var display = std.mem.zeroes(Display);
    display.display[0][0] = true;
    display.display[1][1] = true;
    display.display[x_dim - 1][y_dim - 1] = true;

    {
        try testing.expectEqual(true, display.getXY(0, 0));
    }
    {
        try testing.expectEqual(true, display.getXY(1, 1));
    }
    {
        try testing.expectEqual(true, display.getXY(x_dim - 1, y_dim - 1));
    }
}

test "getXYScaled" {
    const testing = std.testing;
    var display = std.mem.zeroes(Display);
    display.display[0][0] = true;
    display.display[1][1] = true;
    display.display[x_dim - 1][y_dim - 1] = true;

    {
        try testing.expectEqual(.{ 0, 0 }, display.getXYScaled(0, 0));
    }
    {
        try testing.expectEqual(.{ scale, scale }, display.getXYScaled(1, 1));
    }
    {
        try testing.expectEqual(.{ (x_dim - 1) * scale, (y_dim - 1) * scale }, display.getXYScaled(x_dim - 1, y_dim - 1));
    }
}

test "clear" {
    const testing = std.testing;
    var display = std.mem.zeroes(Display);
    display.display[0][0] = true;
    display.display[1][1] = true;
    display.display[x_dim - 1][y_dim - 1] = true;

    display.clear();

    try testing.expectEqual(false, display.getXY(0, 0));
    try testing.expectEqual(false, display.getXY(1, 1));
    try testing.expectEqual(false, display.getXY(x_dim - 1, y_dim - 1));
}
