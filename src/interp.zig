const std = @import("std");
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Lexer = @import("lexer.zig");
const Token = Lexer.Token;

const Parser = @import("parser.zig");
const Ast = Parser.Ast;

const Value = struct {
};

pub fn eval(
    tree: Ast,
    tokens: []const Token,
    source: [:0]const u8,
) !void {
    const node = tree.nodes[0];

    const len = tree.extra[node.list];
    const items = tree.extra[node.list+1..node.list+len+1];

    for (items) |idx| {
        _ = try interp(tree, tokens, source, idx);
    }
}

fn interp(
    tree: Ast,
    tokens: []const Token,
    source: [:0]const u8,
    ndx: u32,
) !Value {
    _ = source;

    const node = tree.nodes[ndx];

    switch (node.kind(tokens)) {
        else => |k| panic("Unhandled kind: {s}", .{@tagName(k)}),
    }

    return .{};
}
