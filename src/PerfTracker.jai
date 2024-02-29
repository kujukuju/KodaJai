
PERF_TRACKER_ENABLED :: true;

// loop
// (enter)
// -start loop cpu
// -(defer) stop loop cpu
// -stop PARENT gpu
// -(defer) start PARENT gpu
// -start loop gpu
// -(defer) stop loop gpu
// -set PARENT gpu queries
// -(defer) pop PARENT gpu queries
//
//     logic
//     (enter)
//     -start logic cpu
//     -(defer) stop logic cpu
//     -stop PARENT gpu
//     -(defer) start PARENT gpu
//     -start logic gpu
//     -(defer) stop logic gpu
//     -set PARENT gpu queries
//     -(defer) pop PARENT gpu queries
//
//     render
//     (enter)
//     -start render cpu
//     -(defer) stop render cpu
//     -stop PARENT gpu
//     -(defer) start PARENT gpu
//     -start render gpu
//     -(defer) stop render gpu
//     -set PARENT gpu queries
//     -(defer) pop PARENT gpu queries
//
//         draw
//         (enter)
//         -start draw cpu
//         -(defer) stop draw cpu
//         -stop PARENT gpu
//         -(defer) start PARENT gpu
//         -start draw gpu
//         -(defer) stop draw gpu
//         -set PARENT gpu queries
//         -(defer) pop PARENT gpu queries

#if PERF_TRACKER_ENABLED {
    perf_track :: ($name: string, $gpu: bool = true) #expand {
        #run tracker_allocated += 1;
        
        tracker_info := get_or_add_tracker(name);
        assert(!tracker_info.currently_tracking, tprint("Tried to track the same call inside itself. %\n", name));
        tracker_info.currently_tracking = true;
        tracker_info.indent = tracker_indent;
        tracker_indent += 1;

        // start cpu
        // defer end cpu
        tracker_start_time := seconds_since_init();
        `defer {
            tracker_info := get_or_add_tracker(name);
            tracker_info.currently_tracking = false;
            tracker_indent -= 1;

            tracker_final_time := seconds_since_init();
            tracker_info.cumulative_cpu_time += (tracker_final_time - tracker_start_time) * 1000.0;
        }

        #if gpu {
            // start stop parent gpu
            parent_gpu_name := tracker_current_gpu_name;
            if parent_gpu_name {
                glEndQuery(GL_TIME_ELAPSED);
            }
            `defer {
                if parent_gpu_name {
                    parent_tracker_info := get_or_add_tracker(parent_gpu_name);
                    gpu_query: u32;
                    glGenQueries(1, *gpu_query);
                    glBeginQuery(GL_TIME_ELAPSED, gpu_query);
                    array_add(*parent_tracker_info.gpu_queries, gpu_query);
                }
            }

            // start stop gpu
            gpu_query: u32;
            glGenQueries(1, *gpu_query);
            glBeginQuery(GL_TIME_ELAPSED, gpu_query);
            array_add(*tracker_info.gpu_queries, gpu_query);
            `defer {
                glEndQuery(GL_TIME_ELAPSED);
            }

            // push pop parent gpu queries
            tracker_current_gpu_name = name;
            `defer tracker_current_gpu_name = parent_gpu_name;
        }
    }

    perf_tracker_finish :: (print_interval: int, maximum_history: int = 0, clear: bool = true) {
        currently_tracking := !!tracker_current_gpu_name;
        for tracker: trackers {
            currently_tracking = currently_tracking || tracker.currently_tracking;
        }
        assert(!currently_tracking, "You cannot call tracker finish until you've finished all your tracker calls. You might have to defer your tracker finish call.\n");

        for *tracker: trackers {
            tracker.visited = false;

            array_add(*tracker.cpu_times, tracker.cumulative_cpu_time);
            tracker.cumulative_cpu_time = 0;

            if tracker.gpu_queries.count > 0 {
                cumulative: float64;
                for query_index: 0..tracker.gpu_queries.count - 1 {
                    elapsed: u64;
                    glGetQueryObjectui64v(tracker.gpu_queries[query_index], GL_QUERY_RESULT, *elapsed);
                    glDeleteQueries(1, *tracker.gpu_queries[query_index]);
                    tracker.gpu_queries[query_index] = 0;

                    cumulative += elapsed / 1000000.0;
                }

                tracker.gpu_queries.count = 0;

                array_add(*tracker.gpu_times, cumulative);
            }
        }

        if maximum_history {
            for *tracker: trackers {
                if tracker.cpu_times.count > maximum_history {
                    over_count := tracker.cpu_times.count - maximum_history;
                    for i: 0..maximum_history - 1 {
                        tracker.cpu_times[i] = tracker.cpu_times[i + over_count];
                    }
                    tracker.cpu_times.count = maximum_history;
                }

                if tracker.gpu_times.count > maximum_history {
                    over_count := tracker.gpu_times.count - maximum_history;
                    for i: 0..maximum_history - 1 {
                        tracker.gpu_times[i] = tracker.gpu_times[i + over_count];
                    }
                    tracker.gpu_times.count = maximum_history;
                }
            }
        }

        tracker_print_index += 1;
        if tracker_print_index % print_interval != 0 {
            return;
        }

        for *tracker: trackers {
            cpu_total: float64;
            gpu_total: float64;
            for cpu_time: tracker.cpu_times {
                cpu_total += cpu_time;
            }
            for gpu_time: tracker.gpu_times {
                gpu_total += gpu_time;
            }
            tracker.average_cpu_time = cpu_total / max(tracker.cpu_times.count, 1);
            tracker.average_gpu_time = gpu_total / max(tracker.gpu_times.count, 1);
            
            tracker.cpu_times.count = 0;
            tracker.gpu_times.count = 0;
        }

        for i: 0..trackers.count - 1 {
            for a: i + 1..trackers.count - 1 {
                if trackers[a].indent > trackers[i].indent {
                    // if it's a child we will add it to the parent time
                    trackers[i].average_gpu_time += trackers[a].average_gpu_time;
                } else {
                    break;
                }
            }
        }

        builder: String_Builder;
        append(*builder, "\nCPU performance section:\n");
        for tracker_index: 0..trackers.count - 1 {
            perf_tracker_finish(tracker_index, *builder, false);
        }
        append(*builder, "\nGPU performance section:\n");
        for tracker_index: 0..trackers.count - 1 {
            perf_tracker_finish(tracker_index, *builder, true);
        }
        append(*builder, "\n");

        write_builder(*builder);

        if clear {
            for tracker: trackers {
                array_free(tracker.gpu_queries);
                array_free(tracker.cpu_times);
                array_free(tracker.gpu_times);
            }
            trackers.count = 0;
        }
    }

    perf_tracker_reset :: () {
        trackers.count = 0;
    }
} else {
    perf_track :: ($name: string, $gpu: bool = false) #expand {}

    perf_tracker_finish :: (interval: int, gpu_wait: bool = true, clear: bool = true) #expand {}

    perf_tracker_reset :: () #expand {}
}

