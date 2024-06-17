const std = @import("std");
const raylib = @import("raylib.zig");
const Chip8 = @import("chip8/Chip8.zig").Chip8;
const Display = @import("chip8/Display.zig").Display;
const KeyManager = @import("key_manager.zig").KeyManager;

pub fn render(chip8: Chip8) void {
    raylib.BeginDrawing();
    defer raylib.EndDrawing();
    raylib.ClearBackground(raylib.BLACK);
    for (0..Display.x_dim) |x| {
        for (0..Display.y_dim) |y| {
            if (chip8.display.getXYScaled(x, y)) |scaled| {
                raylib.DrawRectangle(@intCast(scaled[0]), @intCast(scaled[1]), Display.scale, Display.scale, raylib.WHITE);
            }
        }
    }
}

pub fn main() !void {
    // ensure that all output is on own line
    std.debug.print("\n", .{});
    raylib.SetTraceLogLevel(raylib.LOG_ERROR);
    raylib.InitWindow(Display.x_dim * Display.scale, Display.y_dim * Display.scale, "CHIP-8");
    defer raylib.CloseWindow();

    // perfect for decrementing timers 60 times per second
    raylib.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chip8 = try Chip8.init(KeyManager{}, allocator);
    defer chip8.deinit();

    const instructions_per_frame = 12;
    while (!raylib.WindowShouldClose()) {
        defer render(chip8);

        for (0..instructions_per_frame) |_| {
            try chip8.cycle();
        }

        if (raylib.IsFileDropped()) {
            const droppedFiles = raylib.LoadDroppedFiles();
            defer raylib.UnloadDroppedFiles(droppedFiles);

            // only intrested in the first file
            const file_c = droppedFiles.paths[0];
            const file: []const u8 = std.mem.span(file_c);

            const rom = try Chip8.loadRomFromFile(file, allocator);
            defer allocator.free(rom);

            chip8.loadRom(rom);
        }
    }
}
