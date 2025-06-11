
#if ALLOW_EXPORTS {
    #program_export "NvOptimusEnablement"
    NvOptimusEnablement: u32 = 1;

    #program_export "AmdPowerXpressRequestHighPerformance"
    AmdPowerXpressRequestHighPerformance: s32 = 1;

    // this was found online as something that disables nahimic and sonar
    // which reportedly cause problems with opengl
    // I haven't experienced these problems and it kind of seems like a crazy
    // conspiracy theory to me but I can't imagine how adding this function export
    // would hurt anything in any way so here we are
    #program_export "NoHotPatch"
    NoHotPatch :: () #c_call {}
}

koda_init :: () {
    glfwSetErrorCallback(error_callback);
    if !glfwInit() {
        print("Exited because glfw could not initialize.\n");
        exit(-1);
    }

    init_default_shaders();
    parallel_init();

    koda.initialized = true;
}

get_window :: () -> *GLFWwindow {
    return koda.window;
}

create_window :: (title: *u8, width: s32, height: s32, multisample: int = 0) {
    if !koda.initialized {
        print("Cannot create window before initializing.\n");
        return;
    }

    if !width || !height {
        width = 1920;
        height = 1080;

        monitor := glfwGetPrimaryMonitor();
        video_mode := glfwGetVideoMode(monitor);
        if video_mode {
            if video_mode.height <= 900 || video_mode.width <= 1600 {
                width = 1366;
                height = 768;
            } else if video_mode.height <= 1080 || video_mode.width <= 1920 {
                width = 1600;
                height = 900;
            }
        }
    }

    monitor_width = width;
    monitor_height = height;
    monitor := glfwGetPrimaryMonitor();
    if monitor {
        video_mode := glfwGetVideoMode(monitor);
        if video_mode {
            monitor_width = video_mode.width;
            monitor_height = video_mode.height;
        }
    }

    if multisample {
        glfwWindowHint(GLFW_SAMPLES, xx multisample);
        glEnable(GL_MULTISAMPLE);
    }

    #if OS == .MACOS {
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
    }

    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_API);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    #if !PRODUCTION {
        glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GLFW_TRUE);

        gl_enable_debug_output(true);
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, MINIMUM_GL_MAJOR_VERSION);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, MINIMUM_GL_MINOR_VERSION);
    koda.window = glfwCreateWindow(width, height, title, null, null);
    if !koda.window {
        glfwTerminate();
        print("Cannot create window.\n");
        return;
    }

    glfwSetWindowPos(koda.window, cast(s32) (monitor_width - width) / 2, cast(s32) (monitor_height - height) / 2);

    glfwMakeContextCurrent(koda.window);
    gl_load(*gl, glfwGetProcAddress);

    renderer := glGetString(GL_RENDERER);
    vendor := glGetString(GL_VENDOR);
    version := glGetString(GL_VERSION);

    print("GL Renderer: %\n", to_string(renderer));
    print("GL Vendor: %\n", to_string(vendor));
    print("GL Version: %\n", to_string(version));

    graphics_info := get_graphics_info();
    defer free(graphics_info);
    wrote_graphics_info := write_entire_file("graphics_info.txt", graphics_info);
    print("Wrote graphics info: %\n", wrote_graphics_info);

    glfwSetInputMode(koda.window, GLFW_STICKY_MOUSE_BUTTONS, GLFW_TRUE);
    glfwSetInputMode(koda.window, GLFW_STICKY_KEYS, GLFW_TRUE);
    glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
    glfwSetScrollCallback(koda.window, scroll_callback);
    glfwSetWindowSizeCallback(koda.window, size_callback);
    glfwSetWindowFocusCallback(koda.window, focus_callback);
    window_focused = true;


    glfwSetCharCallback(koda.window, char_input_callback);

    // cursor := glfwCreateStandardCursor(GLFW_ARROW_CURSOR);
    // glfwSetCursor(koda.window, null);

    // TODO listen to window position change, and current monitor and monitor size

    maximum_fragment: s32;
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, *maximum_fragment);
    if !maximum_fragment {
        maximum_fragment = 16;
    }
    koda.maximum_active_texture_count = maximum_fragment;

    print("GL Texture Cache Size: %\n", maximum_fragment);

    set_vsync(false);
    set_target_fps(0);

    set_viewport(width, height);

    set_blend(true);
    set_blend_equation_separate(.Add, .Add);
    set_blend_func_separate(.SrcAlpha, .OneMinusSrcAlpha, .One, .One);

    set_front_face_ccw(true);
    set_depth_test(true);
    set_cull_face(true);

    glClearColor(0.0, 0.0, 0.0, 1.0);

    register_program_exit();

    static_sprite = create_sprite(.{}, 0, 0);
}

