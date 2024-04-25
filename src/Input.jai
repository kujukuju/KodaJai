Key :: enum {
    SPACE;
    APOSTROPHE;
    COMMA;
    MINUS;
    PERIOD;
    SLASH;
    NUMBER_0;
    NUMBER_1;
    NUMBER_2;
    NUMBER_3;
    NUMBER_4;
    NUMBER_5;
    NUMBER_6;
    NUMBER_7;
    NUMBER_8;
    NUMBER_9;
    SEMICOLON;
    EQUAL;
    A;
    B;
    C;
    D;
    E;
    F;
    G;
    H;
    I;
    J;
    K;
    L;
    M;
    N;
    O;
    P;
    Q;
    R;
    S;
    T;
    U;
    V;
    W;
    X;
    Y;
    Z;
    LEFT_BRACKET;
    BACKSLASH;
    RIGHT_BRACKET;
    GRAVE_ACCENT;
    WORLD_1;
    WORLD_2;
    ESCAPE;
    ENTER;
    TAB;
    BACKSPACE;
    INSERT;
    DELETE;
    RIGHT;
    LEFT;
    DOWN;
    UP;
    PAGE_UP;
    PAGE_DOWN;
    HOME;
    END;
    CAPS_LOCK;
    SCROLL_LOCK;
    NUM_LOCK;
    PRINT_SCREEN;
    PAUSE;
    F1;
    F2;
    F3;
    F4;
    F5;
    F6;
    F7;
    F8;
    F9;
    F10;
    F11;
    F12;
    F13;
    F14;
    F15;
    F16;
    F17;
    F18;
    F19;
    F20;
    F21;
    F22;
    F23;
    F24;
    F25;
    NUMPAD_0;
    NUMPAD_1;
    NUMPAD_2;
    NUMPAD_3;
    NUMPAD_4;
    NUMPAD_5;
    NUMPAD_6;
    NUMPAD_7;
    NUMPAD_8;
    NUMPAD_9;
    NUMPAD_DECIMAL;
    NUMPAD_DIVIDE;
    NUMPAD_MULTIPLY;
    NUMPAD_SUBTRACT;
    NUMPAD_ADD;
    NUMPAD_ENTER;
    NUMPAD_EQUAL;
    LEFT_SHIFT;
    LEFT_CONTROL;
    LEFT_ALT;
    LEFT_SUPER;
    RIGHT_SHIFT;
    RIGHT_CONTROL;
    RIGHT_ALT;
    RIGHT_SUPER;
    MENU;
}

KEY_COUNT :: #run enum_count(Key);

Button :: enum {
    A;
    B;
    X;
    Y;
    LEFT_BUMPER;
    RIGHT_BUMPER;
    BACK;
    START;
    GUIDE;
    LEFT_JOYSTICK;
    RIGHT_JOYSTICK;
    DPAD_UP;
    DPAD_RIGHT;
    DPAD_DOWN;
    DPAD_LEFT;
}

BUTTON_COUNT :: #run enum_count(Button);

// ClientInput :: struct {
//     should_quit: bool;

//     keys: [INPUT_COUNT] InputState;
//     released_keys: [INPUT_COUNT] bool;

//     mouse_left: InputState;
//     released_mouse_left: bool;
//     mouse_right: InputState;
//     released_mouse_right: bool;
//     mouse_delta_x: float64;
//     mouse_delta_y: float64;

//     scroll_delta_x: float64;
//     scroll_delta_y: float64;

//     controller_active: bool;
//     controller_left: Vector2;
//     controller_right: Vector2;
//     joystick_projected: bool = true;
//     controller_buttons: [CONTROLLER_BUTTON_COUNT] InputState;
//     released_controller_buttons: [CONTROLLER_BUTTON_COUNT] bool;
// }

InputState :: enum_flags u8 {
    NONE :: 0x0;
    DOWN :: 0x1;
    START :: 0x2;
}

InputFeature :: enum u32 {
    None :: 0x0;
    Keys :: 0x1;
    ControllerButtons :: 0x2;
    ControllerMove :: 0x4;
    MouseButtons :: 0x8;
    MouseScroll :: 0x10;
    MouseMove :: 0x20;
    All :: 0xffffffff;
}

