koda_init :: () {
    glfwSetErrorCallback(error_callback);
    if !glfwInit() {
        print("Exited because glfw could not initialize.\n");
        exit(-1);
    }

    // initialize time
    init_time();

    koda.initialized = true;
}

get_window :: () -> *GLFWwindow {
    return koda.window;
}

monitor_height: s32;
create_window :: (title: *u8, width: s32, height: s32) {
    if !koda.initialized {
        print("Cannot create window before initializing.\n");
        return;
    }

    monitor_width := width;
    monitor_height = height;
    monitor := glfwGetPrimaryMonitor();
    if monitor {
        video_mode := glfwGetVideoMode(monitor);
        if video_mode {
            monitor_width = video_mode.width;
            monitor_height = video_mode.height;
        }
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

    set_vsync(false);
    set_target_fps(0);

    koda.width = width;
    koda.height = height;
    koda.last_width = width;
    koda.last_height = height;
    set_viewport(width, height);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glFrontFace(GL_CCW);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

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

set_viewport :: (width: int, height: int) {
    koda.viewport_width = width;
    koda.viewport_height = height;
    
    glViewport(0, 0, xx width, xx height);
}

should_exit :: () -> bool {
    // end and begin
    glfwSwapBuffers(koda.window);
    glfwGetFramebufferSize(koda.window, *koda.width, *koda.height);
    if koda.last_width != koda.width || koda.last_height != koda.height {
        set_viewport(koda.width, koda.height);
    }

    exit := glfwWindowShouldClose(koda.window) == GLFW_TRUE;

    time := get_time();
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

get_fullscreen :: () -> bool {
    return glfwGetWindowAttrib(koda.window, GLFW_MAXIMIZED) == GLFW_TRUE;
}

set_fullscreen :: (fullscreen: bool) {
    if fullscreen {
        glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_FALSE);
        glfwMaximizeWindow(koda.window);
    } else {
        glfwSetWindowAttrib(koda.window, GLFW_DECORATED, GLFW_TRUE);
        glfwRestoreWindow(koda.window);
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

get_cull_face :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_CULL_FACE, *enabled);
    return enabled;
}

set_cull_face :: (enabled: bool) {
    if enabled {
        glEnable(GL_CULL_FACE);
    } else {
        glDisable(GL_CULL_FACE);
    }
}

clear :: (color: Color) {
    glClearColor(color.r, color.g, color.b, color.a);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
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

MINIMUM_GL_MAJOR_VERSION: s32 : 4;
MINIMUM_GL_MINOR_VERSION: s32 : 4;

#import "JaiGLFW";
#import "Math";
#import "Basic";