
get_graphics_info :: (include_system_info: bool = true) -> string {
    renderer := glGetString(GL_RENDERER);
    vendor := glGetString(GL_VENDOR);
    version := glGetString(GL_VERSION);
    glsl_version := glGetString(GL_SHADING_LANGUAGE_VERSION);

    builder: String_Builder;

    append(*builder, tprint("GL Renderer : %\n", to_string(glGetString(GL_RENDERER))));
    append(*builder, tprint("GL Vendor   : %\n", to_string(glGetString(GL_VENDOR))));
    append(*builder, tprint("GL Version  : %\n", to_string(glGetString(GL_VERSION))));
    append(*builder, tprint("GLSL Version: %\n", to_string(glGetString(GL_SHADING_LANGUAGE_VERSION))));
    append(*builder, "\n");

    n_extensions: s32;
    glGetIntegerv(GL_NUM_EXTENSIONS, *n_extensions);

    append(*builder, tprint("GL Extensions: %\n", n_extensions));
    for i: 0..n_extensions - 1 {
        append(*builder, tprint("  %\n", to_string(glGetStringi(GL_EXTENSIONS, cast(u32) i))));
    }
    append(*builder, "\n");

    context_flags: s32;
    profile_mask: s32;
    glGetIntegerv(GL_CONTEXT_FLAGS, *context_flags);
    glGetIntegerv(GL_CONTEXT_PROFILE_MASK, *profile_mask);

    append(*builder, tprint("Context Flags: %\n", context_flags));
    append(*builder, tprint("Profile Mask : %\n", profile_mask));
    append(*builder, "\n");
    
    // GL_RED_BITS :: 0x0D52;
    // GL_GREEN_BITS :: 0x0D53;
    // GL_BLUE_BITS :: 0x0D54;
    // GL_ALPHA_BITS :: 0x0D55;
    // GL_DEPTH_BITS :: 0x0D56;
    // GL_STENCIL_BITS :: 0x0D57;

    // red_bits: s32;
    // green_bits: s32;
    // blue_bits: s32;
    // alpha_bits: s32;
    // depth_bits: s32;
    // stencil_bits: s32;
    // samples: s32;
    // glGetIntegerv(GL_RED_BITS, *red_bits);
    // glGetIntegerv(GL_GREEN_BITS, *green_bits);
    // glGetIntegerv(GL_BLUE_BITS, *blue_bits);
    // glGetIntegerv(GL_ALPHA_BITS, *alpha_bits);
    // glGetIntegerv(GL_DEPTH_BITS, *depth_bits);
    // glGetIntegerv(GL_STENCIL_BITS, *stencil_bits);
    // glGetIntegerv(GL_SAMPLES, *samples);

    // append(*builder, "Framebuffer Config:\n");
    // append(*builder, tprint("  Red Bits    : %d\n", red_bits));
    // append(*builder, tprint("  Green Bits  : %d\n", green_bits));
    // append(*builder, tprint("  Blue Bits   : %d\n", blue_bits));
    // append(*builder, tprint("  Alpha Bits  : %d\n", alpha_bits));
    // append(*builder, tprint("  Depth Bits  : %d\n", depth_bits));
    // append(*builder, tprint("  Stencil Bits: %d\n", stencil_bits));
    // append(*builder, tprint("  Samples     : %d\n", samples));
    // append(*builder, "\n");

    major := glfwGetWindowAttrib(koda.window, GLFW_CONTEXT_VERSION_MAJOR);
    minor := glfwGetWindowAttrib(koda.window, GLFW_CONTEXT_VERSION_MINOR);
    revision := glfwGetWindowAttrib(koda.window, GLFW_CONTEXT_REVISION);
    profile := glfwGetWindowAttrib(koda.window, GLFW_OPENGL_PROFILE);

    append(*builder, tprint("GLFW Context Version: %.%.%\n", major, minor, revision));
    append(*builder, tprint("GLFW OpenGL Profile : %\n", ifx profile == GLFW_OPENGL_CORE_PROFILE then "Core" else "Compatibility"));
    append(*builder, "\n");

    forward_compat := glfwGetWindowAttrib(koda.window, GLFW_OPENGL_FORWARD_COMPAT);
    debug_context := glfwGetWindowAttrib(koda.window, GLFW_OPENGL_DEBUG_CONTEXT);

    append(*builder, tprint("GLFW Forward Compatible: %\n", ifx forward_compat then "TRUE" else "FALSE"));
    append(*builder, tprint("GLFW Debug Context     : %\n", ifx debug_context then "TRUE" else "FALSE"));
    append(*builder, "\n");

    robustness := glfwGetWindowAttrib(koda.window, GLFW_CONTEXT_ROBUSTNESS);
    release_behavior := glfwGetWindowAttrib(koda.window, GLFW_CONTEXT_RELEASE_BEHAVIOR);

    append(*builder, tprint("GLFW Context Robustness      : %\n", robustness));
    append(*builder, tprint("GLFW Context Release Behavior: %\n", release_behavior));
    append(*builder, "\n");

    fb_width: s32;
    fb_height: s32;
    glfwGetFramebufferSize(koda.window, *fb_width, *fb_height);

    append(*builder, tprint("Framebuffer Size: %x%\n", fb_width, fb_height));
    append(*builder, "\n");

    if include_system_info {
        monitor_count: s32;
        monitors := glfwGetMonitors(*monitor_count);
        append(*builder, "Monitor Count: %\n", monitor_count);

        for i: 0..monitor_count - 1 {
            monitor := monitors[i];
            monitor_name := to_string(glfwGetMonitorName(monitor));
            append(*builder, tprint("  Monitor Name              : %\n", monitor_name));

            physical_width_mm: s32;
            physical_height_mm: s32;
            glfwGetMonitorPhysicalSize(monitor, *physical_width_mm, *physical_height_mm);
            append(*builder, tprint("  Physical Size             : %mm x %mm\n", physical_width_mm, physical_height_mm));

            pos_x: s32;
            pos_y: s32;;
            glfwGetMonitorPos(monitor, *pos_x, *pos_y);
            append(*builder, tprint("  Position On Virtual Screen: %, %\n", pos_x, pos_y));

            scale_x: float;
            scale_y: float;
            glfwGetMonitorContentScale(monitor, *scale_x, *scale_y);
            append(*builder, tprint("  Content Scale             : %, %\n", scale_x, scale_y));

            work_area_x: s32;
            work_area_y: s32;
            work_area_width: s32;
            work_area_height: s32;
            glfwGetMonitorWorkarea(monitor, *work_area_x, *work_area_y, *work_area_width, *work_area_height);
            append(*builder, tprint("  Work Area Position        : %, %\n", work_area_x, work_area_y));
            append(*builder, tprint("  Work Area Size            : %x%\n", work_area_width, work_area_height));

            current_mode := glfwGetVideoMode(monitor);
            append(*builder, tprint("  Monitor Video Mode        :\n"));
            append(*builder, tprint("    Resolution  : %x%\n", current_mode.width, current_mode.height));
            append(*builder, tprint("    Refresh Rate: % Hz\n", current_mode.refreshRate));
            append(*builder, tprint("    Color Depth : R% G% B%\n", current_mode.redBits, current_mode.greenBits, current_mode.blueBits));

            mode_count: s32;
            modes := glfwGetVideoModes(monitor, *mode_count);
            append(*builder, tprint("  Supported Video Modes     : %\n", mode_count));
            for a: 0..mode_count - 1 {
                append(*builder, tprint("    %x% @ %Hz (R% G% B%)\n", modes[a].width, modes[a].height, modes[a].refreshRate, modes[a].redBits, modes[a].greenBits, modes[a].blueBits));
            }

            gamma_ramp := glfwGetGammaRamp(monitor);
            append(*builder, tprint("  Gamma Ramp Size           : %\n", gamma_ramp.size));
            append(*builder, "\n");
        }
    }

    return builder_to_string(*builder);
}
