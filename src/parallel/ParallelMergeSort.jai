
parallel_merge_sort_initialize :: (thread_count: int = 0) {
    if merge_sort_initialized {
        return;
    }
    merge_sort_initialized = true;

    if !thread_count {
        thread_count = get_number_of_processors();
    }
    thread_count = next_power_of_two(thread_count);
    work_count = thread_count * 2 - 1;

    semaphores = NewArray(thread_count, Semaphore);
    threads = NewArray(thread_count, Thread);

    division_count = next_power_of_two(thread_count);
    assert(thread_count == division_count);

    work_queue = NewArray(division_count * 2 - 1, Work);
    for i: 0..work_queue.count - 1 {
        row, index := get_row_and_index(i);

        parent_index: int;
        if row > 0 {
            prow, pindex := get_parent(row, index);
            parent_index = get_flat_index(prow, pindex);
        } else {
            parent_index = -1;
        }

        work_queue[i] = Work.{
            sorted_children = i >= division_count,
            row = row,
            index = index,
            parent_index = parent_index,
        };
    }
    
    work_dependency_finish_count = NewArray(division_count * 2 - 1, u8);

    for i: 0..semaphores.count - 1 {
        init(*semaphores[i]);
    }

    init(*finished_semaphore);

    for i: 0..threads.count - 1 {
        threads[i].data = cast(*void) i;

        thread_init(*threads[i], merge_sort_work);
        thread_start(*threads[i]);
    }
}

get_indices :: (row: int, index: int) -> int, int {
    divisions := intpow(2, row);
    return index * input_count / divisions, (index + 1) * input_count / divisions;
}

get_child_indices :: (row: int, index: int) -> int, int, int, int {
    left_start, left_end := get_indices(row + 1, index * 2);
    right_start, right_end := get_indices(row + 1, index * 2 + 1);

    return left_start, left_end, right_start, right_end;
}

get_row_and_index :: (flat_index: int) -> int, int {
    index := work_count - flat_index - 1;
    
    row := 0;
    while intpow(2, row) * 2 - 1 <= index {
        row += 1;
    }

    return row, index - intpow(2, row) + 1;
}

get_flat_index :: (row: int, index: int) -> int {
    return work_count - index - intpow(2, row);
}

intpow :: (a: int, b: int) -> int {
    r := 1;
    for i: 0..b - 1 {
        r *= a;
    }
    return r;
}

get_parent :: (row: int, index: int) -> row: int, index: int {
    parent_index := index / 2;
    parent_row := row - 1;
    return parent_row, parent_index;
}

parallel_merge_sort :: (input: [] $T, $compare: (a: T, b: T) -> $N) {
    if !merge_sort_initialized {
        parallel_merge_sort_initialize();
    }

    if input.count < division_count * 64 {
        quick_sort(input, compare);
        return;
    }

    for i: 0..work_dependency_finish_count.count - 1 {
        work_dependency_finish_count[i] = 0;
    }

    raw_input_data = input.data;
    input_count = input.count;

    buffer_size := next_power_of_two(input.count * size_of(T));
    array_reserve(*merge_buffer, buffer_size);

    baked_callback :: (index: int) {
        input_data := cast(*T) raw_input_data;
        work_index := index;

        merge_buffer_data := cast(*T) merge_buffer.data;

        while true {
            work := work_queue[work_index];

            if work.sorted_children {
                start_left, end_left, start_right, end_right := get_child_indices(work.row, work.index);
                assert(end_left == start_right);

                input_left: [] T;
                input_left.data = input_data + start_left;
                input_left.count = end_left - start_left;

                input_right: [] T;
                input_right.data = input_data + start_right;
                input_right.count = end_right - start_right;
                
                buffer: [] T;
                buffer.data = merge_buffer_data + start_left;
                buffer.count = end_right - start_left;

                left_index := 0;
                right_index := 0;
                for i: 0..buffer.count - 1 {
                    if left_index < input_left.count && right_index < input_right.count {
                        if compare(input_left[left_index], input_right[right_index]) <= 0 {
                            buffer[i] = input_left[left_index];
                            left_index += 1;
                        } else {
                            buffer[i] = input_right[right_index];
                            right_index += 1;
                        }
                    } else if left_index < input_left.count {
                        buffer[i] = input_left[left_index];
                        left_index += 1;
                    } else if right_index < input_right.count {
                        buffer[i] = input_right[right_index];
                        right_index += 1;
                    } else {
                        assert(false, "There's nothing left to write!\n");
                    }
                }

                memcpy(input_left.data, buffer.data, buffer.count * size_of(T));
            } else {
                start, end := get_indices(work.row, work.index);
                // just sort this chunk because there are no dependencies so it's the very first chunk
                segment_view: [] T;
                segment_view.data = input_data + start;
                segment_view.count = end - start;

                quick_sort(segment_view, compare);
            }

            parent_index := work.parent_index;
            if parent_index >= 0 {
                old_finished_count := atomic_add(*work_dependency_finish_count[parent_index], 1);
                if old_finished_count == 0 {
                    // this was the first thread to finish, so we stop work
                    return;
                }

                work_index = parent_index;
            } else {
                signal(*finished_semaphore);
                return;
            }
        }
    }

    work_callback = baked_callback;

    for i: 0..semaphores.count - 1 {
        signal(*semaphores[i]);
    }

    wait_for(*finished_semaphore);
}

#scope_file

Work :: struct {
    sorted_children: bool;
    row: int;
    index: int;
    parent_index: int;
}

merge_sort_work :: (thread: *Thread) -> s64 {
    index := cast(int) thread.data;

    while true {
        wait_for(*semaphores[index]);

        work_callback(index);
    }

    return 0;
}

next_power_of_two :: (i: int) -> int {
    val := 1;
    while val < i {
        val += val;
    }
    return val;
}

merge_sort_initialized: bool;

division_count: int;
threads: [] Thread;
semaphores: [] Semaphore;

work_queue: [] Work;
work_dependency_finish_count: [] u8;
work_count: int;

merge_buffer: [..] u8;

finished_semaphore: Semaphore;

raw_input_data: *void;
input_count: int;

work_callback: #type (index: int);
