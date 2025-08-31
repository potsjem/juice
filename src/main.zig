const std = @import("std");

const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");
const Interp = @import("interp.zig");

const cwd = std.fs.cwd;
const DebugAllocator = std.heap.DebugAllocator;
const ArgIterator = std.process.ArgIterator;

pub fn main() !void {
    var gpa = DebugAllocator(.{}).init;
    const allocator = gpa.allocator();

    var args = try ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    const self = args.next().?;
    const name = args.next() orelse @panic("NOTE, please provide at least 1 argument");
    _ = self;

    const source = try cwd()
        .readFileAllocOptions(allocator, name, std.math.maxInt(u32), null, @alignOf(u8), 0);
    defer allocator.free(source);

    const tokens = try Lexer.lex(allocator, source);
    defer allocator.free(tokens);

    for (tokens) |token|
        std.debug.print("token.{s}: '{s}'\n", .{@tagName(token.kind), token.slice(source)});

    const tree = try Parser.parse(allocator, tokens, source);
    defer tree.deinit(allocator);

    try tree.debug(tokens, source, 0, 0);

    //try Interp.eval(tree, tokens, source);
}
