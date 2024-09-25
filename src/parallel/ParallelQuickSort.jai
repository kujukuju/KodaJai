#if WASM {

    init_quick_sort :: (thread_count: s64) {

    }

    quick_sort_threaded :: (data: [] DepthEntry) {
        // TODO wasm might be backwards
        quick_sort(data, (a: DepthEntry, b: DepthEntry) -> s32 {
            return cast(s32) sign(b.depth - a.depth);
        });
    }

} else {

    init_quick_sort :: (thread_count: s64) {
        init(*qs_task_mutex);
        init(*qs_work_mutex);
        init(*qs_work_available);
        init(*qs_work_done);

        array_reserve(*qs_threads, thread_count);
        qs_threads.count = thread_count;
        for 0..qs_threads.count-1 {
            thread_init(*qs_threads[it], quick_sort_callback);
            thread_start(*qs_threads[it]);
        }
    }

    quick_sort_draws :: (a: *DepthEntry, n: s64) {
        if n < 2 return;

        p := a[n / 2];

        i := 0;
        j := n-1;

        while true {
            while a[i].depth < p.depth     { i += 1; }
            while p.depth    < a[j].depth  { j -= 1; }
            if i >= j  break;

            a[i], a[j] = a[j], a[i];
            i += 1;
            j -= 1;
        }

        quick_sort_draws(a, i);
        quick_sort_draws(a + i, n - i);
    }

    quick_sort_partition :: (a: [] DepthEntry) -> [] DepthEntry, [] DepthEntry {
        p := a[a.count / 2];

        i := 0;
        j := a.count-1;

        while true {
            while a[i].depth < p.depth     { i += 1; }
            while p.depth    < a[j].depth  { j -= 1; }
            if i >= j  break;

            a[i], a[j] = a[j], a[i];
            i += 1;
            j -= 1;
        }

        left  := a;
        left.count = i;
        right := a;
        right.data  += i;
        right.count -= i;
        return left, right;
    }

    quick_sort_threaded :: (data: [] DepthEntry) {
        if data.count < Quick_Sort_Minimum {
            quick_sort_draws(data.data, data.count);
            return;
        }

        #if QS_Print_Debug {
            print("================================\n");
            print("========== SORT BEGIN ==========\n");
            print("================================\n");
        }

        qs_tasks_remaining = 0;
        left, right := quick_sort_partition(data);

        quick_sort_add_task(left,  0);
        quick_sort_add_task(right, 0);

        wait_for(*qs_work_done);
    }

    quick_sort_task :: (data: [] DepthEntry, depth: s32) {
        defer {
            if atomic_decrement(*qs_tasks_remaining)  signal(*qs_work_done);
        }
        if data.count < Quick_Sort_Minimum {
            if data.count < 2  return;
            quick_sort_draws(data.data, data.count);
            return;
        }

        left, right := quick_sort_partition(data);

        if depth < Quick_Max_Depth {
            if atomic_read(*qs_tasks_remaining) < qs_threads.count {
                quick_sort_add_task(left,  depth + 1);
                quick_sort_add_task(right, depth + 1);
                return;
            };
        }

        quick_sort_draws(left.data,  left.count);
        quick_sort_draws(right.data, right.count);
    }

    quick_sort_add_task :: (data: [] DepthEntry, depth: s32) {
        atomic_increment(*qs_tasks_remaining);
        #if QS_Print_Debug {
            info(
                "queued task: %(%) at depth %",
                FormatInt.{value=cast(s64)data.data, base=16},
                FormatInt.{value=data.count},
                FormatInt.{value=depth},
            );
        }
        lock(*qs_task_mutex);
        array_add(*qs_tasks, .{data, depth});
        signal(*qs_work_available);
        unlock(*qs_task_mutex);
    }

    quick_sort_get_task :: (thread: *Thread) -> QS_Task, bool {
        task: QS_Task;

        lock(*qs_task_mutex);
        defer unlock(*qs_task_mutex);
        if qs_tasks.count > 0 {
            task = qs_tasks[0];
            array_unordered_remove_by_index(*qs_tasks, 0);
            return task, true;
        }
        return task, false;
    }

    quick_sort_callback :: (thread: *Thread) -> s64 {
        context.print_style = .{};
        while true {
            wait_for(*qs_work_available);
            data, found := quick_sort_get_task(thread);
            if !found  continue;
            #if QS_Print_Debug {
                info(
                    "% took task: %(%) at depth %", found,
                    FormatInt.{value=cast(s64)data.draw_calls.data, base=16},
                    FormatInt.{value=data.draw_calls.count},
                    FormatInt.{value=data.depth},
                );
            }
            quick_sort_task(data.draw_calls, data.depth);
        }
        return 0;
    }

    #scope_file

    #import "Thread";
    #import "System";
    #import "Atomics";
    #import "System";

    Quick_Max_Depth    :: 4;
    Quick_Sort_Minimum :: 128;
    QS_Print_Debug     :: false;

    // this is hard to make generic

    QS_Task :: struct {
        draw_calls: [] DepthEntry;
        depth: s32;
    }

    qs_tasks_remaining: s64;
    qs_threads: [..] Thread;
    qs_task_mutex: Mutex;
    qs_tasks:   [..] QS_Task;
    qs_work_mutex: Mutex;
    qs_work_available: Semaphore;
    qs_work_done: Semaphore;

}
