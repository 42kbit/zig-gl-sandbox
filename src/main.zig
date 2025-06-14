const std = @import("std");
const glfw = @import("zglfw");

const gl = @import("gl");

var gl_procs: gl.ProcTable = undefined;

extern fn glGetString(c_int) [*c]const u8;

pub fn main() !void {
    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    //Example of something that fails with GLFW_NOT_INITIALIZED - but will continue with execution
    //var monitor: ?*glfw.Monitor = glfw.getPrimaryMonitor();

    try glfw.init();
    defer glfw.terminate();
    std.debug.print("GLFW Init Succeeded.\n", .{});

    const window: *glfw.Window = try glfw.createWindow(800, 640, "Hello World", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);

    if (!gl_procs.init(glfw.getProcAddress)) {
        @panic("could not get glproc");
    }
    gl.makeProcTableCurrent(&gl_procs);

    const version = gl.GetString(gl.VERSION) orelse "unknown";
    std.debug.print("OpenGL version: {s}\n", .{version});

    const target_fps = 60;
    const target_frame_time_ns = @divFloor(1_000_000_000, target_fps);

    var timer = std.time.Timer.start() catch unreachable;

    while (!glfw.windowShouldClose(window)) {
        const frame_start = timer.read();

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        glfw.pollEvents();

        // Clear the screen
        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        glfw.swapBuffers(window);

        // Rate limit
        const frame_end = timer.read();
        const elapsed = frame_end - frame_start;

        if (elapsed < target_frame_time_ns) {
            std.time.sleep(target_frame_time_ns - elapsed);
        }
    }
}
