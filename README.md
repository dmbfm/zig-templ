# zig-templ

A simple text templating library for zig. Currently WIP stage. 

## Usage

```zig
const templ = @import("zig-templ/src/main.zig").templ;

pub fn main() !void {
    var output = templ(std.heap.page_allocator, "zig-${name}", .{ .name = "templ" });
    defer std.heap.page_allocator.free(output);

    std.log.info("{}", .{ output });
}
```
