const std = @import("std");
const c = @cImport(@cInclude("raylib.h"));
const raylib = c.raylib;

pub fn main() !void {
    raylib.InitWindow(960, 540, "Test");
    defer raylib.CloseWindow();
    raylib.SetTargetFPS(120);

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.BLACK);
        raylib.EndDrawing();
    }
}