destroy_window :: () {
    set_accurate_sleep(false);

    glfwDestroyWindow(koda.window);
    glfwTerminate();
}

register_program_exit :: () {
    generic_close_callback :: () #c_call {
        new_context: #Context;
        push_context new_context {
            set_accurate_sleep(false);
            request_exit();
        }
    }
    glfw_close_callback :: (window: *GLFWwindow) #c_call {
        generic_close_callback();
    }
    glfwSetWindowCloseCallback(koda.window, glfw_close_callback);

    #if OS == .WINDOWS {
        DWORD :: u32;
        BOOL :: enum s32 { FALSE :: 0; TRUE :: 1; }
        HandlerRoutine :: #type (dwCtrlType: DWORD) -> BOOL #c_call;

        kernel32 :: #system_library "kernel32";
        SetConsoleCtrlHandler :: (handler_routine: HandlerRoutine, add: BOOL) -> BOOL #foreign kernel32;

        ctrl_handler :: (dwCtrlType: DWORD) -> BOOL #c_call {
            generic_close_callback();
            return .TRUE;
        }
        SetConsoleCtrlHandler(ctrl_handler, .TRUE);
    }
}

get_accurate_sleep :: () -> bool {
    return accurate_sleep;
}

#if OS == .WINDOWS {
    // it's very important this method undoes itself because it affects the operating system lmao...
    set_accurate_sleep :: (enabled: bool) {
        Windows :: #import "Windows";

        if accurate_sleep == enabled {
            return;
        }
        accurate_sleep = enabled;

        if accurate_sleep {
            Windows.timeBeginPeriod(1);
        } else {
            Windows.timeEndPeriod(1);
        }
    }
} else {
    set_accurate_sleep :: (enabled: bool) #expand {}
}

set_icon :: (image: Image) {
    assert(image.format == .RGBA8, "Your window icon must be of format RGBA8.");
    glfw_image: GLFWimage;
    glfw_image.width = cast(s32) image.width;
    glfw_image.height = cast(s32) image.height;
    glfw_image.pixels = image.pixels.data;

    glfwSetWindowIcon(koda.window, 1, *glfw_image);
}

set_viewport :: (width: int, height: int) {
    if !width && !height {
        return;
    }

    koda.width = width;
    koda.height = height;

    glViewport(0, 0, xx width, xx height);
}

error_check_gl :: ($full_stack := false) -> bool #expand {
    #if PRODUCTION {
        return;
    }

    errored := false;
    err := glGetError();
    while err != GL_NO_ERROR {
        print("GL error: %\n", err);
        #if full_stack {
            print_stack_trace();
        } else {
            print_caller_trace();
        }
        err = glGetError();
        errored = true;
    }

    return errored;
}

koda_should_exit :: (swap_buffer_hook: () = null, swap_buffer_hook_render: () = null) -> bool {
    if glfwWindowShouldClose(koda.window) == GLFW_TRUE {
        return true;
    }

    #if !PRODUCTION {
        error_check_gl();
    }

    // don't swap buffers when entering the loop since you might have drawn to it already
    if koda.time_tracker.last_loop_time > 0 {
        if swap_buffer_hook {
            swap_buffer_hook();
        }
        swap_buffers();
    }

    time := seconds_since_init();

    // sleep if desired
    manual_vsync := !get_fullscreen() && can_vsync_wait();
    if vsync_enabled && manual_vsync {
        // we'll manually control vsync if it's not full screen mode
        vsync_wait();
    } else if !vsync_enabled && koda.time_tracker.target_fps > 0 {
        desired_tick_duration := cast(float64) 1000.0 / cast(float64) koda.time_tracker.target_fps;

        last_loop_time := koda.time_tracker.last_loop_time;
        if last_loop_time > 0 {
            time = seconds_since_init();
            last_tick_duration := (time - last_loop_time) * 1000.0;
            desired_sleep_time := max(desired_tick_duration - last_tick_duration, 0);

            if locked_frames {
                if !locked_frames_start {
                    locked_frames_start = time;
                }

                locked_frames_count += 1;

                delta := time * 1000.0 - locked_frames_start * 1000.0;
                desired_frame_delta := locked_frames_count * desired_tick_duration;
                desired_sleep_time = max(desired_frame_delta - delta, 0);
            }

            while desired_sleep_time > 0 {
                can_reliably_sleep := desired_sleep_time >= cast(float64) time_slice_ms;
                if can_reliably_sleep {
                    set_accurate_sleep(true);
                    defer set_accurate_sleep(false);

                    actual_sleep_time := max(desired_sleep_time - time_slice_ms, 0);
                    if actual_sleep_time > 0 {
                        sleep_milliseconds(cast(s32) actual_sleep_time);
                    }
                }

                time = seconds_since_init();
                last_tick_duration = (time - last_loop_time) * 1000.0;
                desired_sleep_time = max(desired_tick_duration - last_tick_duration, 0);
            }
        }
    }

    tick_frame_tracker(*koda.frame_tracker, time);
    koda.time_tracker.last_loop_time = time;

    // TODO is this the right place for this?
    glfwPollEvents();

    // if mouse_boundary_enabled {
    //     mouse_x: float64;
    //     mouse_y: float64;
    //     glfwGetCursorPos(koda.window, *mouse_x, *mouse_y);

    //     if mouse_x < 0 || mouse_x > cast(float64) koda.width - 1 || mouse_y < 0 || mouse_y > cast(float64) koda.height - 1 {
    //         clamped_x := clamp(mouse_x, 0, cast(float64) koda.width - 1);
    //         clamped_y := clamp(mouse_y, 0, cast(float64) koda.height - 1);

    //         glfwSetCursorPos(koda.window, clamped_x, clamped_y);
    //     }
    // }

    return false;
}

