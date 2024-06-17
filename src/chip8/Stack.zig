const std = @import("std");

pub const Stack = @This();

const ItemType = u16;
stack: std.ArrayList(ItemType),

pub const StackError = error{CapacityError};

pub fn init(allocator: std.mem.Allocator) !Stack {
    return Stack{
        .stack = try std.ArrayList(ItemType).initCapacity(allocator, 16),
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

pub fn pop(self: *Stack) ItemType {
    return self.stack.pop();
}

/// empties the stack
pub fn empty(self: *Stack) void {
    while (self.stack.popOrNull() != null) {}
}
