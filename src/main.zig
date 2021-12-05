const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

const CharStream = struct {
    string: []const u8,
    i: usize = 0,

    pub fn init(string: []const u8) CharStream {
        return .{ .string = string };
    }

    pub fn next(self: *CharStream) ?u8 {
        if (self.i < self.string.len) {
            defer self.i += 1;
            return self.string[self.i];
        }

        return null;
    }

    pub fn match(self: *CharStream, ch: u8) bool {
        if (self.peek()) |c| {
            if (c == ch) {
                self.i += 1;
                return true;
            }
        }

        return false;
    }

    pub fn peek(self: CharStream) ?u8 {
        if (self.i < self.string.len) {
            return self.string[self.i];
        }

        return null;
    }

    pub fn eof(self: CharStream) bool {
        return self.i >= self.string.len;
    }

    pub fn reset(self: *CharStream) void {
        self.i = 0;
    }
};

pub fn templ(allocator: Allocator, string: []const u8, data: anytype) ![]u8 {
    const data_type = @TypeOf(data);
    const type_info = @typeInfo(data_type);

    const fields = switch (type_info) {
        .Struct => |s| s.fields,
        else => {
            return error.InvalidDataType;
        },
    };

    var len: i64 = 0;
    var stream = CharStream.init(string);
    var buffer: []u8 = undefined;
    var wr: std.io.FixedBufferStream([]u8).Writer = undefined;
    var i: usize = 0;
    while (i < 2) : (i += 1) {
        if (i == 1) {
            buffer = try allocator.alloc(u8, @intCast(usize, len));
            wr = std.io.fixedBufferStream(buffer).writer();
            stream.reset();
        }

        while (stream.next()) |ch| {
            if (ch == '$' and stream.match('{')) {
                var annotation_len: usize = 2;
                var annotation_name_start: usize = stream.i;
                var annotation_name_end: usize = stream.i;
                while (stream.next()) |ch3| {
                    annotation_len += 1;
                    if (ch3 == '}') {
                        annotation_name_end = stream.i - 1;
                        break;
                    }
                }
                var name = string[annotation_name_start..annotation_name_end];

                inline for (fields) |field| {
                    if (std.mem.eql(u8, field.name, name)) {
                        const dat_field = @field(data, field.name);
                        const field_type = @TypeOf(dat_field);

                        if (i == 0) {
                            var final_len: usize = switch (@typeInfo(field_type)) {
                                .Int, .Float, .ComptimeInt, .ComptimeFloat => std.fmt.count("{}", .{dat_field}),
                                .Pointer => |p| switch (p.size) {
                                    .Slice => dat_field.len,
                                    .Many => @bitCast([]const u8, dat_field).len,
                                    .One => switch (@typeInfo(p.child)) {
                                        .Array => @as([]const u8, dat_field).len,
                                        else => return error.InvalidFieldType,
                                    },
                                    .C => return error.InvalidFieldType,
                                },
                                else => return error.InvalidFieldType,
                            };

                            len += @intCast(i64, final_len) - 1;
                        } else {
                            // NOTE: I store the error here because if I try to return the error from inside the switch I get a compiler crash (bug).
                            var typeError: ?anyerror = null;
                            switch (@typeInfo(field_type)) {
                                .Int, .Float, .ComptimeInt, .ComptimeFloat => {
                                    try wr.print("{}", .{dat_field});
                                },
                                .Pointer => |ptr| switch (ptr.size) {
                                    .Slice => {
                                        if (ptr.child == u8) {
                                            try wr.writeAll(dat_field);
                                        } else {
                                            typeError = error.InvalidSliceChildType;
                                        }
                                    },
                                    .Many => {
                                        typeError = error.TypeNotImplemented;
                                    },
                                    .One => switch (@typeInfo(ptr.child)) {
                                        .Array => |arr| {
                                            if (arr.child == u8) {
                                                try wr.writeAll(dat_field);
                                            } else {
                                                typeError = error.InvalidArrayChildType;
                                            }
                                        },

                                        else => {
                                            typeError = error.TypeNotImplemented;
                                        },
                                    },
                                    .C => {
                                        typeError = error.TypeNotImplemented;
                                    },
                                },
                                else => {
                                    typeError = error.TypeNotImplemented;
                                },
                            }

                            if (typeError != null) {
                                return typeError.?;
                            }
                        }

                        break;
                    }
                }
            } else if (i == 1) {
                try wr.writeByte(ch);
            }

            if (i == 0) {
                len += 1;
            }
        }
    }

    return buffer;
}

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

test "basic" {
    var template = "My name is ${name}";
    var output = try templ(test_allocator, template, .{ .name = "Daniel" });
    defer test_allocator.free(output);

    try expect(std.mem.eql(u8, output, "My name is Daniel"));
}

test "with numbers" {
    var template = "Eath's average radius is ${radius} km";
    var output = try templ(test_allocator, template, .{ .radius = 6371 });
    defer test_allocator.free(output);

    try expect(std.mem.eql(u8, output, "Eath's average radius is 6371 km"));
}
