const std = @import("std");

pub const Nibble = u4;

const BaseInstruction = struct {
    opcode: u16,
};

const XInstruction = struct {
    opcode: u16,
    x: Nibble,
};

const XYInstruction = struct {
    opcode: u16,
    x: Nibble,
    y: Nibble,
};

const XYNInstruction = struct {
    opcode: u16,
    x: Nibble,
    y: Nibble,
    n: Nibble,
};

const XNNInstruction = struct {
    opcode: u16,
    x: Nibble,
    nn: u8,
};

const NNNInstruction = struct {
    opcode: u16,
    nnn: u12,
};

pub const OpCode = union(enum) {
    invalid: BaseInstruction,

    clear_screen: BaseInstruction,

    jump: NNNInstruction,

    subroutine_call: NNNInstruction,
    subroutine_return: BaseInstruction,

    skip_if_vx_eq_nn: XNNInstruction,
    skip_if_vx_neq_nn: XNNInstruction,
    skip_if_vx_eq_vy: XYInstruction,
    skip_if_vx_neq_vy: XYInstruction,

    set_vx_to_nn: XNNInstruction,

    add_no_carry: XNNInstruction,

    set_vx_to_vy: XYInstruction,

    binary_or: XYInstruction,
    binary_and: XYInstruction,
    logical_xor: XYInstruction,
    add_carry: XYInstruction,

    subtract_vx_vy: XYInstruction,
    subtract_vy_vx: XYInstruction,

    shift_right: XYInstruction,
    shift_left: XYInstruction,

    set_index: NNNInstruction,

    jump_offset: NNNInstruction,

    random: XNNInstruction,

    display: XYNInstruction,

    skip_if_pressed: XInstruction,
    skip_if_not_pressed: XInstruction,

    timer_delay_get: XInstruction,
    timer_delay_set: XInstruction,
    timer_sound_set: XInstruction,

    add_to_index: XInstruction,

    get_key: XInstruction,
    font_char: XInstruction,

    binary_decimal_conversion: XInstruction,

    mem_store: XInstruction,
    mem_load: XInstruction,
};