request_exit :: () {
    glfwSetWindowShouldClose(koda.window, GLFW_TRUE);
}

swap_buffers :: () {
    glfwSwapBuffers(koda.window);

    width: s32;
    height: s32;
    glfwGetFramebufferSize(koda.window, *width, *height);
    if koda.width != width || koda.height != height {
        set_viewport(koda.width, koda.height);
    }
}

get_locked_frames :: () -> bool {
    return locked_frames;
}

set_locked_frames :: (locked: bool) {
    locked_frames = locked;
    locked_frames_start = 0;
    locked_frames_count = 0;
}

can_vsync_wait :: () -> bool {
    return false;

    // #if OS == .WINDOWS {
    //     return true;
    // } else {
    //     return false;
    // }
}

vsync_wait :: () {
    #if OS == .WINDOWS {
        Dwmapi :: #system_library "Dwmapi";
        DwmFlush :: () -> s32 #foreign Dwmapi;
        if DwmFlush() {
            print("Vsync wait error.\n");
        }
    }
}

get_vsync_rate :: () -> int {
    monitor := glfwGetPrimaryMonitor();
    video_mode := glfwGetVideoMode(monitor);

    if !video_mode {
        return 0;
    }

    return video_mode.refreshRate;
}

get_fullscreen :: () -> bool, bool {
    fullscreen := !!glfwGetWindowMonitor(koda.window);
    borderless := !glfwGetWindowAttrib(koda.window, GLFW_DECORATED);
    return fullscreen, borderless;
}

set_fullscreen :: (fullscreen: bool, borderless: bool, width: int = 0, height: int = 0) {
    assert(!fullscreen || !borderless, "You cannot have fullscreen and borderless enabled.\n");

    monitor := glfwGetPrimaryMonitor();
    video_mode := glfwGetVideoMode(monitor);

    if !video_mode {
        return;
    }

    if borderless {
        glfwWindowHint(GLFW_RED_BITS, video_mode.redBits);
        glfwWindowHint(GLFW_GREEN_BITS, video_mode.greenBits);
        glfwWindowHint(GLFW_BLUE_BITS, video_mode.blueBits);
        glfwWindowHint(GLFW_REFRESH_RATE, video_mode.refreshRate);
    }

    if fullscreen {
        if !width then width = video_mode.width;
        if !height then height = video_mode.height;

        // TODO why isn't monitor being used???
        // TODO use GLFW_DONT_CARE for refresh rate
        set_window_size(width, height);
        glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_FALSE);
        glfwSetWindowMonitor(koda.window, monitor, 0, 0, cast(s32) width, cast(s32) height, video_mode.refreshRate);
        set_vsync(get_vsync());
    } else if borderless {
        if !width then width = video_mode.width;
        if !height then height = video_mode.height;

        set_window_size(width, height);
        glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_FALSE);
        glfwSetWindowMonitor(koda.window, null, cast(s32) (video_mode.width - width) / 2, cast(s32) (video_mode.height - height) / 2, cast(s32) width, cast(s32) height, GLFW_DONT_CARE);
        glfwSetWindowPos(koda.window, cast(s32) (video_mode.width - width) / 2, cast(s32) (video_mode.height - height) / 2);
        set_vsync(get_vsync());
    } else if !borderless {
        if !width then width = koda.width;
        if !height then height = koda.height;

        glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_TRUE);
        glfwSetWindowMonitor(koda.window, null, cast(s32) (video_mode.width - width) / 2, cast(s32) (video_mode.height - height) / 2, cast(s32) width, cast(s32) height, GLFW_DONT_CARE);
        glfwSetWindowPos(koda.window, cast(s32) (video_mode.width - width) / 2, cast(s32) (video_mode.height - height) / 2);
        glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_TRUE);
        set_window_size(width, height);
        set_vsync(get_vsync());
    }

    resolve_mouse_capture();
}

