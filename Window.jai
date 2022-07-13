init :: () {
    glfwSetErrorCallback(error_callback);
    if !glfwInit() {
        print("Exited because glfw could not initialize.\n");
        exit(-1);
    }

    // initialize time safely?
    get_time();

    koda.initialized = true;
}

get_window :: () -> *GLFWwindow {
    return koda.window;
}

create_window :: (title: *u8, width: s32, height: s32) {
    if !koda.initialized {
        print("Cannot create window before initializing.\n");
        return;
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

    set_vsync(false);
    set_target_fps(0);

    koda.width = width;
    koda.height = height;
    koda.last_width_ = width;
    koda.last_height_ = height;
    glViewport(0, 0, xx width, xx height);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glFrontFace(GL_CCW);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

    // TODO
    // glEnable(GL_SCISSOR_TEST);

    // koda.shader = get_shader_program(DEFAULT_VERTEX_SHADER, DEFAULT_FRAGMENT_SHADER);
    // default_ellipse_shader = get_shader_program(DEFAULT_ELLIPSE_VERTEX_SHADER, DEFAULT_ELLIPSE_FRAGMENT_SHADER);

    koda.static_sprite_ = create_sprite(.{}, 0, 0);
}

destroy_window :: () {
    glfwDestroyWindow(koda.window);
    glfwTerminate();
}

should_exit :: () -> bool {
    // end and begin
    glfwSwapBuffers(koda.window);
    glfwGetFramebufferSize(koda.window, *koda.width, *koda.height);
    if koda.last_width_ != koda.width || koda.last_height_ != koda.height {
        glViewport(0, 0, xx koda.width, xx koda.height);
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

get_mouse_captured :: () -> bool {
    return glfwGetInputMode(koda.window, GLFW_CURSOR) == GLFW_CURSOR_DISABLED;
}

set_mouse_captured :: (enabled: bool) {
    if enabled {
        glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        glfwSetInputMode(koda.window, GLFW_STICKY_MOUSE_BUTTONS, GLFW_TRUE);
        glfwSetInputMode(koda.window, GLFW_STICKY_KEYS, GLFW_TRUE);
    } else {
        glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
        glfwSetInputMode(koda.window, GLFW_STICKY_MOUSE_BUTTONS, GLFW_FALSE);
        glfwSetInputMode(koda.window, GLFW_STICKY_KEYS, GLFW_FALSE);
    }
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

begin_render_target :: (render_texture: RenderTexture) {

}

end_render_target :: () {

}

#scope_file

error_callback :: (error: s32, description: *u8) #c_call {
    new_context: Context;
    push_context new_context {
        print("GLFW error: % %\n", error, to_string(description));
    }
}

// 4.4?
MINIMUM_GL_MAJOR_VERSION: s32 : 3;
MINIMUM_GL_MINOR_VERSION: s32 : 3;

#import "GL";
#import "JaiGLFW";
#import "Math";
#import "Basic";