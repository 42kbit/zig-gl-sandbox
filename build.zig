const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // I took the build script parts from zglfw
    // https://github.com/IridescenceTech/zglfw
    const exe = b.addExecutable(.{
        .name = "gl-sandbox",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // libc is required to run glfw
    });

    // is not required, since "glfw" dependency links glfw
    // exe.linkSystemLibrary("glfw");

    // read the dependency from build.zig.zon file of the project
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport(
        "zglfw", // name of the module as it appears in @import
        // name within the 'build.zig' as declared the fetched module code
        // though the package is called 'zglfw', the module is named 'glfw'
        // https://github.com/IridescenceTech/zglfw/blob/5d25d66b3d4912c9cb66e4db9dfb80a6eecc84ad/build.zig#L7C35-L7C39
        zglfw.module("glfw"),
    );

    // Choose the OpenGL API, version, profile and extensions you want to generate bindings for.
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.3",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });

    // Import the generated module.
    exe.root_module.addImport("gl", gl_bindings);

    // const zgl = b.dependency("zgl", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // exe.root_module.addImport("zgl", zgl.module("zgl"));
    // link libGL.so
    // Note "GL" should be used instead of "gl"
    //
    // Verify that you have it with:
    // ls -al /lib/x86_64-linux-gnu/ | grep libGL.so
    // exe.linkSystemLibrary("GL");

    // same as b.installArtifact(exe), view std for details
    const install_exe = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);

    // create a run artifact step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&install_exe.step);

    // create a run command
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
