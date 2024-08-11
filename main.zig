const std = @import("std");

extern "env" fn js_console_log(ptr: [*]const u8, len: usize) void;

const MAX_POINTS = 1024;
const MAX_FORCES = 512;

var rng = std.rand.DefaultPrng.init(0);
var app: App = undefined;

const Canvas = struct {
    height: u32,
    width: u32,
};

const Point = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Point {
        return .{
            .x = x,
            .y = y,
        };
    }
};

const AttractorForce = struct {
    origin: *Point,
    radius: f32,
    points: []Point,

    pub fn init(origin: *Point, points: []Point) AttractorForce {
        return .{
            .origin = origin,
            .radius = 1.0,
            .points = points,
        };
    }

    pub fn process(self: *AttractorForce) void {
        for (self.points) |*point| {
            const dx = self.origin.x - point.x;
            const dy = self.origin.y - point.y;
            const distanceSquared = dx * dx + dy * dy;
            if (distanceSquared <= self.radius * self.radius) {
                point.x += dx / 40;
                point.y += dy / 40;
            }
        }
    }
};

const WindForce = struct {
    strength: f32,
    points: []Point,

    pub fn init(strength: f32, points: []Point) WindForce {
        return .{
            .strength = strength,
            .points = points,
        };
    }

    pub fn process(self: *WindForce) void {
        for (self.points) |*point| {
            point.x += self.strength;
        }
    }
};

const Force = union(enum) {
    Attractor: AttractorForce,
    Wind: WindForce,
    Random: RandomForce,

    pub fn process(self: *Force) void {
        switch (self.*) {
            inline else => |*force| force.process(),
        }
    }
};

const RandomForce = struct {
    strength: f32,
    points: []Point,
    target: Point,
    t: f32,

    pub fn init(strength: f32, points: []Point) RandomForce {
        return .{
            .strength = strength,
            .points = points,
            .target = Point.init(0, 0),
            .t = 1.0, // Start at 1.0 to generate a new target immediately
        };
    }

    pub fn process(self: *RandomForce) void {
        if (self.t >= 1.0) {
            // Generate new random target
            self.target.x = rng.random().float(f32) * 2 - 1; // Range: -1 to 1
            self.target.y = rng.random().float(f32) * 2 - 1; // Range: -1 to 1
            self.t = 0.0;
        }

        for (self.points) |*point| {
            // Linear interpolation (lerp)
            point.x += (self.target.x - point.x) * self.strength * self.t;
            point.y += (self.target.y - point.y) * self.strength * self.t;
        }

        self.t += 0.01; // Increase t for smooth transition
    }
};

const App = struct {
    allocator: std.mem.Allocator,
    points: [MAX_POINTS]Point,
    forces: [MAX_FORCES]Force,
    point_count: u16,
    force_count: u16,
    buffer: []u8,
    canvas: Canvas,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !App {
        const buffer = try allocator.alloc(u8, width * height * 4);
        return App{
            .allocator = allocator,
            .points = undefined,
            .forces = undefined,
            .point_count = 0,
            .force_count = 0,
            .buffer = buffer,
            .canvas = Canvas{ .width = width, .height = height },
        };
    }

    pub fn createPoint(self: *App, x: f32, y: f32) *Point {
        // if (self.point_count >= MAX_POINTS) return error.TooManyPoints;
        const index = self.point_count;
        self.points[index] = Point.init(x, y);
        self.point_count += 1;
        return &self.points[index];
    }

    pub fn createAttractor(self: *App, origin: *Point, points: []Point) *Force {
        const index = self.force_count;
        self.forces[index] = Force{ .Attractor = AttractorForce.init(origin, points) };
        self.force_count += 1;
        return &self.forces[index];
    }

    pub fn createWind(self: *App, strength: f32, points: []Point) *Force {
        const index = self.force_count;
        self.forces[index] = Force{ .Wind = WindForce.init(strength, points) };
        self.force_count += 1;
        return &self.forces[index];
    }

    pub fn createRandom(self: *App, strength: f32, points: []Point) *Force {
        const index = self.force_count;
        self.forces[index] = Force{ .Random = RandomForce.init(strength, points) };
        self.force_count += 1;
        return &self.forces[index];
    }

    pub fn deinit(self: *App) void {
        self.allocator.free(self.buffer);
    }

    pub fn clearBuffer(self: *App) void {
        var index: usize = 0;
        while (index < self.buffer.len) : (index += 4) {
            self.buffer[index + 0] = 100;
            self.buffer[index + 1] = 255;
            self.buffer[index + 2] = 123;
            self.buffer[index + 3] = 255;
        }
    }

    pub fn drawPointToBuffer(self: *App, xx: f32, yy: f32, brightness: u8) void {
        const cx: f32 = @floatFromInt(self.canvas.width);
        const cy: f32 = @floatFromInt(self.canvas.height);
        const x: i32 = @intFromFloat((xx / 2 + 0.5) * cx);
        const y: i32 = @intFromFloat((yy / 2 + 0.5) * cy);

        if (x >= 0 and y >= 0 and x < self.canvas.width and y < self.canvas.height) {
            const buffer_index: usize = (@as(usize, @intCast(y)) * self.canvas.width + @as(usize, @intCast(x))) * 4;
            if (buffer_index + 3 < self.buffer.len) {
                @memset(self.buffer[buffer_index..][0..4], brightness);
                self.buffer[buffer_index + 3] = 255;
            }
        }
    }
};

export fn init(width: u32, height: u32) void {
    const allocator = std.heap.page_allocator;
    app = App.init(allocator, width, height) catch unreachable;
    defer app.deinit();

    _ = app.createPoint(0.0, 0.0);

    const p1 = app.createPoint(0.6, 0.6);
    const p2 = app.createPoint(0.0, 0.6);
    const p3 = app.createPoint(0.6, -0.6);

    _ = app.createAttractor(p1, app.points[0..1]);
    _ = app.createAttractor(p2, app.points[0..1]);
    _ = app.createAttractor(p3, app.points[0..1]);

    _ = app.createRandom(0.001, app.points[1..4]);

    app.clearBuffer();
}

export fn go() [*]const u8 {
    for (app.points) |point| {
        app.drawPointToBuffer(point.x, point.y, 255);
    }

    for (app.forces[0..app.force_count], 0..) |force, i| {
        app.forces[i].process();
        switch (force) {
            .Attractor => |attractor| app.drawPointToBuffer(attractor.origin.x, attractor.origin.y, 0),
            .Wind => {}, // Wind forces are not drawn
            .Random => {}, // Wind forces are not drawn
        }
    }

    return app.buffer.ptr;
}

fn log(message: []const u8) void {
    js_console_log(message.ptr, message.len);
}

fn logInt(value: i32) void {
    var buf: [32]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return;
    log(formatted);
}