input: struct {
    keys: [KEY_COUNT] InputState;
    released_keys: [KEY_COUNT] bool;
    controller_active: bool;
    controller_left: Vector2;
    controller_right: Vector2;
    buttons: [BUTTON_COUNT] InputState;
    released_buttons: [BUTTON_COUNT] bool;
    mouse_left: InputState;
    released_mouse_left: bool;
    mouse_left_start: Vector2;
    mouse_left_drag: Vector2;
    mouse_right: InputState;
    released_mouse_right: bool;
    mouse_right_start: Vector2;
    mouse_right_drag: Vector2;
    mouse_middle: InputState;
    released_mouse_middle: bool;
    mouse_middle_start: Vector2;
    mouse_middle_drag: Vector2;
    mouse: Vector2;
    mouse_delta_x: float64;
    mouse_delta_y: float64;
    scroll_delta_x: float64;
    scroll_delta_y: float64;
};

update_inputs :: ($update_features: InputFeature = .All) {
    // TODO should this be called here?

    // TODO all this update feature shit is gonna have to be redone and reorganized at some poitn

    for joystick: GLFW_JOYSTICK_1..GLFW_JOYSTICK_LAST {
        if !glfwJoystickPresent(xx joystick) {
            continue;
        }

        if !glfwJoystickIsGamepad(xx joystick) {
            continue;
        }

        state: GLFWgamepadstate;
        if !glfwGetGamepadState(xx joystick, *state) {
            continue;
        }

        #if update_features & .ControllerButtons {
            for index: 0..BUTTON_COUNT - 1 {
                button_down := cast(bool) (state.buttons[index] & GLFW_PRESS);
                input.released_buttons[index] = input.buttons[index] && !button_down;

                // clear the start value
                input.buttons[index] &= ~InputState.START;

                // set the start value if this is a new input
                if button_down & !input.buttons[index] {
                    input.buttons[index] |= InputState.START;
                }
                
                if button_down {
                    input.buttons[index] |= InputState.DOWN;
                    input.controller_active = true;
                } else {
                    input.buttons[index] &= ~InputState.DOWN;
                }
            }
        }

        #if update_features & .ControllerMove {
            input.controller_left.x = state.axes[GLFW_GAMEPAD_AXIS_LEFT_X];
            input.controller_left.y = state.axes[GLFW_GAMEPAD_AXIS_LEFT_Y];
            input.controller_right.x = state.axes[GLFW_GAMEPAD_AXIS_RIGHT_X];
            input.controller_right.y = state.axes[GLFW_GAMEPAD_AXIS_RIGHT_Y];

            length_left := length(input.controller_left) * (1.0 + joystick_padding * 2) - joystick_padding;
            length_left = min(max(length_left, 0.0), 1.0);
            input.controller_left = normalize(input.controller_left) * length_left;

            length_right := length(input.controller_right) * (1.0 + joystick_padding * 2) - joystick_padding;
            length_right = min(max(length_right, 0.0), 1.0);
            input.controller_right = normalize(input.controller_right) * length_right;

            if joystick_projected {
                if length_left > 0 {
                    angle := atan2(input.controller_left.y, input.controller_left.x);
                    denom := max(abs(cos(angle)), abs(sin(angle)));
                    input.controller_left /= denom;
                }
                if length_right > 0 {
                    angle := atan2(input.controller_right.y, input.controller_right.x);
                    denom := max(abs(cos(angle)), abs(sin(angle)));
                    input.controller_right /= denom;
                }
            }
        }
    }

    #if update_features & .MouseMove {
        last_raw_mouse_x := raw_mouse_x;
        last_raw_mouse_y := raw_mouse_y;
        glfwGetCursorPos(koda.window, *raw_mouse_x, *raw_mouse_y);
        input.mouse_delta_x = raw_mouse_x - last_raw_mouse_x;
        input.mouse_delta_y = raw_mouse_y - last_raw_mouse_y;
        input.mouse = xy(xx raw_mouse_x, xx raw_mouse_y);
    }

    #if update_features & .MouseScroll {
        input.scroll_delta_x = accumulated_scroll[0];
        input.scroll_delta_y = accumulated_scroll[1];
        accumulated_scroll[0] = 0;
        accumulated_scroll[1] = 0;
    }

    // TODO probably need a more generic way to clear all inputs when not captured
    #if update_features & .MouseButtons {
        input.mouse_left &= ~InputState.START;
        mouse_left := glfwGetMouseButton(koda.window, GLFW_MOUSE_BUTTON_LEFT);
        input.released_mouse_left = input.mouse_left && !mouse_left;
        if mouse_left && !input.mouse_left {
            input.mouse_left |= InputState.START;
            input.mouse_left_start = input.mouse;
            input.mouse_left_drag = .{};
        }
        if mouse_left {
            input.mouse_left |= InputState.DOWN;
            input.mouse_left_drag += Vector2.{xx input.mouse_delta_x, xx input.mouse_delta_y};
        } else {
            input.mouse_left &= ~InputState.DOWN;
        }

        input.mouse_right &= ~InputState.START;
        mouse_right := glfwGetMouseButton(koda.window, GLFW_MOUSE_BUTTON_RIGHT);
        input.released_mouse_right = input.mouse_right && !mouse_right;
        if mouse_right && !input.mouse_right {
            input.mouse_right |= InputState.START;
            input.mouse_right_start = input.mouse;
            input.mouse_right_drag = .{};
        }
        if mouse_right {
            input.mouse_right |= InputState.DOWN;
            input.mouse_right_drag += Vector2.{xx input.mouse_delta_x, xx input.mouse_delta_y};
        } else {
            input.mouse_right &= ~InputState.DOWN;
        }

        input.mouse_middle &= ~InputState.START;
        mouse_middle := glfwGetMouseButton(koda.window, GLFW_MOUSE_BUTTON_MIDDLE);
        input.released_mouse_middle = input.mouse_middle && !mouse_middle;
        if mouse_middle && !input.mouse_middle {
            input.mouse_middle |= InputState.START;
            input.mouse_middle_start = input.mouse;
            input.mouse_middle_drag = .{};
        }
        if mouse_middle {
            input.mouse_middle |= InputState.DOWN;
            input.mouse_middle_drag += Vector2.{xx input.mouse_delta_x, xx input.mouse_delta_y};
        } else {
            input.mouse_middle &= ~InputState.DOWN;
        }
    }

    #if update_features & .Keys {
        for key_code, index: glfw_key_map {
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
                input.controller_active = false;
            } else {
                input.keys[index] &= ~InputState.DOWN;
            }
        }
    }

    // if mouse_currently_captured && input.keys[Key.ESCAPE] {
    //     mouse_currently_captured = false;
    //     resolve_mouse_capture();
    // } else if !mouse_currently_captured && (input.mouse_left || input.mouse_right) {
    //     mouse_currently_captured = true;
    //     resolve_mouse_capture();
    // }

    if abort_shortcut && input.keys[Key.LEFT_CONTROL] && (input.keys[Key.C] & InputState.START) {
        glfwSetWindowShouldClose(koda.window, GLFW_TRUE);
    }
}

