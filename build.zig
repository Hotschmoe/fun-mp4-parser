const std = @import("std");

// This is the build script for our MP4 Parser WebAssembly project
pub fn build(b: *std.Build) void {
    // Standard target options for WebAssembly
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    });

    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});

    // Create an executable that compiles to WebAssembly
    // For WebAssembly, we use addExecutable instead of addSharedLibrary
    const exe = b.addExecutable(.{
        .name = "mp4_parser",
        .root_source_file = b.path("src/mp4_parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Important WASM-specific settings
    exe.rdynamic = true;

    // Disable entry point for WebAssembly
    exe.entry = .disabled;

    // Install in the output directory
    b.installArtifact(exe);

    // Create a step to clear the www directory
    const clear_www = b.addSystemCommand(&[_][]const u8{ "powershell", "-Command", "if (Test-Path www) { Remove-Item -Path www\\* -Recurse -Force }; if (-not (Test-Path www)) { New-Item -ItemType Directory -Path www }" });

    // Create a step to copy the WASM file to the www directory
    const copy_wasm = b.addSystemCommand(&[_][]const u8{
        "powershell",                                        "-Command",            "Copy-Item",
        b.fmt("{s}/bin/mp4_parser.wasm", .{b.install_path}), "www/mp4_parser.wasm",
    });
    copy_wasm.step.dependOn(b.getInstallStep());
    copy_wasm.step.dependOn(&clear_www.step);

    // Create a step to copy the index.html file to the www directory
    const copy_html = b.addSystemCommand(&[_][]const u8{
        "powershell", "-Command",       "Copy-Item",
        "index.html", "www/index.html",
    });
    copy_html.step.dependOn(&clear_www.step);

    // Create a step to copy all files from the assets directory to the www directory
    const copy_assets = b.addSystemCommand(&[_][]const u8{ "powershell", "-Command", "if (Test-Path assets) { Copy-Item -Path assets\\* -Destination www\\ -Recurse -Force }" });
    copy_assets.step.dependOn(&clear_www.step);

    // Add a run step to start a Python HTTP server
    // Try both 'py' and 'python' commands to be compatible with different systems
    const run_cmd = b.addSystemCommand(&[_][]const u8{ "powershell", "-Command", "cd www; try { py -m http.server 8000 } catch { python -m http.server 8000 }" });
    run_cmd.step.dependOn(&copy_wasm.step);
    run_cmd.step.dependOn(&copy_html.step);
    run_cmd.step.dependOn(&copy_assets.step);

    const run_step = b.step("run", "Build, deploy, and start HTTP server");
    run_step.dependOn(&run_cmd.step);

    // Add a deploy step that only copies the files without starting the server
    const deploy_step = b.step("deploy", "Build and copy files to www directory");
    deploy_step.dependOn(&copy_wasm.step);
    deploy_step.dependOn(&copy_html.step);
    deploy_step.dependOn(&copy_assets.step);
}

// To set 'python' as an alias for 'py' on Windows:
// 1. Open PowerShell as administrator
// 2. Run: New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\python.exe" -Target "$env:USERPROFILE\py.exe"
// Or add this to your PowerShell profile:
// Set-Alias -Name python -Value py
