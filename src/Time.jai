FrameTracker :: struct {
    history: [FRAME_HISTORY_COUNT] float64;
    next_index: int;
}

TimeTracker :: struct {
    vsync: bool;
    target_fps: float;
    last_loop_time: float64;
}

get_fps :: () -> float {
    start_index := koda.frame_tracker.next_index;
    if koda.frame_tracker.history[start_index] == 0 {
        start_index = 0;
    }

    first_time := koda.frame_tracker.history[start_index];
    if start_index == 0 && first_time == 0 {
        return 0.0;
    }

    last_index := (koda.frame_tracker.next_index + FRAME_HISTORY_COUNT - 1) % FRAME_HISTORY_COUNT;
    last_time := koda.frame_tracker.history[last_index];

    delta_time := last_time - first_time;
    delta_frames := (last_index - start_index + FRAME_HISTORY_COUNT) % FRAME_HISTORY_COUNT;

    if delta_time == 0 {
        return 0.0;
    }

    return cast(float) (delta_frames / delta_time);
}

draw_fps :: (position: Vector2, anchor: Vector2 = .{}, font: *Font = null) {
    draw_fps(position.x, position.y, anchor, font);
}

draw_fps :: (x: float, y: float, anchor: Vector2 = .{}, font: *Font = null) {
    if !font then font = get_default_font();

    fps := get_fps();
    integer := cast(int) fps;
    remainder := cast(int) ((fps - integer) * 100);

    content := tprint("FPS: %.%", integer, remainder);

    set_depth_test_scope(false);

    buffer_text(content, font, .{x, y}, anchor, fixed_height_string = "FPS");
    if !font.buffer_required {
        flush_text(font);
    }
}

tick_frame_tracker :: (tracker: *FrameTracker, time: float64) {
    tracker.history[tracker.next_index] = time;
    tracker.next_index = (tracker.next_index + 1) % tracker.history.count;
}

#scope_module

#scope_file

FRAME_HISTORY_COUNT :: 60;

#import "Basic";