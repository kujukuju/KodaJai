
VideoFrames :: struct {
    width: int;
    height: int;
    frames: [] u8;
    frame_count: int;
    buffer: [] u8; @serializer_skip
    uncompressed: [2] [] u8; @serializer_skip
    uncompressed_index: int; @serializer_skip
    frame: int; @serializer_skip
    decoder: *LZ4_streamDecode_t; @serializer_skip
}

destroy_allocated :: (video_frames: VideoFrames) {
    for uncompressed {
        if it.count {
            array_free(it);
        }
    }
    if video_frames.decoder {
        LZ4_freeStreamDecode(video_frames.decoder);
    }
}

generate_video :: (path: string) -> VideoFrames {
    #import "Process";

    _, width_height_string := run_command("ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", path, capture_and_return_output = true,, temp);
    width_height := split(width_height_string, "x",, temp);
    assert(width_height.count == 2);
    width_string := width_height[0];
    height_string := width_height[1];

    width := string_to_int(width_string);
    assert(width > 0);
    height := string_to_int(height_string);
    assert(height > 0);
    frame_byte_count := width * height * 3;

    print("Reading video with dimensions %x%.\n", width, height);

    raw_file := tprint("%.%.bytes", path, get_unix_time());

    result := run_command("ffmpeg", "-v", "error", "-i", path, "-map", "0:v:0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-vsync", "0", raw_file,, temp);
    defer file_delete(raw_file);

    file := file_open(raw_file);
    defer file_close(*file);

    file_size := file_length(file);
    frame_count := file_size / frame_byte_count;
    print("Reading % video frames.\n", frame_count);

    current_frames: [2] [] u8;
    current_frames[0] = NewArray(frame_byte_count, u8,, temp);
    current_frames[1] = NewArray(frame_byte_count, u8,, temp);
    current_frame_index: int;

    frame_delta := NewArray(frame_byte_count, u8,, temp);

    compressed: [..] u8;

    encoder := LZ4_createStreamHC();
    defer LZ4_freeStreamHC(encoder);

    for i: 0..frame_count - 1 {
        current_frame := current_frames[current_frame_index];
        current_frame_index = (current_frame_index + 1) % current_frames.count;

        success, total_read := file_read(file, current_frame.data, frame_byte_count);
        assert(success);
        assert(total_read == frame_byte_count);

        last_frame := current_frames[current_frame_index];

        for i: 0..current_frame.count - 1 {
            frame_delta[i] = current_frame[i] ^ last_frame[i];
        }

        compress_block(encoder, frame_delta, *compressed);
    }

    print("Compressed video from % bytes into % bytes.\n", file_size, compressed.count);

    video_frames: VideoFrames;
    video_frames.width = width;
    video_frames.height = height;
    video_frames.frames = compressed;
    video_frames.frame_count = frame_count;

    return video_frames;
}

get_frame_and_increment :: (video_frame: *VideoFrames) -> [] u8 {
    if video_frame.frame >= video_frame.frames.count {
        return video_frame.uncompressed[video_frame.uncompressed_index];
    }

    if !video_frame.decoder {
        video_frame.decoder = LZ4_createStreamDecode();

        video_frame.buffer = NewArray(video_frame.width * video_frame.height * 3, u8);

        for i: 0..video_frame.uncompressed.count - 1 {
            video_frame.uncompressed[i] = NewArray(video_frame.width * video_frame.height * 3, u8);
        }
    }

    if video_frame.frame == 0 {
        memset(video_frame.buffer.data, 0, video_frame.buffer.count);
        for i: 0..video_frame.uncompressed.count - 1 {
            memset(video_frame.uncompressed[i].data, 0, video_frame.uncompressed[i].count);
        }
    }

    out_frame := video_frame.uncompressed[video_frame.uncompressed_index];
    video_frame.uncompressed_index = (video_frame.uncompressed_index + 1) % video_frame.uncompressed.count;

    last_frame := video_frame.uncompressed[video_frame.uncompressed_index];

    uncompress_block(video_frame.decoder, video_frame.frames[video_frame.frame], out_frame);
    video_frame.frame += 1;

    for i: 0..out_frame.count - 1 {
        out_frame[i] = out_frame[i] ^ last_frame[i];
    }
}

#scope_file

compress_block :: (encoder: *LZ4_streamHC_t, uncompressed: [] u8, out: *[..] u8) {
    required_size := LZ4_compressBound(cast(s32) uncompressed.count);
    array_reserve(out, out.count + required_size);

    written  := LZ4_compress_HC_continue(encoder, uncompressed.data, out.data + out.count, cast(s32) uncompressed.count, cast(s32) required_size);
    assert(written > 0 && written <= required_size);
    out.count += written;
}

uncompress_block :: (decoder: *LZ4_streamDecode_t, compressed: [] u8, out: [] u8) {
    written := LZ4_decompress_safe_continue(decoder, compressed.data, out.data, cast(s32) compressed.count, cast(s32) out.count);
    assert(written > 0 && written <= out.count);
    assert(written == out.count);
}

get_unix_time :: () -> u64 #c_call {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";

        filetime: Windows.FILETIME;
        Windows.GetSystemTimePreciseAsFileTime(*filetime);

        UNIX_TIME_START: s64 : 0x019DB1DED53E8000;
        TICKS_PER_SECOND: s64 : 10000;

        li: Windows.LARGE_INTEGER;
        li.LowPart = xx filetime.dwLowDateTime;
        li.HighPart = xx filetime.dwHighDateTime;

        return cast(u64) ((li.QuadPart - UNIX_TIME_START) / TICKS_PER_SECOND);
    } else #if OS == .LINUX {
        POSIX :: #import "POSIX";

        t: POSIX.timespec;
        POSIX.clock_gettime(POSIX.clockid_t.CLOCK_REALTIME, *t);
        micros: s64 = t.tv_sec * 1000000;
        /* Add full microseconds */
        micros += t.tv_nsec / 1000;

        return cast(u64) micros / 1000;
    } else {
        return 0;
    }
}
