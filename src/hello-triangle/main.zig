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

    const WindowDimensions = struct {
        width: c_int,
        height: c_int,
    };

    const window_dimensions: WindowDimensions = .{
        .width = 800,
        .height = 600,
    };

    const window: *glfw.Window = try glfw.createWindow(
        window_dimensions.width,
        window_dimensions.height,
        "Hello World",
        null,
        null,
    );
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

    var timer = try std.time.Timer.start();

    const verticies = [_][3]f32{
        [_]f32{ -0.5, -0.5, 0.0 },
        [_]f32{ 0.5, -0.5, 0.0 },
        [_]f32{ 0.0, 0.5, 0.0 },
    };

    const nverts: comptime_int = verticies.len;
    const nvert_attritubes: comptime_int = verticies[0].len;

    // Cast "verticies" to a 1D array
    const v_ptr: *const [nverts * nvert_attritubes]f32 = @ptrCast(&verticies);

    var vbo: gl.uint = undefined;
    // ptrCast is used to cast *gl.uint to [*]gl.uint
    gl.GenBuffers(1, @ptrCast(&vbo));

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(
        gl.ARRAY_BUFFER,
        nverts * nvert_attritubes * @sizeOf(f32),
        v_ptr,
        gl.STATIC_DRAW,
    );
    defer gl.DeleteBuffers(1, @ptrCast(&vbo));

    while (!glfw.windowShouldClose(window)) {
        const frame_start = timer.read();

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // Clear the screen
        gl.ClearColor(0.0, 0.0, 1.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
        // Manually describe vertex layout each time:
        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            3 * @sizeOf(f32),
            0,
        );

        // Draw
        gl.DrawArrays(gl.TRIANGLES, 0, 3);

        // Optionally disable again (not strictly required)
        gl.DisableVertexAttribArray(0);

        // Rate limit
        const frame_end = timer.read();
        const elapsed = frame_end - frame_start;

        if (elapsed < target_frame_time_ns) {
            std.time.sleep(target_frame_time_ns - elapsed);
        }

        glfw.pollEvents();
        glfw.swapBuffers(window);
    }
}
