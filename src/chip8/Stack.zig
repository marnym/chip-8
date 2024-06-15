const std = @import("std");

pub const Stack = @This();

const ItemType = u16;
stack: std.ArrayList(ItemType),

pub const StackError = error{CapacityError};

/// The Stack has place for 16 * u16 = 32 * u8.
/// Needs to take `[]u8` as param, since FixedBufferAllocator only accepts `[]u8`
pub fn init(buf: *[32]u8) !Stack {
    var fba = std.heap.FixedBufferAllocator.init(buf);
    return Stack{
        .stack = try std.ArrayList(ItemType).initCapacity(fba.allocator(), 16),
    };
}

pub fn deinit(self: *Stack) void {
    self.stack.deinit();
}

pub fn push(self: *Stack, item: ItemType) StackError!void {
    if (self.stack.items.len < self.stack.capacity) {
        self.stack.appendAssumeCapacity(item);
    } else {
        return StackError.CapacityError;
    }
}

pub fn pop(self: *Stack) ?ItemType {
    return self.stack.popOrNull();
}
