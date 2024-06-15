const std = @import("std");
const raylib = @import("raylib.zig");
const Chip8 = @import("chip8.zig").Chip8;

pub fn main() !void {
    raylib.InitWindow(800, 540, "raylib [core] example - basic window");
    defer raylib.CloseWindow();

    raylib.SetTargetFPS(120);

    const chip8 = Chip8.init();
    _ = chip8;

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.RAYWHITE);
        raylib.DrawText("Congrats! You created your first window!", 190, 200, 20, raylib.LIGHTGRAY);
        raylib.EndDrawing();
    }
}
