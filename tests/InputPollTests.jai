// Loads the complete production input owner, not a copy of its polling logic.
// From KodaJai: /usr/local/bin/jai input_poll_tests.jai -quiet && ./.build/input_poll_tests
// No GLFW initialization, window, graphics, game scenes, or real controller polling.
#import "Basic";
#import "Math";
#import "File";
#import "String";
#import "JaiMath";
#import "JaiGLFW";

#scope_file

mock_present: [GLFW_JOYSTICK_LAST + 1] bool;
mock_gamepad: [GLFW_JOYSTICK_LAST + 1] bool;
mock_valid: [GLFW_JOYSTICK_LAST + 1] bool;
mock_states: [GLFW_JOYSTICK_LAST + 1] GLFWgamepadstate;
mock_keys: [GLFW_KEY_LAST + 1] s32;
mock_sticky_keys: [GLFW_KEY_LAST + 1] bool;
mock_key_calls: [GLFW_KEY_LAST + 1] int;
mock_mouse_buttons: [GLFW_MOUSE_BUTTON_LAST + 1] s32;
mock_sticky_mouse_buttons: [GLFW_MOUSE_BUTTON_LAST + 1] bool;
mock_mouse_button_calls: [GLFW_MOUSE_BUTTON_LAST + 1] int;
mock_cursor: [2] float64;
mock_state_calls: int;
mock_window_focused: bool = true;
window_focused: bool = true;

koda: struct { window: *GLFWwindow; };
mouse_capture: bool;
mouse_boundary_enabled: bool;

// Same enum sizing helper as src/Utilities.jai, without loading graphics utilities.
enum_count :: ($t: Type) -> s64 { return enum_highest_value(t) + 1; }

// File-local mocks override imported GLFW procedures for the inserted owner.
glfwJoystickPresent :: (joystick: s32) -> s32 {
    return cast(s32) mock_present[joystick];
}
glfwJoystickIsGamepad :: (joystick: s32) -> s32 {
    return cast(s32) mock_gamepad[joystick];
}
glfwGetGamepadState :: (joystick: s32, state: *GLFWgamepadstate) -> s32 {
    mock_state_calls += 1;
    state.* = mock_states[joystick];
    return cast(s32) mock_valid[joystick];
}
glfwGetCursorPos :: (window: *GLFWwindow, x: *float64, y: *float64) {
    x.* = mock_cursor[0];
    y.* = mock_cursor[1];
}
glfwGetMouseButton :: (window: *GLFWwindow, button: s32) -> s32 {
    mock_mouse_button_calls[button] += 1;
    if mock_sticky_mouse_buttons[button] {
        mock_sticky_mouse_buttons[button] = false;
        return GLFW_PRESS;
    }
    return mock_mouse_buttons[button];
}
glfwGetKey :: (window: *GLFWwindow, key: s32) -> s32 {
    mock_key_calls[key] += 1;
    if mock_sticky_keys[key] {
        mock_sticky_keys[key] = false;
        return GLFW_PRESS;
    }
    return mock_keys[key];
}
glfwGetWindowAttrib :: (window: *GLFWwindow, attribute: s32) -> s32 {
    assert(attribute == GLFW_FOCUSED);
    return cast(s32) mock_window_focused;
}
glfwSetWindowShouldClose :: (window: *GLFWwindow, value: s32) {
    assert(false, "Input poll tests must not request window shutdown.");
}

#insert #run read_entire_file(tprint("%../src/Input.jai", #filepath));