get_window_size :: () -> int, int {
    width: s32;
    height: s32;
    glfwGetWindowSize(koda.window, *width, *height);
    return width, height;
}

set_window_size :: (width: int, height: int) {
    glfwSetWindowSize(koda.window, cast(s32) width, cast(s32) height);
    set_viewport(width, height);
}

// I can't tell that this does anything at all so I'm removing it for now
// get_adaptive_vsync :: () -> bool {
//     return adaptive_vsync_enabled;
// }

// set_adaptive_vsync :: (enabled: bool) {
//     // I can't tell this makes any difference at all tbh... if anything it makes the interpolation worse?
//     adaptive_vsync_enabled = enabled;

//     if enabled {
//         print("Adaptive sync allowed? %\n", !!glfwExtensionSupported("WGL_EXT_swap_control_tear"));
//     }

//     set_vsync(enabled);
// }

get_vsync :: () -> bool {
    return vsync_enabled;
}

set_vsync :: (vsync: bool) {
    vsync_enabled = vsync;
    manual_vsync := !get_fullscreen() && can_vsync_wait();

    if vsync_enabled && !manual_vsync {
        glfwSwapInterval(xx (ifx adaptive_vsync_enabled then -1 else 1));
    } else {
        glfwSwapInterval(0);
    }
}

get_target_fps :: () -> float {
    return koda.time_tracker.target_fps;
}

set_target_fps :: (target: float) {
    koda.time_tracker.target_fps = target;
}

get_mouse_capture :: () -> bool {
    return mouse_capture;
}

set_mouse_capture :: (capture: bool) {
    // if mouse_capture != capture {
    //     // if capture {
    //     //     mouse_currently_captured = true;
    //     // }

    // }

    mouse_capture = capture;

    resolve_mouse_capture();
}

get_mouse_boundary :: () -> bool {
    return mouse_boundary_enabled;
}

set_mouse_boundary :: (enabled: bool) {
    mouse_boundary_enabled = enabled;

    resolve_mouse_capture();
}

get_mouse_currently_captured :: () -> bool {
    return glfwGetInputMode(koda.window, GLFW_CURSOR) == GLFW_CURSOR_DISABLED;
}

get_focused :: () -> bool {
    return window_focused;
}

request_focus :: () {
    glfwFocusWindow(koda.window);
}

get_front_face_ccw :: () -> bool {
    front_facing: GLint;
    glGetIntegerv(GL_FRONT_FACE, *front_facing);
    return front_facing == GL_CCW;
}

set_front_face_ccw :: (ccw: bool) {
    if ccw {
        glFrontFace(GL_CCW);
    } else {
        glFrontFace(GL_CW);
    }
}