get_joystick_projected :: () -> bool {
    return joystick_projected;
}

set_joystick_projected :: (projected: bool) {
    joystick_projected = enabled;
}

get_joystick_padding :: () -> float {
    return joystick_padding;
}

set_joystick_padding :: (padding: float) {
    joystick_padding = padding;
}

get_abort_shortcut :: () -> bool {
    return abort_shortcut;
}

set_abort_shortcut :: (enabled: bool) {
    abort_shortcut = enabled;
}

#scope_module

resolve_mouse_capture :: () {
    if mouse_capture && mouse_currently_captured {
        glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        // glfwSetInputMode(koda.window, GLFW_STICKY_MOUSE_BUTTONS, GLFW_TRUE);
        // glfwSetInputMode(koda.window, GLFW_STICKY_KEYS, GLFW_TRUE);
        if glfwRawMouseMotionSupported() {
            glfwSetInputMode(koda.window, GLFW_RAW_MOUSE_MOTION, GLFW_TRUE);
        }
    } else {
        glfwSetInputMode(koda.window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
        // glfwSetInputMode(koda.window, GLFW_STICKY_MOUSE_BUTTONS, GLFW_FALSE);
        // glfwSetInputMode(koda.window, GLFW_STICKY_KEYS, GLFW_FALSE);
        if glfwRawMouseMotionSupported() {
            glfwSetInputMode(koda.window, GLFW_RAW_MOUSE_MOTION, GLFW_FALSE);
        }
    }
}

scroll_callback :: (window: *GLFWwindow, x_offset: float64, y_offset: float64) #c_call {
    accumulated_scroll[0] += x_offset;
    accumulated_scroll[1] += y_offset;
}

// I wonder if this would be more accurate?
mouse_callback :: (window: *GLFWwindow, x: float64, y: float64) #c_call {
    accumulated_mouse[0] = x - mouse_position[0];
    accumulated_mouse[1] = y - mouse_position[1];
    mouse_position[0] = x;
    mouse_position[1] = y;
}

#scope_file

raw_mouse_x: float64 = 0.0;
raw_mouse_y: float64 = 0.0;

accumulated_scroll: [2] float64;
mouse_position: [2] float64;
accumulated_mouse: [2] float64;

joystick_padding := 0.2;
joystick_projected := true;

abort_shortcut := false;

