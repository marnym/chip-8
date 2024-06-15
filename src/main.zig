const std = @import("std");
const raylib = @import("raylib.zig");
const Chip8 = @import("chip8/Chip8.zig").Chip8;
const Display = @import("chip8/Display.zig").Display;

pub fn main() !void {
    raylib.SetTraceLogLevel(raylib.LOG_ERROR);
    raylib.InitWindow(Display.x_dim * Display.scale, Display.y_dim * Display.scale, "CHIP-8");
    defer raylib.CloseWindow();

    raylib.SetTargetFPS(60);

    {
        var stack_mem: [32]u8 = undefined;
        var chip8 = try Chip8.init(&stack_mem);
        defer chip8.deinit();

        while (!raylib.WindowShouldClose()) {
            raylib.BeginDrawing();
            defer raylib.EndDrawing();
            raylib.ClearBackground(raylib.BLACK);
            for (0..Display.x_dim) |x| {
                for (0..Display.y_dim) |y| {
                    if (chip8.display.getXYScaled(x, y)) |scaled| {
                        raylib.DrawRectangle(@intCast(scaled.@"0"), @intCast(scaled.@"1"), Display.scale, Display.scale, raylib.WHITE);
                    }
                }
            }
        }
    }
}
