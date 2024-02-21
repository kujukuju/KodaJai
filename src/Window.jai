koda_init :: () {
    glfwSetErrorCallback(error_callback);
    if !glfwInit() {
        print("Exited because glfw could not initialize.\n");
        exit(-1);
    }

    init_default_shaders();
    init_quick_sort(core_count);
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
            if video_mode.height <= 1080 || video_mode.width <= 1920 {
                width = 1600;
                height = 900;
            }
        }
    }

    monitor_width := width;
    monitor_height := height;
    monitor := glfwGetPrimaryMonitor();
    if monitor {
        video_mode := glfwGetVideoMode(monitor);
        if video_mode {
            monitor_width = video_mode.width;
            monitor_height = video_mode.height;
        }
    }
    koda.windowed_width = width;
    koda.windowed_height = height;

    if multisample {
        glfwWindowHint(GLFW_SAMPLES, xx multisample);
    }

    #if OS == .MACOS {
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, MINIMUM_GL_MAJOR_VERSION);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, MINIMUM_GL_MINOR_VERSION);
    koda.window = glfwCreateWindow(width, height, title, null, null);
    if !koda.window {
        glfwTerminate();
        print("Cannot create window.\n");
        return;
    }

    glfwSetWindowPos(koda.window, (monitor_width - width) / 2, (monitor_height - height) / 2);

    glfwMakeContextCurrent(koda.window);
    gl_load(*gl, glfwGetProcAddress);

    // glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    glfwSetInputMode(koda.window, GLFW_STICKY_MOUSE_BUTTONS, GLFW_TRUE);
    glfwSetInputMode(koda.window, GLFW_STICKY_KEYS, GLFW_TRUE);
    // glfwSetCursorPos(koda.window, width / 2.0, height / 2.0);
    glfwSetScrollCallback(koda.window, scroll_callback);
    // glfwSetCursorPosCallback(koda.window, mouse_callback);
    glfwSetWindowSizeCallback(koda.window, size_callback);

    set_vsync(false);
    set_target_fps(0);

    if multisample {
        glEnable(GL_MULTISAMPLE);
    }

    koda.width = width;
    koda.height = height;
    koda.last_width = width;
    koda.last_height = height;
    set_viewport(width, height);

    set_blend(true);
    set_blend_func(.SrcAlpha, .OneMinusSrcAlpha);

    glFrontFace(GL_CCW);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

    glClearColor(0.0, 0.0, 0.0, 1.0);

    // TODO
    // glEnable(GL_SCISSOR_TEST);

    // koda.shader = get_shader_program(DEFAULT_VERTEX_SHADER, DEFAULT_FRAGMENT_SHADER);
    // default_ellipse_shader = get_shader_program(DEFAULT_ELLIPSE_VERTEX_SHADER, DEFAULT_ELLIPSE_FRAGMENT_SHADER);

    static_sprite = create_sprite(.{}, 0, 0);
}

destroy_window :: () {
    glfwDestroyWindow(koda.window);
    glfwTerminate();
}

set_icon :: (image: Image) {
    assert(image.format == .RGBA, "Your window icon must be of format RGBA.");
    glfw_image: GLFWimage;
    glfw_image.width = cast(s32) image.width;
    glfw_image.height = cast(s32) image.height;
    glfw_image.pixels = image.pixels.data;

    glfwSetWindowIcon(koda.window, 1, *glfw_image);
}

set_viewport :: (width: int, height: int) {
    koda.viewport_width = width;
    koda.viewport_height = height;
    
    glViewport(0, 0, xx width, xx height);
}

should_exit :: () -> bool {
    #if !PRODUCTION {
        err := glGetError();
        while err != GL_NO_ERROR {
            print("GL error: %\n", err);
            err = glGetError();
        }
    }

    // end and begin
    glfwSwapBuffers(koda.window);
    glfwGetFramebufferSize(koda.window, *koda.width, *koda.height);
    if koda.last_width != koda.width || koda.last_height != koda.height {
        set_viewport(koda.width, koda.height);
    }

    exit := glfwWindowShouldClose(koda.window) == GLFW_TRUE;

    time := seconds_since_init();
    tick_frame_tracker(*koda.frame_tracker, time);

    // TODO sleep_milliseconds is garbage on windows, use something else like locks and threads

    // sleep if desired
    if !koda.time_tracker.vsync && koda.time_tracker.target_fps > 0 {
        desired_tick_duration := cast(float64) 1000.0 / cast(float64) koda.time_tracker.target_fps;

        last_loop_time := koda.time_tracker.last_loop_time;
        if last_loop_time > 0 {
            last_tick_duration := (time - last_loop_time) * 1000.0;
            desired_sleep_time := max(desired_tick_duration - last_tick_duration, 0.0);

            if desired_sleep_time > 0 {
                sleep_milliseconds(cast(s32) desired_sleep_time);
            }
        }
    }
    koda.time_tracker.last_loop_time = time;
    
    // TODO is this the right place for this?
    if !exit {
        glfwPollEvents();
    }

    return exit;
}

