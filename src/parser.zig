const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Lexer = @import("lexer.zig");
const Token = Lexer.Token;

var error_idx: u32 = 0;

const Error = error {
    UnexpectedEof,
    UnexpectedRParen,
} || Allocator.Error;

pub const Ast = struct {
    nodes: []Node,
    extra: []u32,

    pub fn deinit(self: Ast, allocator: Allocator) void {
        allocator.free(self.nodes);
        allocator.free(self.extra);
    }

    pub fn debug(
        self: Ast,
        tokens: []const Token,
        source: [:0]const u8,
        depth: u32,
        idx: u32,
    ) !void {
        const node = self.nodes[idx];
        const kind = node.kind(tokens);

        for (0..depth) |_|
            std.debug.print("  ", .{});

        switch (kind) {
            .root => {
                std.debug.print("root\n", .{});

                const len = self.extra[node.list];
                for (self.extra[node.list+1..node.list+len+1]) |ndx| {
                    try self.debug(tokens, source, depth + 1, ndx);
                }
            },
            .@"(" => {
                std.debug.print("list\n", .{});

                const len = self.extra[node.list];
                for (self.extra[node.list+1..node.list+len+1]) |ndx| {
                    try self.debug(tokens, source, depth + 1, ndx);
                }
            },
            else => {
                std.debug.print("{s}\n", .{tokens[node.main].slice(source)});
            },
        }
    }
};

pub const Node = struct {
    main: u32,
    list: u32,

    pub fn kind(self: Node, tokens: []const Token) Token.Kind {
        return tokens[self.main].kind;
    }
};

pub fn parse(allocator: Allocator, tokens: []const Token, source: [:0]const u8) Error!Ast {
    var nodes = ArrayList(Node).init(allocator);
    var extra = ArrayList(u32).init(allocator);
    var roots = ArrayList(u32).init(allocator);
    var idx: u32 = 0;

    try nodes.append(.{
        .main = @intCast(tokens.len-1),
        .list = undefined,
    });

    while (true) switch (peek(tokens, &idx).kind) {
        .root => break,
        else => {
            const root = try parseExpr(
                &nodes,
                &extra,
                tokens,
                source,
                &idx);

            const node = nodes.items.len;
            try nodes.append(root);
            try roots.append(@intCast(node));
        },
    };

    const list = extra.items.len;
    try extra.append(@intCast(roots.items.len));
    try extra.appendSlice(roots.items);
    roots.deinit();

    nodes.items[0].list = @intCast(list);

    return .{
        .nodes = try nodes.toOwnedSlice(),
        .extra = try extra.toOwnedSlice(),
    };
}

fn parseExpr(
    nodes: *ArrayList(Node),
    extra: *ArrayList(u32),
    tokens: []const Token,
    source: [:0]const u8,
    idx: *u32,
) !Node {
    const main = idx.*;
    const token = next(tokens, idx);

    return switch (token.kind) {
        .root => {
            error_idx = token.idx;
            return error.UnexpectedEof;
        },
        .atom => .{
            .main = main,
            .list = undefined
        },
        .identifier => .{
            .main = main,
            .list = undefined
        },
        .string => .{
            .main = main,
            .list = undefined
        },
        .@"(" => b: {
            var elems = ArrayList(u32).init(extra.allocator);

            while (true) switch (peek(tokens, idx).kind) {
                .@")" => {
                    idx.* += 1;
                    break;
                },
                else => {
                    const elem = try parseExpr(
                        nodes,
                        extra,
                        tokens,
                        source,
                        idx);

                    const node = nodes.items.len;
                    try nodes.append(elem);
                    try elems.append(@intCast(node));
                },
            };

            const list = extra.items.len;
            try extra.append(@intCast(elems.items.len));
            try extra.appendSlice(elems.items);
            elems.deinit();

            break :b .{
                .main = main,
                .list = @intCast(list),
            };
        },
        .@")" => {
            error_idx = token.idx;
            return error.UnexpectedRParen;
        },
        .@"@" => .{
            .main = main,
            .list = undefined
        },
    };
}

fn peek(tokens: []const Token, idx: *const u32) Token {
    return tokens[idx.*];
}

fn next(tokens: []const Token, idx: *u32) Token {
    const token = tokens[idx.*];
    idx.* += 1;
    return token;
}

fn skip(tokens: []const Token, idx: *u32) void {
    switch (tokens[idx.*].kind) {
        .root => {},
        else => idx.* += 1,
    }
}
