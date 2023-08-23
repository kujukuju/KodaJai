
parallel_init :: () {
    if threads_initialized {
        return;
    }
    threads_initialized = true;

    for i: 0..threads.count - 1 {
        threads[i].data = New(ThreadData);

        thread_data := cast(*ThreadData) threads[i].data;
        // thread_data.index = i;
        init(*thread_data.run_semaphore);

        thread_init(*threads[i], thread_callback);
        thread_start(*threads[i]);
    }

    init(*pause_semaphore);
}

// x
parallel_for :: (start: int, end_exclusive: int, $callback: (i: int)) {
    inline parallel_for(start, end_exclusive, (i: int, a: u8) {callback(i);}, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A), a: A) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: u8) {callback(i, a);}, a, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B), a: A, b: B) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: u8) {callback(i, a, b);}, a, b, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C), a: A, b: B, c: C) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: u8) {callback(i, a, b, c);}, a, b, c, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D), a: A, b: B, c: C, d: D) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: u8) {callback(i, a, b, c, d);}, a, b, c, d, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E), a: A, b: B, c: C, d: D, e: E) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: u8) {callback(i, a, b, c, d, e);}, a, b, c, d, e, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F), a: A, b: B, c: C, d: D, e: E, f: F) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: u8) {callback(i, a, b, c, d, e, f);}, a, b, c, d, e, f, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G), a: A, b: B, c: C, d: D, e: E, f: F, g: G) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: u8) {callback(i, a, b, c, d, e, f, g);}, a, b, c, d, e, f, g, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: u8) {callback(i, a, b, c, d, e, f, g, h);}, a, b, c, d, e, f, g, h, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: u8) {callback(i, a, b, c, d, e, f, g, h, m);}, a, b, c, d, e, f, g, h, m, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M, n: $N), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: u8) {callback(i, a, b, c, d, e, f, g, h, m, n);}, a, b, c, d, e, f, g, h, m, n, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M, n: $N, o: $O), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: u8) {callback(i, a, b, c, d, e, f, g, h, m, n, o);}, a, b, c, d, e, f, g, h, m, n, o, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M, n: $N, o: $O, p: $P), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: u8) {callback(i, a, b, c, d, e, f, g, h, m, n, o, p);}, a, b, c, d, e, f, g, h, m, n, o, p, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M, n: $N, o: $O, p: $P, q: $Q), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: Q) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: Q, r: u8) {callback(i, a, b, c, d, e, f, g, h, m, n, o, p, q);}, a, b, c, d, e, f, g, h, m, n, o, p, q, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M, n: $N, o: $O, p: $P, q: $Q, r: $R), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: Q, r: R) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: Q, r: R, s: u8) {callback(i, a, b, c, d, e, f, g, h, m, n, o, p, q, r);}, a, b, c, d, e, f, g, h, m, n, o, p, q, r, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M, n: $N, o: $O, p: $P, q: $Q, r: $R, s: $S), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: Q, r: R, s: S) {
    inline parallel_for(start, end_exclusive, (i: int, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: Q, r: R, s: S, t: u8) {callback(i, a, b, c, d, e, f, g, h, m, n, o, p, q, r, s);}, a, b, c, d, e, f, g, h, m, n, o, p, q, r, s, 0);
}

parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, a: $A, b: $B, c: $C, d: $D, e: $E, f: $F, g: $G, h: $H, m: $M, n: $N, o: $O, p: $P, q: $Q, r: $R, s: $S, t: $T), a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, m: M, n: N, o: O, p: P, q: Q, r: R, s: S, t: T) {
    #if SINGLE_THREAD {
        for i: start..end_exclusive - 1 {
            callback(i, a, b, c, d, e, f, g, h, m, n, o, p, q, r, s, t);
        }
        return;
    }

    if !threads_initialized {
        parallel_init();
    }
    
    ParameterStruct :: struct {
        a: A;
        b: B;
        c: C;
        d: D;
        e: E;
        f: F;
        g: G;
        h: H;
        m: M;
        n: N;
        o: O;
        p: P;
        q: Q;
        r: R;
        s: S;
        t: T;
    }

    // stack stuff is fine because this function waits for the threads to finish before proceeding
    thread_baked_callback = (i: int) {
        casted_parameters := cast(*ParameterStruct) thread_parameter_data;
        callback(i, casted_parameters.a, casted_parameters.b, casted_parameters.c, casted_parameters.d, casted_parameters.e, casted_parameters.f, casted_parameters.g, casted_parameters.h, casted_parameters.m, casted_parameters.n, casted_parameters.o, casted_parameters.p, casted_parameters.q, casted_parameters.r, casted_parameters.s, casted_parameters.t);
    };

    thread_parameters: ParameterStruct;
    thread_parameters.a = a;
    thread_parameters.b = b;
    thread_parameters.c = c;
    thread_parameters.d = d;
    thread_parameters.e = e;
    thread_parameters.f = f;
    thread_parameters.g = g;
    thread_parameters.h = h;
    thread_parameters.m = m;
    thread_parameters.n = n;
    thread_parameters.o = o;
    thread_parameters.p = p;
    thread_parameters.q = q;
    thread_parameters.r = r;
    thread_parameters.s = s;
    thread_parameters.t = t;
    thread_parameter_data = *thread_parameters;

    finished_count = 0;

    increment_value := cast(int) ceil(cast(float) (end_exclusive - start) / threads.count);

    start_index := start;
    end_index_exclusive := start_index + increment_value;
    for thread_index: 0..threads.count - 1 {
        thread := threads[thread_index];
        thread_data := cast(*ThreadData) thread.data;
        thread_data.start_index = start_index;
        thread_data.end_index_exclusive = end_index_exclusive;

        signal(*thread_data.run_semaphore);

        start_index = end_index_exclusive;
        end_index_exclusive = min(start_index + increment_value, end_exclusive);
    }

    // pause until threads say ready
    wait_for(*pause_semaphore);
}

#scope_file

SINGLE_THREAD :: false;

ThreadData :: struct {
    run_semaphore: Semaphore;
    start_index: int;
    end_index_exclusive: int;
}

thread_callback :: (thread: *Thread) -> s64 {
    thread_data: *ThreadData = cast(*ThreadData) thread.data;

    while true {
        // wait for the thread to be ready
        wait_for(*thread_data.run_semaphore);

        for index: thread_data.start_index..thread_data.end_index_exclusive - 1 {
            thread_baked_callback(index);
        }
        
        old_finished_count := atomic_add(*finished_count, 1);
        if old_finished_count == threads.count - 1 {
            signal(*pause_semaphore);
        }
    }

    return 0;
}

pause_semaphore: Semaphore;
finished_count: int;

core_count :: #run get_number_of_processors();
thread_count :: core_count;
threads: [thread_count] Thread;
threads_initialized: bool;

thread_baked_callback: #type (i: int);
thread_parameter_data: *void;

#import "Basic";
#import "Thread";
#import "Atomics";
#import "System";