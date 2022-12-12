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

draw_fps :: (x: float, y: float) {
    fps := get_fps();
    integer := cast(int) fps;
    remainder := cast(int) ((fps - integer) * 100);

    default_text := get_default_text();
    default_text.text = tprint("FPS: %.%", integer, remainder);

    depth_test := get_depth_test();
    cull_face := get_cull_face();
    transform := koda.transform;

    set_depth_test(false);
    defer set_depth_test(depth_test);
    set_cull_face(false);
    defer set_cull_face(cull_face);
    koda.transform = Matrix4_Identity;
    defer koda.transform = transform;

    draw_text(default_text, xy(x, y));
}

#scope_module

tick_frame_tracker :: (tracker: *FrameTracker, time: float64) {
    tracker.history[tracker.next_index] = time;
    tracker.next_index = (tracker.next_index + 1) % tracker.history.count;
}

#scope_file

FRAME_HISTORY_COUNT :: 60;

#import "Basic";