set_front_face_ccw_scope :: (ccw: bool) #expand {
    old_ccw := get_front_face_ccw();
    `defer set_front_face_ccw(old_ccw);

    set_front_face_ccw(ccw);
}

PolygonMode :: enum s32 {
    Line;
    Fill;
}

convert_polygon_mode :: (mode: PolygonMode) -> u32 {
    if #complete mode == {
        case .Line;
            return GL_LINE;
        case .Fill;
            return GL_FILL;
    }
}

convert_polygon_mode :: (mode: u32) -> PolygonMode {
    if mode == {
        case GL_LINE;
            return .Line;
        case GL_FILL;
            return .Fill;
        case;
            print("Unhandled polygon mode. %\n", mode);
            return .Fill;
    }
}

get_polygon_mode :: () -> PolygonMode, PolygonMode {
    polygon_mode: [2] s32;
    glGetIntegerv(GL_FRONT, *polygon_mode[0]);
    glGetIntegerv(GL_BACK, *polygon_mode[1]);

    return convert_polygon_mode(polygon_mode[0]), convert_polygon_mode(polygon_mode[1]);
}

set_polygon_mode :: (mode: PolygonMode) {
    gl_mode := convert_polygon_mode(mode);

    glPolygonMode(GL_FRONT_AND_BACK, gl_mode);
}

set_polygon_mode_scope :: (mode: PolygonMode) #expand {
    old_polygon_mode: [2] s32;
    glGetIntegerv(GL_FRONT, *old_polygon_mode[0]);
    glGetIntegerv(GL_BACK, *old_polygon_mode[1]);

    `defer glPolygonMode(GL_FRONT, cast(u32) old_polygon_mode[0]);
    `defer glPolygonMode(GL_BACK, cast(u32) old_polygon_mode[1]);

    set_polygon_mode(mode);
}

DepthFunc :: enum s32 {
    Never;
    Less;
    Greater;
    Equal;
    Always;
    LessEqual;
    GreaterEqual;
    NotEqual;
}

get_depth_func :: () -> DepthFunc {
    func: s32;
    glGetIntegerv(GL_DEPTH_FUNC, *func);

    if func == GL_ALWAYS {
        return DepthFunc.Always;
    } else if func == GL_GEQUAL {
        return DepthFunc.GreaterEqual;
    } else if func == GL_NOTEQUAL {
        return DepthFunc.NotEqual;
    } else if func == GL_LEQUAL {
        return DepthFunc.LessEqual;
    } else if func == GL_GREATER {
        return DepthFunc.Greater;
    } else if func == GL_EQUAL {
        return DepthFunc.Equal;
    } else if func == GL_LESS {
        return DepthFunc.Less;
    } else if func == GL_NEVER {
        return DepthFunc.Never;
    } else {
        return DepthFunc.Never;
    }
}

set_depth_func :: (func: DepthFunc) {
    if #complete func == {
        case .Never;
            glDepthFunc(GL_NEVER);
        case .Less;
            glDepthFunc(GL_LESS);
        case .Greater;
            glDepthFunc(GL_GREATER);
        case .Equal;
            glDepthFunc(GL_EQUAL);
        case .Always;
            glDepthFunc(GL_ALWAYS);
        case .LessEqual;
            glDepthFunc(GL_LEQUAL);
        case .GreaterEqual;
            glDepthFunc(GL_GEQUAL);
        case .NotEqual;
            glDepthFunc(GL_NOTEQUAL);
    }
}

set_depth_func_scope :: (func: DepthFunc) #expand {
    old_func := get_depth_func();
    `defer set_depth_func(old_func);

    set_depth_func(func);
}

get_color_write :: () -> bool {
    enabled: [4] GLboolean;
    glGetBooleanv(GL_COLOR_WRITEMASK, enabled.data);
    return enabled[0];
}

set_color_write :: (enabled: bool) {
    if enabled {
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    } else {
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
    }
}

set_color_write_scope :: (enabled: bool) #expand {
    old_enabled := get_color_write();
    `defer set_color_write(old_enabled);

    set_color_write(enabled);
}

get_depth_write :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_DEPTH_WRITEMASK, *enabled);
    return enabled;
}

set_depth_write :: (enabled: bool) {
    if enabled {
        glDepthMask(GL_TRUE);
    } else {
        glDepthMask(GL_FALSE);
    }
}

set_depth_write_scope :: (enabled: bool) #expand {
    old_enabled := get_depth_write();
    `defer set_depth_write(old_enabled);

    set_depth_write(enabled);
}

get_depth_test :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_DEPTH_TEST, *enabled);
    return enabled;
}

set_depth_test :: (enabled: bool) {
    if enabled {
        glEnable(GL_DEPTH_TEST);
    } else {
        glDisable(GL_DEPTH_TEST);
    }
}

set_depth_test_scope :: (enabled: bool) #expand {
    old_enabled := get_depth_test();
    `defer set_depth_test(old_enabled);

    set_depth_test(enabled);
}

get_blend :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_BLEND, *enabled);
    return enabled;
}

set_blend :: (enabled: bool) {
    if enabled {
        glEnable(GL_BLEND);
    } else {
        glDisable(GL_BLEND);
    }
}

set_blend_scope :: (enabled: bool) #expand {
    old_enabled := get_blend();
    `defer set_blend(old_enabled);

    set_blend(enabled);
}

BlendEquation :: enum {
    Add;
    Subtract;
    ReverseSubtract;
    Min;
    Max;
}

convert_blend_equation :: (value: BlendEquation) -> u32 {
    if #complete value == {
        case .Add;
            return GL_FUNC_ADD;
        case .Subtract;
            return GL_FUNC_SUBTRACT;
        case .ReverseSubtract;
            return GL_FUNC_REVERSE_SUBTRACT;
        case .Min;
            return GL_MIN;
        case .Max;
            return GL_MAX;
    }
}

convert_blend_equation :: (value: u32) -> BlendEquation {
    if value == GL_FUNC_ADD {
        return .Add;
    } else if value == GL_FUNC_SUBTRACT {
        return .Subtract;
    } else if value == GL_FUNC_REVERSE_SUBTRACT {
        return .ReverseSubtract;
    } else if value == GL_MIN {
        return .Min;
    } else if value == GL_MAX {
        return .Max;
    }

    return .Add;
}

