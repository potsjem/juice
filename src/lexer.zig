const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

var error_idx: u32 = 0;

const Error = error {
    UnexpectedChar,
} || Allocator.Error;

const State = enum {
    initial,
    comment,
    identifier,
    string,
};

pub const Token = struct {
    kind: Kind,
    idx: u32,

    pub const Kind = enum {
        root, //EOF
        atom,
        identifier,
        string,
        @"(",
        @")",
        @"@",
    };

    pub fn slice(self: Token, source: [:0]const u8) []const u8 {
        var idx = self.idx;

        return switch (self.kind) {
            .root => source[idx..],
            .atom => sub: switch (source[idx+1]) {
                'a'...'z', 'A'...'Z', '0'...'9', ':', '-' => {
                    idx += 1;
                    continue :sub source[idx];
                },
                else => {
                    return source[self.idx+1..idx];
                },
            },
            .identifier => sub: switch (source[idx]) {
                'a'...'z', 'A'...'Z', '0'...'9', ':', '-' => {
                    idx += 1;
                    continue :sub source[idx];
                },
                else => {
                    return source[self.idx..idx];
                },
            },
            .string => sub: switch (source[idx+1]) {
                //TODO, handle unbalanced string at eof
                '"' => {
                    return source[self.idx+1..idx];
                },
                else => {
                    idx += 1;
                    continue :sub source[idx];
                },
            },
            else => @tagName(self.kind),
        };
    }
};

pub fn lex(allocator: Allocator, source: [:0]const u8) Error![]Token {
    var tokens = ArrayList(Token).init(allocator);

    var idx: u32 = 0;

    state: switch (State.initial) {
        .initial => switch (source[idx]) {
            '\n', '\r', '\t', ' ' => {
                idx += 1;
                continue :state .initial;
            },
            ';' => {
                continue :state .comment;
            },
            0 => {
                try tokens.append(.{
                    .kind = .root,
                    .idx = idx,
                });

                idx += 1;
            },
            '(' => {
                try tokens.append(.{
                    .kind = .@"(",
                    .idx = idx,
                });

                idx += 1;
                continue :state .initial;
            },
            ')' => {
                try tokens.append(.{
                    .kind = .@")",
                    .idx = idx,
                });

                idx += 1;
                continue :state .initial;
            },
            '@' => {
                try tokens.append(.{
                    .kind = .@"@",
                    .idx = idx,
                });

                idx += 1;
                continue :state .initial;
            },
            '"' => {
                try tokens.append(.{
                    .kind = .string,
                    .idx = idx,
                });

                std.debug.print("##########################################\n", .{});
                idx += 1;
                continue :state .string;
            },
            '#' => {
                try tokens.append(.{
                    .kind = .atom,
                    .idx = idx,
                });

                idx += 1;
                continue :state .identifier;
            },
            'a'...'z', 'A'...'Z' => {
                try tokens.append(.{
                    .kind = .identifier,
                    .idx = idx,
                });

                continue :state .identifier;
            },
            else => |c| {
                error_idx = idx;
                std.debug.print("(TODO, remove), Unexpected char: {c}\n", .{c});
                return error.UnexpectedChar;
            },
        },
        .comment => sub: switch (source[idx]) {
            0, '\n' => {
                continue :state .initial;
            },
            else => {
                idx += 1;
                continue :sub source[idx];
            },
        },
        .identifier => sub: switch (source[idx]) {
            'a'...'z', 'A'...'Z', '0'...'9', ':', '-' => {
                idx += 1;
                continue :sub source[idx];
            },
            else => {
                continue :state .initial;
            },
        },
        .string => sub: switch (source[idx]) {
            //TODO, handle unbalanced string at eof
            '"' => {
                idx += 1;
                continue :state .initial;
            },
            else => |c| {
                std.debug.print("c: '{c}'\n", .{c});
                idx += 1;
                continue :sub source[idx];
            },
        },
    }

    return tokens.toOwnedSlice();
}