// Compile the real focus owner without loading unrelated window/graphics machinery.
#insert #run -> string {
    source := read_entire_file(tprint("%../src/Window.jai", #filepath));
    getter_start := find_index_from_left(source, "get_focused :: (");
    getter_end := find_index_from_left(source, "request_focus :: (", getter_start);
    callback_start := find_index_from_left(source, "focus_callback :: (");
    callback_end := find_index_from_left(source, "time_slice_ms ::", callback_start);
    registration_text := "glfwSetWindowFocusCallback(koda.window, focus_callback);";
    registration := find_index_from_left(source, registration_text);
    initial_start := registration + registration_text.count;
    initial_end := find_index_from_left(source, #char ";", initial_start);
    assert(getter_start >= 0 && getter_end > getter_start && callback_start >= 0 && callback_end > callback_start);
    assert(registration >= 0 && initial_start > registration && initial_end > initial_start);
    return tprint("%\n%\ninitialize_window_focus_fixture :: () { % }\n",
        slice(source, getter_start, getter_end - getter_start),
        slice(source, callback_start, callback_end - callback_start),
        slice(source, initial_start, initial_end - initial_start + 1));
};

checks: int;
failures: int;
scenario: string;

check :: (condition: bool, message: string) {
    checks += 1;
    if condition return;
    failures += 1;
    print("FAIL input poll [%]: %\n", scenario, message);
}

reset_fixture :: () {
    input = .{};
    controller_input_blocked_until_release = false;
    controller_release_pending_features = .None;
    memset(mock_present.data, 0, size_of(type_of(mock_present)));
    memset(mock_gamepad.data, 0, size_of(type_of(mock_gamepad)));
    memset(mock_valid.data, 0, size_of(type_of(mock_valid)));
    memset(mock_states.data, 0, size_of(type_of(mock_states)));
    memset(mock_keys.data, 0, size_of(type_of(mock_keys)));
    memset(mock_sticky_keys.data, 0, size_of(type_of(mock_sticky_keys)));
    memset(mock_key_calls.data, 0, size_of(type_of(mock_key_calls)));
    memset(mock_mouse_buttons.data, 0, size_of(type_of(mock_mouse_buttons)));
    memset(mock_sticky_mouse_buttons.data, 0, size_of(type_of(mock_sticky_mouse_buttons)));
    memset(mock_mouse_button_calls.data, 0, size_of(type_of(mock_mouse_button_calls)));
    mock_cursor = .[300, 400];
    mock_state_calls = 0;
    mock_window_focused = true;
    window_focused = true;
    raw_mouse_x = 0;
    raw_mouse_y = 0;
    accumulated_scroll = .[0, 0];
    mouse_position = .[0, 0];
    accumulated_mouse = .[0, 0];
    mouse_position_valid = false;
    mouse_left_tracking = false;
    joystick_padding = 0.2;
    trigger_activation_distance = 0.2;
    abort_shortcut = false;
}

connect_held :: (joystick: int) {
    mock_present[joystick] = true;
    mock_gamepad[joystick] = true;
    mock_valid[joystick] = true;
    state := *mock_states[joystick];
    for *button: state.buttons button.* = GLFW_PRESS;
    state.axes[GLFW_GAMEPAD_AXIS_LEFT_X] = 0.75;
    state.axes[GLFW_GAMEPAD_AXIS_LEFT_Y] = -0.5;
    state.axes[GLFW_GAMEPAD_AXIS_RIGHT_X] = -0.6;
    state.axes[GLFW_GAMEPAD_AXIS_RIGHT_Y] = 0.8;
    state.axes[GLFW_GAMEPAD_AXIS_LEFT_TRIGGER] = 1;
    state.axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = 1;
}

connect_neutral :: (joystick: int) {
    mock_present[joystick] = true;
    mock_gamepad[joystick] = true;
    mock_valid[joystick] = true;
    mock_states[joystick] = .{};
    mock_states[joystick].axes[GLFW_GAMEPAD_AXIS_LEFT_TRIGGER] = -1;
    mock_states[joystick].axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = -1;
}

check_held :: (fresh: bool) {
    check(input.controller_active, "controller activity is reported");
    check(length(input.controller_left) > 0.5 && length(input.controller_right) > 0.5, "both real deadzone-adjusted stick paths are held");
    check(length(input.controller_left_projected) > 0.5 && length(input.controller_right_projected) > 0.5, "both projected stick paths are held");
    expected: KodaInputState = ifx fresh then .DOWN | .START else .DOWN;
    for button, index: input.buttons {
        check(button == expected, tprint("button % has correct held/start state", index));
        check(!input.released_buttons[index], tprint("button % has no release while held", index));
    }
    for trigger, index: input.triggers {
        check(trigger == 1 && input.trigger_buttons[index] == expected, tprint("raw trigger % and its edge state are held", index));
        check(input.trigger_activations[index] == 1, tprint("trigger % records peak activation", index));
    }
}

check_neutral :: (value: Input, releases: bool = false) {
    check(value.controller_left == Vector2.{} && value.controller_right == Vector2.{}, "both stick axes are neutral");
    check(value.controller_left_projected == Vector2.{} && value.controller_right_projected == Vector2.{}, "both projected axes are neutral");
    for button, index: value.buttons {
        check(button == .NONE, tprint("button % is cleared", index));
        check(value.released_buttons[index] == releases, tprint("button % has correct release state", index));
    }
    for trigger, index: value.triggers {
        check(trigger == -1, tprint("raw trigger % rests at -1, not 0", index));
        check(value.trigger_buttons[index] == .NONE, tprint("trigger % has no held/start state", index));
        check(value.trigger_deactivations[index] == -1, tprint("trigger % deactivation history is neutral", index));
    }
    check(value.controller_left_trigger == 0 && value.controller_right_trigger == 0, "legacy trigger scalars are cleared");
}

check_disconnected :: () {
    check(!input.controller_active, "disconnect clears sticky controller activity");
    check_neutral(input);
    for activation, index: input.trigger_activations check(activation == 0, tprint("trigger % activation history is reset", index));
    check(!controller_input_is_down(), "persisted controller owner reports neutral");
    check(!controller_input_blocked_until_release, "console release gate rearms after disconnect");
    value := get_input();
    check(!value.controller_active, "public input reports controller inactive");
    check_neutral(value);
}

check_mouse_keyboard :: () {
    check(input.keys[KodaKey.SPACE] == .DOWN && !input.released_keys[KodaKey.SPACE], "held keyboard key is not erased by controller reset");
    check(input.mouse_left == .DOWN && !input.released_mouse_left, "held mouse button is not erased by controller reset");
    check(input.mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] == .DOWN, "generic mouse button state survives");
    check(input.mouse == Vector2.{300, 400}, "mouse-only poll still updates cursor");
    check(input.mouse_left_start == Vector2.{20, 30}, "mouse press origin survives");
    check(input.mouse_left_maximum_drag_distance_squared == 81 && input.released_mouse_left_maximum_drag_distance_squared == 49 && input.mouse_left_release_tracked, "mouse tracking metadata survives");
    check(!input.char_input && input.char_input_buffer[0] == 66, "keyboard character buffer is processed normally");
    check(input.scroll_delta_x == 2 && input.scroll_delta_y == -3, "pending mouse scroll is processed normally");
    value := get_input();
    check(value.keys[KodaKey.SPACE] == .DOWN && value.mouse_left == .DOWN, "public input retains keyboard and mouse after controller gate clears");
}

// Exercise the exact render/physics masks used by FatGoblins, including their ordering.
test_disconnect :: (joystick: int, failure_mode: int, neutral_reconnect: bool) {
    scenario = tprint("joystick %, no-state mode %, neutral reconnect %", joystick, failure_mode, neutral_reconnect);
    reset_fixture();
    connect_held(joystick);
    update_inputs(.ControllerButtons | .ControllerMove);
    check(mock_state_calls == 1, "real owner polls the mock gamepad");
    check_held(true);
    before := input;
    update_inputs(.MouseMove);
    check(input.controller_left == before.controller_left && input.controller_right == before.controller_right, "connected mouse-only poll preserves stick fields");
    for button, index: input.buttons check(button == before.buttons[index], tprint("connected mouse-only poll preserves button %", index));
    for trigger, index: input.triggers check(trigger == before.triggers[index], tprint("connected mouse-only poll preserves raw trigger %", index));
    update_inputs(~.MouseMove);
    check_held(false);

    input.keys[KodaKey.SPACE] = .DOWN;
    mock_keys[GLFW_KEY_SPACE] = GLFW_PRESS;
    input.mouse_left = .DOWN;
    input.mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = .DOWN;
    mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_PRESS;
    input.controller_left_trigger = 0.7;
    input.controller_right_trigger = 0.9;
    for *released: input.released_buttons released.* = true;
    set_char_input(true);
    set_char_input(false);
    // This scenario checks disconnect preservation, not character-input gesture cancellation.
    input.mouse_left_start = .{20, 30};
    input.mouse_left_maximum_drag_distance_squared = 81;
    input.released_mouse_left_maximum_drag_distance_squared = 49;
    input.mouse_left_release_tracked = true;
    update_inputs(.ControllerButtons | .ControllerMove);
    check(controller_input_blocked_until_release, "closing console with held controller arms release gate");
    check(input.controller_active && !get_input().controller_active, "held poll reactivates persisted owner while public console gate masks it");
    check_neutral(get_input());
    check(length(input.controller_left) > 0.5, "console masking does not erase persisted held axes");
    input.char_input_back_buffer[0] = 66;
    accumulated_scroll = .[2, -3];
    for *released: input.released_buttons released.* = true;
    input.trigger_deactivations = .[-0.8, -0.6];

    if failure_mode == {
        case 0; mock_present[joystick] = false;
        case 1; mock_gamepad[joystick] = false;
        case 2; mock_valid[joystick] = false;
    }
    before = input;
    calls_before := mock_state_calls;
    update_inputs(.MouseMove);
    check(!input.controller_active, "no-state mouse-only poll clears activity");
    check(input.controller_left == before.controller_left && input.controller_right == before.controller_right, "mouse-only feature mask preserves unrequested stick fields");
    for button, index: input.buttons check(button == before.buttons[index], tprint("mouse-only feature mask preserves unrequested button %", index));
    for trigger, index: input.triggers check(trigger == before.triggers[index], tprint("mouse-only feature mask preserves unrequested raw trigger %", index));
    check(controller_input_blocked_until_release, "mouse-only poll cannot prematurely release held controller gate");
    update_inputs(~.MouseMove);
    expected_calls := calls_before + (ifx failure_mode == 2 then 2 else 0);
    check(mock_state_calls == expected_calls, "absent/non-gamepad/failed-poll paths reach the expected GLFW calls");
    check_disconnected();
    check_mouse_keyboard();

    if neutral_reconnect {
        connect_neutral(joystick);
        update_inputs(.MouseMove);
        update_inputs(~.MouseMove);
        check_disconnected();
        check(input.keys[KodaKey.SPACE] == .DOWN && input.mouse_left == .DOWN, "neutral reconnect does not lose keyboard or mouse");
    }

    mock_keys[GLFW_KEY_SPACE] = GLFW_RELEASE;
    connect_held(joystick);
    update_inputs(.MouseMove);
    update_inputs(~.MouseMove);
    check_held(true);
    check(!controller_input_blocked_until_release, "fresh held reconnect is not stuck behind console gate");
    connect_neutral(joystick);
    update_inputs(~.MouseMove);
    check_neutral(input, true);
    check(!controller_input_is_down(), "connected release is neutral to the owner");
    check(input.controller_active, "normal release preserves last-device activity, unlike disconnect");
    update_inputs(~.MouseMove);
    check_neutral(input);
}

test_console_release :: () {
    scenario = "connected console-release gate";
    reset_fixture();
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    set_char_input(true);
    set_char_input(false);
    update_inputs(.MouseMove);
    update_inputs(~.MouseMove);
    check(controller_input_blocked_until_release && controller_input_is_down(), "held connected input keeps console gate armed");
    check_neutral(get_input());
    connect_neutral(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    check(!controller_input_blocked_until_release && !input.controller_active, "connected neutral release clears gate and activity");
    check_neutral(input);
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    check_held(true);
}

test_trigger_modality :: () {
    scenario = "held right trigger after mouse takeover";
    reset_fixture();
    connect_neutral(GLFW_JOYSTICK_1);
    mock_states[GLFW_JOYSTICK_1].axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = 0;
    update_inputs(~.MouseMove);
    check(input.controller_active && get_input().controller_active, "half-held RT activates controller modality");
    check(input.triggers[KodaTrigger.RIGHT] == 0 && input.trigger_activations[KodaTrigger.RIGHT] == 0, "half-held RT records its raw value and activation peak");
    check(input.trigger_buttons[KodaTrigger.RIGHT] == (.DOWN | .START), "initial RT activation has a fresh start edge");

    mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_PRESS;
    update_inputs(.MouseMove);
    update_inputs(~.MouseMove);
    check(input.mouse_left == (.DOWN | .START), "real mouse press takes over while RT is held");
    check(!input.controller_active && !get_input().controller_active, "mouse press switches to mouse modality");
    mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_RELEASE;
    update_inputs(~.MouseMove);
    check(!input.controller_active && !get_input().controller_active, "unchanged held RT does not steal mouse modality");
    check(input.trigger_buttons[KodaTrigger.RIGHT] == .DOWN && input.trigger_activations[KodaTrigger.RIGHT] == 0, "unchanged held RT preserves its peak without another start edge");

    mock_states[GLFW_JOYSTICK_1].axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = 0.5;
    update_inputs(~.MouseMove);
    check(input.controller_active && get_input().controller_active, "RT increase beyond its activation peak restores controller modality");
    check(input.triggers[KodaTrigger.RIGHT] == 0.5 && input.trigger_activations[KodaTrigger.RIGHT] == 0.5, "RT increase updates the raw value and activation peak");
    check(input.trigger_buttons[KodaTrigger.RIGHT] == .DOWN, "RT increase does not generate a second start edge");

    mock_states[GLFW_JOYSTICK_1].axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = -1;
    update_inputs(~.MouseMove);
    check(input.triggers[KodaTrigger.RIGHT] == -1 && input.trigger_buttons[KodaTrigger.RIGHT] == .NONE, "RT release clears the held state and raw value");
    check(input.trigger_deactivations[KodaTrigger.RIGHT] == -1 && !controller_input_is_down(), "RT release records neutral deactivation and leaves no held controller input");
    check(input.controller_active, "RT release preserves last-device controller modality");
    update_inputs(~.MouseMove);
    check(input.trigger_buttons[KodaTrigger.RIGHT] == .NONE && !controller_input_is_down(), "neutral RT remains released on the next poll");
}

test_feature_masks :: ($first: InputFeature, $second: InputFeature) {
    scenario = tprint("isolated masks % then %", first, second);
    reset_fixture();
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(.ControllerButtons | .ControllerMove);
    set_char_input(true);
    set_char_input(false);
    mock_present[GLFW_JOYSTICK_1] = false;
    update_inputs(first);
    #if first & .ControllerButtons {
        for button: input.buttons check(button == .NONE, "buttons-only reset clears button state");
        check(input.triggers[0] == -1 && input.triggers[1] == -1, "buttons-only reset clears raw triggers");
        check(length(input.controller_left) > 0.5, "buttons-only reset preserves unrequested stick fields");
    } else {
        check(input.controller_left == Vector2.{} && input.controller_right == Vector2.{}, "move-only reset clears stick fields");
        check(!!(input.buttons[KodaButton.A] & .DOWN), "move-only reset preserves unrequested buttons");
        check(input.triggers[0] == 1 && input.triggers[1] == 1, "move-only reset preserves unrequested raw triggers");
    }
    check(controller_input_blocked_until_release, "partial controller reset does not release remaining held input");
    update_inputs(second);
    check_disconnected();
}

test_focus_controller :: ($first: InputFeature, $second: InputFeature) {
    scenario = tprint("focus/rearm masks % then %", first, second);
    reset_fixture();
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    focus_callback(null, GLFW_FALSE);
    check(!get_focused() && !get_input().controller_active, "focus callback immediately masks held controller activity");
    check_neutral(get_input());

    connect_neutral(GLFW_JOYSTICK_1);
    update_inputs(first);
    update_inputs(second);
    check(controller_input_blocked_until_release, "neutral background polling cannot rearm controller input");
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(first);
    update_inputs(second);
    check(!get_input().controller_active, "background controller press cannot claim public modality");
    check_neutral(get_input());

    focus_callback(null, GLFW_TRUE);
    check_neutral(get_input());
    update_inputs(first);
    update_inputs(second);
    check(controller_input_blocked_until_release, "held controls stay blocked after refocus");
    check_neutral(get_input());
    connect_neutral(GLFW_JOYSTICK_1);
    update_inputs(first);
    check(controller_input_blocked_until_release, "partial poll preserves unrefreshed held controls");
    update_inputs(second);
    check(!controller_input_blocked_until_release && !get_input().controller_active, "focused neutral poll rearms without controller takeover");
    check_neutral(get_input());
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    check_held(true);
    check(get_input().buttons[KodaButton.A] == (.DOWN | .START), "fresh post-neutral press reaches public input");
}

test_focus_stale_neutral :: ($first: InputFeature, $second: InputFeature) {
    scenario = tprint("focus stale-neutral masks % then %", first, second);
    reset_fixture();
    connect_neutral(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    focus_callback(null, GLFW_FALSE);
    focus_callback(null, GLFW_TRUE);
    // Both focus events may arrive in one event batch before any controller poll.
    #if first & .ControllerButtons {
        mock_states[GLFW_JOYSTICK_1].axes[GLFW_GAMEPAD_AXIS_LEFT_X] = 0.8;
    } else {
        mock_states[GLFW_JOYSTICK_1].buttons[KodaButton.A] = GLFW_PRESS;
    }
    update_inputs(first);
    check(controller_input_blocked_until_release, "stale neutral fields cannot rearm after a partial first poll");
    update_inputs(second);
    check(controller_input_blocked_until_release, "newly sampled held control still requires neutral");
    check_neutral(get_input());
    connect_neutral(GLFW_JOYSTICK_1);
    update_inputs(first);
    update_inputs(second);
    check(!controller_input_blocked_until_release, "fresh neutral samples rearm after split polls");
}

test_focus_disconnect :: () {
    scenario = "unfocused disconnect/reconnect";
    reset_fixture();
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    focus_callback(null, GLFW_FALSE);
    mock_present[GLFW_JOYSTICK_1] = false;
    update_inputs(.MouseMove);
    update_inputs(~.MouseMove);
    check(controller_input_blocked_until_release, "background disconnect does not bypass the focus gate");
    connect_held(GLFW_JOYSTICK_1);
    focus_callback(null, GLFW_TRUE);
    update_inputs(.MouseMove);
    update_inputs(~.MouseMove);
    check(controller_input_blocked_until_release, "held reconnect across focus remains blocked");
    check_neutral(get_input());
    mock_present[GLFW_JOYSTICK_1] = false;
    update_inputs(~.MouseMove);
    check_disconnected();
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    check_held(true);
}

test_focus_trigger_neutral :: () {
    scenario = "focus gate requires trigger neutral, not only hysteresis release";
    reset_fixture();
    connect_neutral(GLFW_JOYSTICK_1);
    mock_states[GLFW_JOYSTICK_1].axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = 1;
    update_inputs(~.MouseMove);
    focus_callback(null, GLFW_FALSE);
    focus_callback(null, GLFW_TRUE);
    mock_states[GLFW_JOYSTICK_1].axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = 0.5;
    update_inputs(~.MouseMove);
    check(input.trigger_buttons[KodaTrigger.RIGHT] == .NONE, "existing trigger hysteresis still releases the digital button");
    check(controller_input_blocked_until_release, "partially held raw trigger cannot rearm focus input");
    check_neutral(get_input());
    mock_states[GLFW_JOYSTICK_1].axes[GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER] = -0.9;
    update_inputs(~.MouseMove);
    check(!controller_input_blocked_until_release, "trigger inside resting activation margin allows neutral rearm");
}

test_mouse_ownership :: (transition: int, release_before_transition: bool) {
    scenario = tprint("mouse ownership transition %, pending release %", transition, release_before_transition);
    reset_fixture();
    initialize_mouse_position(null);
    if transition == 1 set_char_input(true);
    mouse_button_callback(null, GLFW_MOUSE_BUTTON_LEFT, GLFW_PRESS, 0);
    mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_PRESS;
    update_inputs(.MouseButtons);
    check(mouse_left_tracking, "focused press begins tracked gesture");
    if release_before_transition {
        mouse_button_callback(null, GLFW_MOUSE_BUTTON_LEFT, GLFW_RELEASE, 0);
        mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_RELEASE;
        update_inputs(.MouseButtons);
        check(mouse_left_clicked(16), "ordinary click qualifies before ownership changes");
    }
    if transition == {
        case 0; set_char_input(true);
        case 1; set_char_input(false);
        case 2;
            focus_callback(null, GLFW_FALSE);
            focus_callback(null, GLFW_TRUE);
    }
    check(!mouse_left_tracking && !input.mouse_left_release_tracked, "ownership transition cancels held and completed click tracking");
    check(!mouse_left_clicked(16), "pending click cannot cross ownership transition");
    if !release_before_transition {
        mouse_button_callback(null, GLFW_MOUSE_BUTTON_LEFT, GLFW_RELEASE, 0);
        mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_RELEASE;
        update_inputs(.MouseButtons);
        check(!mouse_left_clicked(16), "old held press cannot become a click in the new owner");
    }
    mouse_button_callback(null, GLFW_MOUSE_BUTTON_LEFT, GLFW_PRESS, 0);
    mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_PRESS;
    update_inputs(.MouseButtons);
    mouse_button_callback(null, GLFW_MOUSE_BUTTON_LEFT, GLFW_RELEASE, 0);
    mock_mouse_buttons[GLFW_MOUSE_BUTTON_LEFT] = GLFW_RELEASE;
    update_inputs(.MouseButtons);
    check(mouse_left_clicked(16), "fresh press/release still clicks after cancellation");
}

test_focus_mouse_rebase :: () {
    scenario = "focus mouse rebase";
    reset_fixture();
    initialize_mouse_position(null);
    input.mouse_delta_x = 12;
    input.mouse_delta_y = -9;
    focus_callback(null, GLFW_FALSE);
    mock_cursor = .[900, 700];
    focus_callback(null, GLFW_TRUE);
    check(input.mouse_delta_x == 0 && input.mouse_delta_y == 0, "focus gain clears already-published mouse deltas");
    update_inputs(.MouseMove);
    check(input.mouse == Vector2.{900, 700}, "focus rebase retains actual pointer location");
    check(input.mouse_delta_x == 0 && input.mouse_delta_y == 0, "first focused poll does not publish background displacement");
    mock_cursor = .[907, 697];
    mouse_callback(null, 907, 697);
    update_inputs(.MouseMove);
    check(input.mouse_delta_x == 7 && input.mouse_delta_y == -3, "real motion after refocus is not discarded");
}

test_initial_focus :: () {
    scenario = "initial window focus attribute";
    reset_fixture();
    mock_window_focused = false;
    initialize_window_focus_fixture();
    check(!get_focused(), "hidden/unfocused creation uses the GLFW focus attribute");
    connect_held(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    check(!get_input().controller_active && controller_input_blocked_until_release, "initially unfocused window blocks controller input without a focus event");
    check_neutral(get_input());
    mock_window_focused = true;
    initialize_window_focus_fixture();
    check(get_focused(), "focused creation also uses the actual GLFW attribute");
}

test_sticky_keys :: (char_input: bool) {
    scenario = tprint("sticky key sampling, character input %", char_input);
    reset_fixture();
    set_char_input(char_input);
    for key: glfw_key_map mock_sticky_keys[key] = true;
    update_inputs(.MouseMove);
    for key: glfw_key_map check(mock_key_calls[key] == 0 && mock_sticky_keys[key], "mouse-only poll does not consume a pending sticky key");
    update_inputs(.Keys);
    for key, index: glfw_key_map {
        check(mock_key_calls[key] == 1, tprint("key % is sampled exactly once", key));
        state := ifx char_input then input.char_input_keys[index] else input.keys[index];
        other := ifx char_input then input.keys[index] else input.char_input_keys[index];
        check(state == (.DOWN | .START) && other == .NONE, tprint("sticky key % reaches only its current owner", key));
    }
    update_inputs(.Keys);
    for key, index: glfw_key_map {
        check(mock_key_calls[key] == 2, tprint("released key % is sampled once on the next poll", key));
        check(input.keys[index] == .NONE && input.char_input_keys[index] == .NONE, tprint("sticky key % releases without another start", key));
        check(input.released_keys[index] == !char_input, tprint("key % release belongs only to the normal-key path", key));
    }
}

test_sticky_mouse :: () {
    scenario = "sticky mouse sampled once for dedicated and generic fields";
    reset_fixture();
    for *sticky: mock_sticky_mouse_buttons sticky.* = true;
    update_inputs(.MouseMove);
    for calls: mock_mouse_button_calls check(calls == 0, "mouse-move-only poll does not consume sticky buttons");
    update_inputs(.MouseButtons);
    for state, index: input.mouse_buttons {
        check(mock_mouse_button_calls[index] == 1, tprint("mouse button % is sampled exactly once", index));
        check(state == (.DOWN | .START), tprint("generic mouse button % receives the sticky start", index));
    }
    check(input.mouse_left == input.mouse_buttons[GLFW_MOUSE_BUTTON_LEFT], "left dedicated/generic snapshots agree");
    check(input.mouse_right == input.mouse_buttons[GLFW_MOUSE_BUTTON_RIGHT], "right dedicated/generic snapshots agree");
    check(input.mouse_middle == input.mouse_buttons[GLFW_MOUSE_BUTTON_MIDDLE], "middle dedicated/generic snapshots agree");
    update_inputs(.MouseButtons);
    for state, index: input.mouse_buttons {
        check(mock_mouse_button_calls[index] == 2 && state == .NONE, tprint("mouse button % releases on one subsequent sample", index));
    }
    check(input.released_mouse_left && input.released_mouse_right && input.released_mouse_middle, "dedicated mouse releases still fire once");
}

test_wheel_modality :: (horizontal: bool) {
    scenario = tprint("wheel takeover, horizontal %", horizontal);
    reset_fixture();
    connect_neutral(GLFW_JOYSTICK_1);
    mock_states[GLFW_JOYSTICK_1].buttons[KodaButton.A] = GLFW_PRESS;
    update_inputs(~.MouseMove);
    connect_neutral(GLFW_JOYSTICK_1);
    update_inputs(~.MouseMove);
    check(input.controller_active, "released controller remains the last active device");
    if horizontal scroll_callback(null, 2, 0);
    else scroll_callback(null, 0, -3);
    update_inputs(.MouseMove);
    check(input.controller_active, "unrequested scroll remains pending without changing modality");
    update_inputs(~.MouseMove);
    check(!input.controller_active && !get_input().controller_active, "fresh wheel input claims mouse modality");
    if horizontal check(input.scroll_delta_x == 2 && input.scroll_delta_y == 0, "horizontal wheel delta is retained");
    else check(input.scroll_delta_x == 0 && input.scroll_delta_y == -3, "vertical wheel delta is retained");
    update_inputs(~.MouseMove);
    check(input.scroll_delta_x == 0 && input.scroll_delta_y == 0 && !input.controller_active, "wheel is consumed once and mouse modality persists");
    mock_states[GLFW_JOYSTICK_1].buttons[KodaButton.A] = GLFW_PRESS;
    update_inputs(~.MouseMove);
    check(input.controller_active, "fresh controller button still restores controller modality");
}

#scope_export
main :: () {
    for joystick: int.[GLFW_JOYSTICK_1, GLFW_JOYSTICK_LAST] {
        for failure_mode: 0..2 {
            test_disconnect(joystick, failure_mode, false);
            test_disconnect(joystick, failure_mode, true);
        }
    }
    test_console_release();
    test_trigger_modality();
    test_feature_masks(.ControllerButtons, .ControllerMove);
    test_feature_masks(.ControllerMove, .ControllerButtons);
    test_focus_controller(.MouseMove, ~.MouseMove);
    test_focus_controller(.ControllerButtons, .ControllerMove);
    test_focus_controller(.ControllerMove, .ControllerButtons);
    test_focus_stale_neutral(.MouseMove, ~.MouseMove);
    test_focus_stale_neutral(.ControllerButtons, .ControllerMove);
    test_focus_stale_neutral(.ControllerMove, .ControllerButtons);
    test_focus_disconnect();
    test_focus_trigger_neutral();
    for transition: 0..2 {
        test_mouse_ownership(transition, false);
        test_mouse_ownership(transition, true);
    }
    test_focus_mouse_rebase();
    test_initial_focus();
    test_sticky_keys(false);
    test_sticky_keys(true);
    test_sticky_mouse();
    test_wheel_modality(false);
    test_wheel_modality(true);
    // Multi-pad selection/handover and held digital/stick modality policy remain deferred.
    print("Input poll tests: % checks, % failures; real input/focus owners, split masks, disconnect/reconnect, console/focus neutral gates, click cancellation, mouse rebase, initial focus, sticky sampling, trigger/wheel modality.\n", checks, failures);
    if failures > 0 exit(1);
}
