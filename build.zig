const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // is not required, since "glfw" dependency links glfw
    // exe.linkSystemLibrary("glfw");

    // read the dependency from build.zig.zon file of the project
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    // Choose the OpenGL API, version, profile and extensions you want to generate bindings for.
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.3",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });

    const fs = std.fs;
    const allocator = b.allocator;

    const bins_sub_path = "src/bin";
    // Open the `src` directory
    var src_dir = fs.cwd().openDir(bins_sub_path, .{
        .iterate = true,
    }) catch @panic("Failed to open \"src/bin\" directory");

    var iter = src_dir.iterate();
    while (true) {
        const entry = iter.next() catch @panic("Failed to iterate src");
        if (entry == null) break;

        const dir_entry = entry.?;
        if (dir_entry.kind != .directory) continue;

        const project_name = dir_entry.name;
        const project_path = std.fs.path.join(allocator, &[_][]const u8{
            bins_sub_path, project_name, "main.zig",
        }) catch @panic("OOM");

        const exe = b.addExecutable(.{
            .name = project_name,
            .root_source_file = b.path(project_path),
            .target = target,
            .optimize = optimize,
        });

        // Note: for glfw, libc is required in case you'll get segfaults
        exe.root_module.addImport(
            "zglfw", // name of the module as it appears in @import
            // name within the 'build.zig' as declared the fetched module code
            // though the package is called 'zglfw', the module is named 'glfw'
            // https://github.com/IridescenceTech/zglfw/blob/5d25d66b3d4912c9cb66e4db9dfb80a6eecc84ad/build.zig#L7C35-L7C39
            zglfw.module("glfw"),
        );

        // Import the generated module.
        exe.root_module.addImport("gl", gl_bindings);

        const install_exe = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install_exe.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_exe.step);

        const step_name = b.fmt("run-{s}", .{project_name});
        const run_step = b.step(step_name, b.fmt("Run {s}", .{project_name}));
        run_step.dependOn(&run_cmd.step);
    }
}