#scope_file

TrackerInfo :: struct {
    name: string;
    cumulative_cpu_time: float64;
    // cpu_start: float64;
    gpu_queries: [..] u32;
    cpu_times: [..] float64;
    gpu_times: [..] float64;
    average_cpu_time: float64;
    average_gpu_time: float64;
    indent: int;
    visited: bool;
    currently_tracking: bool;
}

get_or_add_tracker :: (name: string) -> *TrackerInfo {
    unvisited_index := trackers.count;
    i := 0;
    while i < trackers.count {
        defer i += 1;

        if trackers[i].name == name {
            if !trackers[i].visited {
                trackers[i].visited = true;

                if i > unvisited_index {
                    tracker := trackers[i];
                    array_ordered_remove_by_index(*trackers, i);
                    array_insert_at(*trackers, tracker, unvisited_index);

                    return *trackers[unvisited_index];
                }
            }

            return *trackers[i];
        }

        if !trackers[i].visited {
            unvisited_index = min(unvisited_index, i);
        }
    }

    // we need to do it this way to be sure trackers are always valid memory...
    // or we could use a block allocator or something
    if !trackers.allocated {
        array_reserve(*trackers, tracker_allocated);
    }

    trackers.count += 1;
    assert(trackers.count <= trackers.allocated, "Something went wrong... More trackers than allocated.\n");

    tracker := *trackers[trackers.count - 1];
    tracker.* = TrackerInfo.{};
    tracker.name = name;
    tracker.visited = true;
    return tracker;
}

perf_tracker_finish :: (tracker_index: int, builder: *String_Builder, gpu: bool) {
    tracker := trackers[tracker_index];

    average_time := ifx gpu then tracker.average_gpu_time else tracker.average_cpu_time;

    space_line := "  ";
    vertical_line := "│ ";
    horizontal_line := "└─";
    continuation_line := "├─";

    tracker_continue_depths.count = 0;
    memset(tracker_continue_depths.data, 0, tracker_continue_depths.allocated * size_of(bool));

    // this marks where every next indentation might be so it can be drawn to
    for next_tracker_index: tracker_index + 1..trackers.count - 1 {
        next_indent := trackers[next_tracker_index].indent;
        
        if next_indent <= 0 {
            continue;
        }
        next_indent -= 1;

        if tracker_continue_depths.count <= next_indent {
            if tracker_continue_depths.allocated <= next_indent {
                array_reserve(*tracker_continue_depths, next_indent + 1);
            }
            
            tracker_continue_depths.count = next_indent + 1;
        }

        tracker_continue_depths[next_indent] = true;
    }

    // if this indentation immediately ends, we don't want to continue drawing
    if tracker_index < trackers.count - 1 {
        next_indent := trackers[tracker_index + 1].indent;

        // im totally guessing here but it's probably right
        if next_indent < tracker.indent {
            for indent: next_indent..tracker.indent - 1 {
                tracker_continue_depths[indent] = false;
            }
        }
    }

    current_indent := 0;
    if current_indent < tracker.indent {
        while current_indent < tracker.indent - 1 {
            defer current_indent += 1;

            if tracker_continue_depths[current_indent] {
                append(builder, vertical_line.data, vertical_line.count);
            } else {
                append(builder, space_line.data, space_line.count);
            }
        }

        if tracker_continue_depths[current_indent] {
            append(builder, continuation_line.data, continuation_line.count);
        } else {
            append(builder, horizontal_line.data, horizontal_line.count);
        }
    }

    append(builder, tracker.name);
    append(builder, ": ");
    append(builder, tprint("%", average_time));
    append(builder, "\n");
}

trackers: [..] TrackerInfo;
tracker_indent: int;
tracker_print_index: int;
tracker_continue_depths: [..] bool;
tracker_has_gpu_query: bool;
tracker_current_gpu_name: string;

#no_reset tracker_allocated: int;