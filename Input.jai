ClientInput :: struct {
    should_quit: bool;

    keys: [INPUT_COUNT] InputState;
    released_keys: [INPUT_COUNT] bool;

    mouse_left: InputState;
    released_mouse_left: bool;
    mouse_right: InputState;
    released_mouse_right: bool;
    mouse_delta_x: float64;
    mouse_delta_y: float64;

    scroll_delta_x: float64;
    scroll_delta_y: float64;
}

InputState :: enum_flags u8 {
    NONE :: 0x0;
    DOWN :: 0x1;
    START :: 0x2;
}

// TODO we need to rename these to specific actions once we figure out what actions our game has
Input :: enum {
    W;
    A;
    S;
    D;
    R;
    SPACE;
    SHIFT;
    CONTROL;
    ESCAPE;
    NUM1;
    NUM2;
    F5;
    F1;
    DELETE;
}

INPUT_COUNT :: #run enum_count(Input);

key_map: [INPUT_COUNT] s32 = .[
    GLFW_KEY_W,
    GLFW_KEY_A,
    GLFW_KEY_S,
    GLFW_KEY_D,
    GLFW_KEY_R,
    GLFW_KEY_SPACE,
    GLFW_KEY_LEFT_SHIFT,
    GLFW_KEY_LEFT_CONTROL,
    GLFW_KEY_ESCAPE,
    GLFW_KEY_1,
    GLFW_KEY_2,
    GLFW_KEY_F5,
    GLFW_KEY_F1,
    GLFW_KEY_DELETE,
];

input: ClientInput;

raw_mouse_x: float64 = 0.0 / 2;
raw_mouse_y: float64 = 0.0 / 2;

mouse_sensitivity: float64 = 0.25;

mouse_captured := true;

accumulated_scroll: [2] float64;

scroll_callback :: (window: *GLFWwindow, x_offset: float64, y_offset: float64) #c_call {
    accumulated_scroll[0] += x_offset;
    accumulated_scroll[1] += y_offset;
}

update_inputs :: () {
    // TODO should this be called here?
    // glfwPollEvents();

    last_raw_mouse_x := raw_mouse_x;
    last_raw_mouse_y := raw_mouse_y;
    glfwGetCursorPos(koda.window, *raw_mouse_x, *raw_mouse_y);
    input.mouse_delta_x = (raw_mouse_x - last_raw_mouse_x) * mouse_sensitivity;
    input.mouse_delta_y = (raw_mouse_y - last_raw_mouse_y) * mouse_sensitivity;
    if !mouse_captured {
        input.mouse_delta_x = 0;
        input.mouse_delta_y = 0;
    }

    input.scroll_delta_x = accumulated_scroll[0];
    input.scroll_delta_y = accumulated_scroll[1];
    accumulated_scroll[0] = 0;
    accumulated_scroll[1] = 0;
    if !mouse_captured {
        input.scroll_delta_x = 0;
        input.scroll_delta_y = 0;
    }

    // TODO probably need a more generic way to clear all inputs when not captured
    input.mouse_left &= ~InputState.START;
    mouse_left := glfwGetMouseButton(koda.window, GLFW_MOUSE_BUTTON_LEFT);
    input.released_mouse_left = input.mouse_left && !mouse_left;
    if mouse_left && !input.mouse_left {
        input.mouse_left |= InputState.START;
    }
    if mouse_left {
        input.mouse_left |= InputState.DOWN;
    } else {
        input.mouse_left &= ~InputState.DOWN;
    }

    input.mouse_right &= ~InputState.START;
    mouse_right := glfwGetMouseButton(koda.window, GLFW_MOUSE_BUTTON_RIGHT);
    input.released_mouse_right = input.mouse_right && !mouse_right;
    if mouse_right && !input.mouse_right {
        input.mouse_right |= InputState.START;
    }
    if mouse_right {
        input.mouse_right |= InputState.DOWN;
    } else {
        input.mouse_right &= ~InputState.DOWN;
    }

    for key_code, index: key_map {
        key_value := glfwGetKey(koda.window, key_code);
        key_down: bool = cast(bool) (key_value & GLFW_PRESS);
        input.released_keys[index] = input.keys[index] && !key_down;

        // clear the start value
        input.keys[index] &= ~InputState.START;

        // set the start value if this is a new input
        if key_down & !input.keys[index] {
            input.keys[index] |= InputState.START;
        }
        
        if key_down {
            input.keys[index] |= InputState.DOWN;
        } else {
            input.keys[index] &= ~InputState.DOWN;
        }
    }

    if mouse_captured {
        if glfwGetKey(koda.window, GLFW_KEY_ESCAPE) {
            mouse_captured = false;
            glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
        }
    } else {
        if input.mouse_left {
            mouse_captured = true;
            glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        }
    }

    if glfwGetKey(koda.window, GLFW_KEY_C) {
        if input.keys[Input.CONTROL] {
            glfwSetWindowShouldClose(koda.window, GLFW_TRUE);
        }
    }
}
