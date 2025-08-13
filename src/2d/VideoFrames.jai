
VideoFrames :: struct {
    width: int;
    height: int;
    frames: [] [] u8;
    buffer: [] u8;
    frame: int;
}

generate_video :: (path: string) -> VideoFrames {
    return .{};
}

initialize_frame :: (video_frame: *VideoFrames, rgb: [] u8) {
    byte_count := video_frame.width * video_frame.height * 3;

    if video_frame.buffer.count != byte_count {
        array_free(video_frame.buffer);
        video_frame.buffer = NewArray(byte_count, u8);
    }

    video_frame.frame = 0;
}

get_frame_and_increment :: (video_frame: *VideoFrames, rgb: [] u8) {
    assert(rgb.count == video_frame.width * video_frame.height * 3);
    assert(video_frame.buffer.count == rgb.count);

    if video_frame.frame >= video_frame.frames.count {
        return;
    }

    if video_frame.frame == 0 {
        uncompress_block(video_frame.frames[0], rgb);
    } else {
        memcpy(video_frame.buffer.data, rgb.data, rgb.count);
        uncompress_block(video_frame.buffer, video_frame.frames[video_frame.frame], rgb);
    }
}

#scope_file

compress_block :: (current_uncompressed: [] u8, out: *[..] u8) {
    // do stuff
}

compress_block :: (last_uncompressed: [] u8, current_uncompressed: [] u8, out: *[..] u8) {
    // do stuff
}

uncompress_block :: (current_compressed: [] u8, out: [] u8) {
    // do stuff
}

uncompress_block :: (last_uncompressed: [] u8, current_compressed: [] u8, out: [] u8) {
    // do stuff
}
