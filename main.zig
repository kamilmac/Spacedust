const std = @import("std");

// extern fn log(str: i32) void;
extern "env" fn js_console_log(ptr: [*]const u8, len: usize) void;

const Canvas = struct {
    height: u32,
    width: u32,
};

const Pixel = struct {
    x: i32,
    y: i32,
    v: u8, // value represent brightness in grey scale
};

const Sprite = struct {
    x: i32,
    y: i32,
    p: []Pixel,
};

var rng = std.rand.DefaultPrng.init(0);
var canvas: Canvas = undefined;
var buffer: []u8 = undefined;

export fn init(width: u32, height: u32) void {
    canvas = Canvas{
        .width = width,
        .height = height,
    };
    const total_size = canvas.width * canvas.height * 4;
    buffer = std.heap.page_allocator.alloc(u8, total_size) catch unreachable;
    var index: usize = 0;
    while (index < buffer.len) : (index += 4) {
        buffer[index + 0] = 0;
        buffer[index + 1] = 0;
        buffer[index + 2] = 0;
        buffer[index + 3] = 0;
    }
}

fn log(message: []const u8) void {
    js_console_log(message.ptr, message.len);
}

export fn go(timeSinceStart: f32) *[]const u8 {
    if (timeSinceStart > 6000) {
        // return undefined;
    }

    // #1
    // const p = createBlurryPoint() catch {
    //     return &buffer; // Exit main function after handling the error
    // };
    // spriteToBuffer(p);
    // freeSprite(p); // Free the sprite after it is no longer needed
    //

    // #2
    drawRandomCircles();
    return &buffer;
}

fn getRandomPixel() [4]u8 {
    return [4]u8{
        rng.random().uintAtMost(u8, 255),
        rng.random().uintAtMost(u8, 255),
        rng.random().uintAtMost(u8, 255),
        255,
    };
}

fn createBlurryPoint() !Sprite {
    const center_x = rng.random().uintAtMost(u32, canvas.width - 1);
    const center_y = rng.random().uintAtMost(u32, canvas.height - 1);
    const spread = 128; // define the blur spread radius

    // Allocate memory for pixels
    const max_pixels = (spread * 2 + 1) * (spread * 2 + 1);
    var allocator = std.heap.page_allocator;
    var pixels = try allocator.alloc(Pixel, max_pixels);

    var i: usize = 0;
    var dy: i32 = -spread;
    while (dy <= spread) : (dy += 1) {
        var dx: i32 = -spread;
        while (dx <= spread) : (dx += 1) {
            // calculate distance from center
            const distance: f32 = @sqrt(@as(f32, @floatFromInt(dx * dx + dy * dy)));
            const max_distance = spread;
            const brightness = (1.0 - distance / max_distance) * 255;

            pixels[i] = Pixel{
                .x = dx,
                .y = dy,
                .v = @intFromFloat(brightness),
            };
            i += 1;
        }
    }

    return Sprite{
        .x = @intCast(center_x),
        .y = @intCast(center_y),
        .p = pixels[0..i],
    };
}

fn spriteToBuffer(s: Sprite) void {
    for (s.p) |pixel| {
        const x = pixel.x + s.x;
        const y = pixel.y + s.y;
        drawPixelToBuffer(x, y, pixel.v);
    }
}

fn freeSprite(sprite: Sprite) void {
    std.heap.page_allocator.free(sprite.p);
}

fn drawRandomCircles() void {
    const numOfCircles = 8;
    const maxRadius = 160;

    var index: u32 = 0;

    while (index < numOfCircles) {
        const posx = rng.random().uintAtMost(u32, canvas.width);
        const posy = rng.random().uintAtMost(u32, canvas.height);
        const r = rng.random().uintAtMost(u8, maxRadius);
        drawCircle(@intCast(posx), @intCast(posy), r);
        index += 1;
    }
}

fn drawCircle(cx: i32, cy: i32, radius: i32) void {
    var x: i32 = radius;
    var y: i32 = 0;
    var decision_over2: i32 = 1 - x; // Decision criterion divided by 2 evaluated at (radius, 0)

    while (x >= y) {
        // Drawing all the points in all octants of the circle
        drawPixelToBuffer(cx + x, cy + y, 255);
        drawPixelToBuffer(cx + y, cy + x, 255);
        drawPixelToBuffer(cx - y, cy + x, 255);
        drawPixelToBuffer(cx - x, cy + y, 255);
        drawPixelToBuffer(cx - x, cy - y, 255);
        drawPixelToBuffer(cx - y, cy - x, 255);
        drawPixelToBuffer(cx + y, cy - x, 255);
        drawPixelToBuffer(cx + x, cy - y, 255);

        y += 1;
        if (decision_over2 <= 0) {
            decision_over2 += 2 * y + 1; // Change in decision criterion for y -> y+1
        } else {
            x -= 1;
            decision_over2 += 2 * (y - x) + 1; // Change for y -> y+1 and x -> x-1
        }
    }
    if (radius > 8) {
        drawCircle(cx, cy, radius - 1);
    }
}

fn drawPixelToBuffer(x: i32, y: i32, brightness: u8) void {
    if (x >= 0 and y >= 0 and x < canvas.width and y < canvas.height) {
        const buffer_index: u32 = (@as(u32, @intCast(y)) * canvas.width + @as(u32, @intCast(x))) * 4;
        if (buffer_index + 3 < buffer.len) {
            buffer[buffer_index + 0] = brightness / 3 + buffer[buffer_index + 0]; // Red
            buffer[buffer_index + 1] = brightness / 2 + buffer[buffer_index + 1]; // Green
            buffer[buffer_index + 2] = brightness / 2 + buffer[buffer_index + 2]; // Blue
            // buffer[buffer_index + 3] = pixel.v; // Alpha
            buffer[buffer_index + 3] = 255; // Alpha
        }
    }
}
