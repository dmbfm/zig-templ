# zig-simple-tamplate

Simple text templating library for zig. Currently WIP stage. 

## Usage

```
const templ = @import("zig-simple-tamplate/src/main.zig").templ;

pub fn main() !void {
    var output = templ(std.heap.page_allocator, "zig-${simple}-template", .{ .simple = "simple" });
    defer std.heap.page_allocator.free(output);

    std.log.info("{}", .{ output });
}
```
