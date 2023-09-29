
// parallel_init :: () {
//     if threads_initialized {
//         return;
//     }
//     threads_initialized = true;

//     for i: 0..threads.count - 1 {
//         threads[i].data = New(ThreadData);

//         thread_data := cast(*ThreadData) threads[i].data;
//         // thread_data.index = i;
//         init(*thread_data.run_semaphore);

//         thread_init(*threads[i], thread_callback);
//         thread_start(*threads[i]);
//     }

//     init(*pause_semaphore);
// }

// parallel_for :: (start: int, end_exclusive: int, $callback: (i: int)) {
//     #if SINGLE_THREAD {
//         for i: start..end_exclusive - 1 {
//             callback(i);
//         }
//         return;
//     }

//     if !threads_initialized {
//         parallel_init();
//     }

//     // stack stuff is fine because this function waits for the threads to finish before proceeding
//     thread_baked_callback = callback;

//     finished_count = 0;

//     increment_value := cast(int) ceil(cast(float) (end_exclusive - start) / threads.count);

//     start_index := start;
//     end_index_exclusive := start_index + increment_value;
//     for thread_index: 0..threads.count - 1 {
//         thread := threads[thread_index];
//         thread_data := cast(*ThreadData) thread.data;
//         thread_data.start_index = start_index;
//         thread_data.end_index_exclusive = end_index_exclusive;

//         signal(*thread_data.run_semaphore);

//         start_index = end_index_exclusive;
//         end_index_exclusive = min(start_index + increment_value, end_exclusive);
//     }

//     // pause until threads say ready
//     wait_for(*pause_semaphore);
// }

// #scope_file

// SINGLE_THREAD :: false;

// ThreadData :: struct {
//     run_semaphore: Semaphore;
//     start_index: int;
//     end_index_exclusive: int;
// }

// thread_callback :: (thread: *Thread) -> s64 {
//     thread_data: *ThreadData = cast(*ThreadData) thread.data;

//     while true {
//         // wait for the thread to be ready
//         wait_for(*thread_data.run_semaphore);

//         for index: thread_data.start_index..thread_data.end_index_exclusive - 1 {
//             thread_baked_callback(index);
//         }
        
//         old_finished_count := atomic_add(*finished_count, 1);
//         if old_finished_count == threads.count - 1 {
//             signal(*pause_semaphore);
//         }
//     }

//     return 0;
// }

// pause_semaphore: Semaphore;
// finished_count: int;

// core_count :: #run get_number_of_processors();
// thread_count :: core_count;
// threads: [thread_count] Thread;
// threads_initialized: bool;

// thread_baked_callback: #type (i: int);

// #import "Basic";
// #import "Thread";
// #import "Atomics";
// #import "System";