get_blend_equation :: () -> BlendEquation {
    real_equation: s32;
    glGetIntegerv(GL_BLEND_EQUATION_RGB, *real_equation);
    equation := convert_blend_equation(cast(u32) real_equation);

    return equation;
}

set_blend_equation :: (equation: BlendEquation) {
    real_equation := convert_blend_equation(equation);

    glBlendEquation(real_equation);
}

set_blend_equation_scope :: (equation: BlendEquation) #expand {
    old_rgb, old_alpha := get_blend_equation_separate();
    `defer set_blend_equation_separate(old_rgb, old_alpha);

    set_blend_equation(equation);
}

get_blend_equation_separate :: () -> BlendEquation, BlendEquation {
    real_rgb: s32;
    glGetIntegerv(GL_BLEND_EQUATION_RGB, *real_rgb);
    rgb := convert_blend_equation(cast(u32) real_rgb);

    real_alpha: s32;
    glGetIntegerv(GL_BLEND_EQUATION_ALPHA, *real_alpha);
    alpha := convert_blend_equation(cast(u32) real_alpha);

    return rgb, alpha;
}

set_blend_equation_separate :: (rgb: BlendEquation, alpha: BlendEquation) {
    real_rgb := convert_blend_equation(rgb);
    real_alpha := convert_blend_equation(alpha);

    glBlendEquationSeparate(real_rgb, real_alpha);
}

set_blend_equation_separate_scope :: (rgb: BlendEquation, alpha: BlendEquation) #expand {
    old_rgb, old_alpha := get_blend_equation_separate();
    `defer set_blend_equation_separate(old_rgb, old_alpha);

    set_blend_equation_separate(rgb, alpha);
}

BlendFunc :: enum {
    Zero;
    One;
    SrcColor;
    OneMinusSrcColor;
    DstColor;
    OneMinusDstColor;
    SrcAlpha;
    OneMinusSrcAlpha;
    DstAlpha;
    OneMinusDstAlpha;
}

convert_blend_func :: (value: BlendFunc) -> u32 {
    if #complete value == {
        case .Zero;
            return GL_ZERO;
        case .One;
            return GL_ONE;
        case .SrcColor;
            return GL_SRC_COLOR;
        case .OneMinusSrcColor;
            return GL_ONE_MINUS_SRC_COLOR;
        case .DstColor;
            return GL_DST_COLOR;
        case .OneMinusDstColor;
            return GL_ONE_MINUS_DST_COLOR;
        case .SrcAlpha;
            return GL_SRC_ALPHA;
        case .OneMinusSrcAlpha;
            return GL_ONE_MINUS_SRC_ALPHA;
        case .DstAlpha;
            return GL_DST_ALPHA;
        case .OneMinusDstAlpha;
            return GL_ONE_MINUS_DST_ALPHA;
    }
}

convert_blend_func :: (value: u32) -> BlendFunc {
    if value == GL_ZERO {
        return .Zero;
    } else if value == GL_ONE {
        return .One;
    } else if value == GL_SRC_COLOR {
        return .SrcColor;
    } else if value == GL_ONE_MINUS_SRC_COLOR {
        return .OneMinusSrcColor;
    } else if value == GL_DST_COLOR {
        return .DstColor;
    } else if value == GL_ONE_MINUS_DST_COLOR {
        return .OneMinusDstColor;
    } else if value == GL_SRC_ALPHA {
        return .SrcAlpha;
    } else if value == GL_ONE_MINUS_SRC_ALPHA {
        return .OneMinusSrcAlpha;
    } else if value == GL_DST_ALPHA {
        return .DstAlpha;
    } else if value == GL_ONE_MINUS_DST_ALPHA {
        return .OneMinusDstAlpha;
    }

    return .One;
}

get_blend_func :: () -> BlendFunc, BlendFunc {
    real_src: s32;
    glGetIntegerv(GL_BLEND_SRC_RGB, *real_src);
    src := convert_blend_func(cast(u32) real_src);

    real_dst: s32;
    glGetIntegerv(GL_BLEND_SRC_ALPHA, *real_dst);
    dst := convert_blend_func(cast(u32) real_dst);

    return src, dst;
}

set_blend_func :: (src: BlendFunc, dst: BlendFunc) {
    real_src := convert_blend_func(src);
    real_dst := convert_blend_func(dst);

    glBlendFunc(real_src, real_dst);
}

