
PERF_TRACKER_ENABLED :: false;

#if PERF_TRACKER_ENABLED {
    perf_track :: ($name: string) #expand {
        tracker_start_time := seconds_since_init();

        tracker_info := get_or_add_tracker(name);
        assert(tracker_info.current_time == 0, "Tried to call tracker start twice in a row.");
        tracker_info.current_time = tracker_start_time;

        `defer {
            glFinish();
            tracker_final_time := seconds_since_init();

            tracker_info := get_or_add_tracker(name);
            tracker_info.times[tracker_info.next_index] = (tracker_final_time - tracker_info.current_time) * 1000.0;
            tracker_info.next_index = (tracker_info.next_index + 1) % tracker_info.times.count;

            tracker_info.current_time = 0;
        }
    }
} else {
    perf_track :: ($name: string) #expand {}
}

#if PERF_TRACKER_ENABLED {
    perf_tracker_print :: (interval: int) {
        print_index += 1;
        if print_index % interval != 0 {
            return;
        }

        builder: String_Builder;
        append(*builder, "(PERF) START\n");
        for info: trackers {
            perf_tracker_print(info, *builder);
        }
        append(*builder, "(PERF) END\n");

        write_builder(*builder);
    }
} else {
    perf_tracker_print :: (interval: int) #expand {}
}

perf_tracker_print :: (info: TrackerInfo, builder: *String_Builder) {
    total: float64;
    count: int;
    for i: 0..info.times.count - 1 {
        if info.times[i] > 0 {
            total += info.times[i];
            count += 1;
        }
    }

    append(builder, "(PERF) ");
    append(builder, info.name);
    append(builder, ": ");
    append(builder, tprint("%", total / count));
    append(builder, "\n");
}

#scope_file

TrackerInfo :: struct {
    name: string;
    current_time: float64;
    times: [200] float64;
    next_index: int;
}

get_or_add_tracker :: ($name: string) -> *TrackerInfo {
    for *tracker: trackers {
        if tracker.name == name {
            return tracker;
        }
    }

    added := array_add(*trackers);
    added.name = name;
    return added;
}

trackers: [..] TrackerInfo;
print_index: int;

// trackers: Table(string, TrackerInfo);