glfw_key_map: [KEY_COUNT] s32 = .[
    GLFW_KEY_SPACE,
    GLFW_KEY_APOSTROPHE,
    GLFW_KEY_COMMA,
    GLFW_KEY_MINUS,
    GLFW_KEY_PERIOD,
    GLFW_KEY_SLASH,
    GLFW_KEY_0,
    GLFW_KEY_1,
    GLFW_KEY_2,
    GLFW_KEY_3,
    GLFW_KEY_4,
    GLFW_KEY_5,
    GLFW_KEY_6,
    GLFW_KEY_7,
    GLFW_KEY_8,
    GLFW_KEY_9,
    GLFW_KEY_SEMICOLON,
    GLFW_KEY_EQUAL,
    GLFW_KEY_A,
    GLFW_KEY_B,
    GLFW_KEY_C,
    GLFW_KEY_D,
    GLFW_KEY_E,
    GLFW_KEY_F,
    GLFW_KEY_G,
    GLFW_KEY_H,
    GLFW_KEY_I,
    GLFW_KEY_J,
    GLFW_KEY_K,
    GLFW_KEY_L,
    GLFW_KEY_M,
    GLFW_KEY_N,
    GLFW_KEY_O,
    GLFW_KEY_P,
    GLFW_KEY_Q,
    GLFW_KEY_R,
    GLFW_KEY_S,
    GLFW_KEY_T,
    GLFW_KEY_U,
    GLFW_KEY_V,
    GLFW_KEY_W,
    GLFW_KEY_X,
    GLFW_KEY_Y,
    GLFW_KEY_Z,
    GLFW_KEY_LEFT_BRACKET,
    GLFW_KEY_BACKSLASH,
    GLFW_KEY_RIGHT_BRACKET,
    GLFW_KEY_GRAVE_ACCENT,
    GLFW_KEY_WORLD_1,
    GLFW_KEY_WORLD_2,
    GLFW_KEY_ESCAPE,
    GLFW_KEY_ENTER,
    GLFW_KEY_TAB,
    GLFW_KEY_BACKSPACE,
    GLFW_KEY_INSERT,
    GLFW_KEY_DELETE,
    GLFW_KEY_RIGHT,
    GLFW_KEY_LEFT,
    GLFW_KEY_DOWN,
    GLFW_KEY_UP,
    GLFW_KEY_PAGE_UP,
    GLFW_KEY_PAGE_DOWN,
    GLFW_KEY_HOME,
    GLFW_KEY_END,
    GLFW_KEY_CAPS_LOCK,
    GLFW_KEY_SCROLL_LOCK,
    GLFW_KEY_NUM_LOCK,
    GLFW_KEY_PRINT_SCREEN,
    GLFW_KEY_PAUSE,
    GLFW_KEY_F1,
    GLFW_KEY_F2,
    GLFW_KEY_F3,
    GLFW_KEY_F4,
    GLFW_KEY_F5,
    GLFW_KEY_F6,
    GLFW_KEY_F7,
    GLFW_KEY_F8,
    GLFW_KEY_F9,
    GLFW_KEY_F10,
    GLFW_KEY_F11,
    GLFW_KEY_F12,
    GLFW_KEY_F13,
    GLFW_KEY_F14,
    GLFW_KEY_F15,
    GLFW_KEY_F16,
    GLFW_KEY_F17,
    GLFW_KEY_F18,
    GLFW_KEY_F19,
    GLFW_KEY_F20,
    GLFW_KEY_F21,
    GLFW_KEY_F22,
    GLFW_KEY_F23,
    GLFW_KEY_F24,
    GLFW_KEY_F25,
    GLFW_KEY_KP_0,
    GLFW_KEY_KP_1,
    GLFW_KEY_KP_2,
    GLFW_KEY_KP_3,
    GLFW_KEY_KP_4,
    GLFW_KEY_KP_5,
    GLFW_KEY_KP_6,
    GLFW_KEY_KP_7,
    GLFW_KEY_KP_8,
    GLFW_KEY_KP_9,
    GLFW_KEY_KP_DECIMAL,
    GLFW_KEY_KP_DIVIDE,
    GLFW_KEY_KP_MULTIPLY,
    GLFW_KEY_KP_SUBTRACT,
    GLFW_KEY_KP_ADD,
    GLFW_KEY_KP_ENTER,
    GLFW_KEY_KP_EQUAL,
    GLFW_KEY_LEFT_SHIFT,
    GLFW_KEY_LEFT_CONTROL,
    GLFW_KEY_LEFT_ALT,
    GLFW_KEY_LEFT_SUPER,
    GLFW_KEY_RIGHT_SHIFT,
    GLFW_KEY_RIGHT_CONTROL,
    GLFW_KEY_RIGHT_ALT,
    GLFW_KEY_RIGHT_SUPER,
    GLFW_KEY_MENU,
];