set_blend_func_scope :: (src: BlendFunc, dst: BlendFunc) #expand {
    old_src_color, old_dst_color, old_src_alpha, old_dst_alpha := get_blend_func_separate();
    `defer set_blend_func_separate(old_src_color, old_dst_color, old_src_alpha, old_dst_alpha);

    set_blend_func(src, dst);
}

get_blend_func_separate :: () -> BlendFunc, BlendFunc, BlendFunc, BlendFunc {
    real_src_color: s32;
    glGetIntegerv(GL_BLEND_SRC_RGB, *real_src_color);
    src_color := convert_blend_func(cast(u32) real_src_color);

    real_dst_color: s32;
    glGetIntegerv(GL_BLEND_DST_RGB, *real_dst_color);
    dst_color := convert_blend_func(cast(u32) real_dst_color);

    real_src_alpha: s32;
    glGetIntegerv(GL_BLEND_SRC_ALPHA, *real_src_alpha);
    src_alpha := convert_blend_func(cast(u32) real_src_alpha);

    real_dst_alpha: s32;
    glGetIntegerv(GL_BLEND_DST_ALPHA, *real_dst_alpha);
    dst_alpha := convert_blend_func(cast(u32) real_dst_alpha);

    return src_color, dst_color, src_alpha, dst_alpha;
}

set_blend_func_separate :: (src_color: BlendFunc, dst_color: BlendFunc, src_alpha: BlendFunc, dst_alpha: BlendFunc) {
    real_src_color := convert_blend_func(src_color);
    real_dst_color := convert_blend_func(dst_color);
    real_src_alpha := convert_blend_func(src_alpha);
    real_dst_alpha := convert_blend_func(dst_alpha);

    glBlendFuncSeparate(real_src_color, real_dst_color, real_src_alpha, real_dst_alpha);
}

set_blend_func_separate_scope :: (src_color: BlendFunc, dst_color: BlendFunc, src_alpha: BlendFunc, dst_alpha: BlendFunc) #expand {
    old_src_color, old_dst_color, old_src_alpha, old_dst_alpha := get_blend_func_separate();
    `defer set_blend_func_separate(old_src_color, old_dst_color, old_src_alpha, old_dst_alpha);

    set_blend_func_separate(src_color, dst_color, src_alpha, dst_alpha);
}

get_cull_face :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_CULL_FACE, *enabled);
    return enabled;
}

set_cull_face :: (enabled: bool) {
    koda.cull_face = enabled;
    if enabled {
        glEnable(GL_CULL_FACE);
    } else {
        glDisable(GL_CULL_FACE);
    }
}

set_cull_face_scope :: (enabled: bool) #expand {
    old_enabled := get_cull_face();
    `defer set_cull_face(old_enabled);

    set_cull_face(enabled);
}

CullFaceMode :: enum u32 {
    Front;
    Back;
    FrontAndBack;
}

convert_cull_face_mode :: (value: CullFaceMode) -> u32 {
    if #complete value == {
        case .Front;
            return GL_FRONT;
        case .Back;
            return GL_BACK;
        case .FrontAndBack;
            return GL_FRONT_AND_BACK;
    }
}

convert_cull_face_mode :: (value: u32) -> CullFaceMode {
    if value == GL_FRONT {
        return .Front;
    } else if value == GL_BACK {
        return .Back;
    } else if value == GL_FRONT_AND_BACK {
        return .FrontAndBack;
    }

    return .Back;
}

get_cull_face_mode :: () -> CullFaceMode {
    cull_face_mode: s32;
    glGetIntegerv(GL_CULL_FACE_MODE, *cull_face_mode);
    return convert_cull_face_mode(cast(u32) cull_face_mode);
}

set_cull_face_mode :: (value: CullFaceMode) {
    koda.cull_face_mode = value;
    cull_face_mode := convert_cull_face_mode(value);
    glCullFace(cull_face_mode);
}

set_cull_face_mode_scope :: (value: CullFaceMode) #expand {
    old_value := get_cull_face_mode();
    `defer set_cull_face_mode(old_value);

    set_cull_face_mode(value);
}

get_scissor_test :: () -> bool, Point2, Point2 {
    enabled := glIsEnabled(GL_SCISSOR_TEST);
    box: [4] s32;
    glGetIntegerv(GL_SCISSOR_BOX, box.data);

    return enabled, .{box[0], koda.height - box[1] - box[3]}, .{box[2], box[3]};
}

set_scissor_test :: (enabled: bool) {
    if enabled {
        glEnable(GL_SCISSOR_TEST);
    } else {
        glDisable(GL_SCISSOR_TEST);
    }
}