force_draw :: should_exit;

get_fullscreen :: () -> bool {
    return glfwGetWindowAttrib(koda.window, GLFW_DECORATED) == GLFW_FALSE || !!glfwGetWindowMonitor(koda.window);
}

set_fullscreen :: (fullscreen: bool, borderless: bool) {
    if fullscreen {
        if borderless {
            monitor := glfwGetPrimaryMonitor();
            video_mode := glfwGetVideoMode(monitor);
            if video_mode {
                glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_FALSE);
                glfwSetWindowMonitor(koda.window, null, 0, 0, video_mode.width, video_mode.height, 0);
            }
        } else {
            monitor := glfwGetPrimaryMonitor();
            video_mode := glfwGetVideoMode(monitor);
            if video_mode {
                glfwSetWindowMonitor(koda.window, monitor, 0, 0, video_mode.width, video_mode.height, video_mode.refreshRate);
            }
        }
    } else {
        monitor := glfwGetPrimaryMonitor();
        video_mode := glfwGetVideoMode(monitor);
        if video_mode {
            glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_TRUE);
            glfwSetWindowMonitor(koda.window, null, cast(s32) (video_mode.width - koda.windowed_width) / 2, cast(s32) (video_mode.height - koda.windowed_height) / 2, cast(s32) koda.windowed_width, cast(s32) koda.windowed_height, 0);
        }
    }
}

get_vsync :: () -> bool {
    return koda.time_tracker.vsync;
}

set_vsync :: (vsync: bool) {
    koda.time_tracker.vsync = vsync;
    glfwSwapInterval(xx (ifx vsync then 1 else 0));
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
    if mouse_capture != capture {
        if capture {
            mouse_currently_captured = true;
        }
        
        mouse_capture = capture;
        resolve_mouse_capture();
    }
}

get_mouse_currently_captured :: () -> bool {
    return glfwGetInputMode(koda.window, GLFW_CURSOR) == GLFW_CURSOR_DISABLED;
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

get_depth_write :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_DEPTH_WRITEMASK, *enabled);
    return enabled;
}

set_depth_write :: (enabled: bool) {
    glDepthMask(enabled);
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

get_blend_equation_seperate :: () -> BlendEquation, BlendEquation {
    real_rgb: s32;
    glGetIntegerv(GL_BLEND_EQUATION_RGB, *real_rgb);
    rgb := convert_blend_equation(cast(u32) real_rgb);

    real_alpha: s32;
    glGetIntegerv(GL_BLEND_EQUATION_ALPHA, *real_alpha);
    alpha := convert_blend_equation(cast(u32) real_alpha);

    return rgb, alpha;
}

set_blend_equation_seperate :: (rgb: BlendEquation, alpha: BlendEquation) {
    real_rgb := convert_blend_equation(rgb);
    real_alpha := convert_blend_equation(alpha);

    glBlendEquationSeparate(real_rgb, real_alpha);
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

ClearMask :: enum_flags {
    Color;
    Depth;
    Stencil;
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

clear :: (color: Color, $mask: ClearMask = .Color | .Depth) {
    real_mask := #run convert_clear_mask(mask);
    glClearColor(color.r, color.g, color.b, color.a);
    glClear(real_mask);
}

clear :: ($mask: ClearMask = .Color | .Depth) {
    real_mask := #run convert_clear_mask(mask);
    glClear(real_mask);
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

mouse_capture: bool;
mouse_currently_captured: bool;

#scope_file

error_callback :: (error: s32, description: *u8) #c_call {
    // TODO print color
    new_context: Context;
    push_context new_context {
        print("GLFW error: % %\n", error, to_string(description));
    }
}

size_callback :: (window: *GLFWwindow, width: s32, height: s32) #c_call {
    new_context: Context;
    push_context new_context {
        set_viewport(width, height);
    }
}

MINIMUM_GL_MAJOR_VERSION: s32 : 4;
MINIMUM_GL_MINOR_VERSION: s32 : 4;

#import "JaiGLFW";
#import "Math";
#import "Basic";