set_scissor_test :: (enabled: bool, top_left: Point2, dimensions: Point2) {
    if enabled {
        glEnable(GL_SCISSOR_TEST);
    } else {
        glDisable(GL_SCISSOR_TEST);
    }

    glScissor(cast(s32) top_left.x, cast(s32) (koda.height - top_left.y - dimensions.y), cast(u32) dimensions.x, cast(u32) dimensions.y);
}

set_scissor_test_scope :: (enabled: bool) #expand {
    old_enabled := get_scissor_test();
    `defer set_scissor_test(old_enabled);

    set_scissor_test(enabled);
}

set_scissor_test_scope :: (enabled: bool, top_left: Point2, dimensions: Point2) #expand {
    old_enabled, old_top_left, old_dimensions := get_scissor_test();
    `defer set_scissor_test(old_enabled, old_top_left, old_dimensions);

    set_scissor_test(enabled, top_left, dimensions);
}

get_monitor_size :: () -> Point2 {
    return .{monitor_width, monitor_height};
}

get_view :: () -> Matrix4 {
    return koda.view;
}

set_view :: (view: Matrix4) {
    koda.view = view;
}

set_view_scope :: (view: Matrix4) #expand {
    old_view := get_view();
    `defer set_view(old_view);
    set_view(view);
}

ClearMask :: enum_flags {
    None :: 0;
    Color :: 1;
    Depth;
    Stencil;
    All :: Color | Depth | Stencil;
}

convert_clear_mask :: (mask: ClearMask) -> u32 {
    real_mask: u32;
    if mask & .Color {
        real_mask |= GL_COLOR_BUFFER_BIT;
    }
    if mask & .Depth {
        real_mask |= GL_DEPTH_BUFFER_BIT;
    }
    if mask & .Stencil {
        real_mask |= GL_STENCIL_BUFFER_BIT;
    }

    return real_mask;
}

convert_clear_mask :: (real_mask: u32) -> ClearMask {
    mask: ClearMask;
    if real_mask & GL_COLOR_BUFFER_BIT {
        mask |= .Color;
    }
    if real_mask & GL_DEPTH_BUFFER_BIT {
        mask |= .Depth;
    }
    if real_mask & GL_STENCIL_BUFFER_BIT {
        mask |= .Stencil;
    }

    return mask;
}

clear :: (mask: ClearMask = .All) {
    clear(.{0, 0, 0, 0}, mask);
}

clear :: (color: Color, mask: ClearMask = .All) {
    clear(color, 1.0, mask);
}

clear :: (color: Color, depth: float, mask: ClearMask = .All) {
    assert(koda.can_render, "Cannot currently make any draw calls.\n");

    real_mask := convert_clear_mask(mask);
    glClearColor(color.r, color.g, color.b, color.a);
    glClearDepth(depth);
    glStencilMask(0xFF);
    defer glStencilMask(0x00);
    if mask {
        glClear(real_mask);
    }
}

begin_render_target :: (render_texture: *RenderTexture) {
    BUFFERS :: u32.[GL_COLOR_ATTACHMENT0];

    koda.render_flipped = true;
    set_viewport(render_texture.width, render_texture.height);
    set_front_face_ccw(false);

    glBindFramebuffer(GL_FRAMEBUFFER, render_texture.framebuffer);
    glDrawBuffers(1, BUFFERS.data);

    status := glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if status != GL_FRAMEBUFFER_COMPLETE {
        print("Framebuffer error. %", status);
    }
}

end_render_target :: () {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

    set_front_face_ccw(true);
    set_viewport(koda.width, koda.height);
    koda.render_flipped = false;
}

#scope_module

monitor_width: int;
monitor_height: int;

mouse_capture: bool;

mouse_boundary_enabled: bool;

accurate_sleep: bool;

vsync_enabled: bool;

locked_frames: bool;
locked_frames_start: float64;
locked_frames_count: int;

#scope_file

adaptive_vsync_enabled: bool;

window_focused: bool;

error_callback :: (error: s32, description: *u8) #c_call {
    // TODO print color
    new_context: #Context;
    push_context new_context {
        print("GLFW error: % %\n", error, to_string(description));
    }
}

size_callback :: (window: *GLFWwindow, width: s32, height: s32) #c_call {
    new_context: #Context;
    push_context new_context {
        set_viewport(width, height);
    }
}

focus_callback :: (window: *GLFWwindow, focused: s32) #c_call {
    new_context: #Context;
    push_context new_context {
        window_focused = !!focused;
    }
}

time_slice_ms :: 2;

MINIMUM_GL_MAJOR_VERSION: s32 : 4;
MINIMUM_GL_MINOR_VERSION: s32 : 4;
