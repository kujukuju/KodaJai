FramedSprite :: struct {
    using animated_sprite: AnimatedSprite;
    animations: [..] FramedAnimation; // oh well
    frame_f: float;
    finished: bool;
}

create_framed_sprite :: (sprite: AnimatedSprite) -> FramedSprite {
    framed: FramedSprite;
    framed.animated_sprite = sprite;

    return framed;
}

draw :: (framed: FramedSprite, position: Vector2) {
    // TODO don't do it this way?
    // TODO this doesnt allocate memory... right?
    new := framed;
    new.position = position;

    draw(new);
}

draw :: (framed: FramedSprite) {
    // calculate the frame
    draw(framed.animated_sprite);
}

add_animation :: (framed: *FramedSprite, name: string, start: int, end: int, loop: bool = true) {
    for anim: framed.animations {
        if anim.name == name {
            return;
        }
    }

    animation: FramedAnimation = ---;
    animation.name = name;
    animation.start = start;
    animation.end = end;
    animation.loop = loop;

    array_add(*framed.animations, animation);
}

goto_animation :: (framed: *FramedSprite, name: string, frame: int) {
    animation, exists := find_animation(framed.*, name);
    if !exists {
        return;
    }

    frame_count := animation.end - animation.start + 1;
    if animation.loop {
        framed.frame_f = cast(float) (frame % frame_count + animation.start);
        framed.frame = cast(int) framed.frame_f;
        framed.finished = false;
    } else {
        framed.frame_f = cast(float) min(frame, frame_count) + animation.start;
        framed.frame = min(cast(int) framed.frame_f, animation.end);
        framed.finished = framed.frame_f == cast(float) frame_count + animation.start;
    }
}

step_animation :: (framed: *FramedSprite, name: string) {
    step_animation(framed, name, 1.0);
}

step_animation :: (framed: *FramedSprite, name: string, frames: float) {
    animation, exists := find_animation(framed.*, name);
    if !exists {
        return;
    }

    if framed.frame < animation.start || framed.frame > animation.end {
        framed.frame = animation.start;
        // I could subtract frames from here so that the first frame starts at 0
        // but I think that leads to the first frame being played longer?
        framed.frame_f = cast(float) animation.start;
    }

    frame_count := animation.end - animation.start + 1.0;
    frame := framed.frame_f - animation.start;

    frame += frames;

    // why doesnt floating mod % mod exist?
    // TODO min of this and start + count - 1 or something
    if animation.loop {
        framed.frame_f = fmod_cycling(frame, frame_count) + animation.start;
        framed.finished = false;
    } else {
        framed.frame_f = min(frame, frame_count) + animation.start;
        // we have to check this way because its only finished once the last frame has fully been played
        framed.finished = framed.frame_f == frame_count + animation.start;
    }

    framed.frame = cast(int) framed.frame_f;
    if !animation.loop {
        framed.frame = min(framed.frame, animation.end);
    }
    print("frame is %\n", framed.frame);
}

get_current_animation_name :: (framed: FramedSprite) -> string {
    for anim: framed.animations {
        if framed.frame >= anim.start && framed.frame <= anim.end {
            return anim.name;
        }
    }

    return "";
}

is_animation_finished :: (framed: FramedSprite) -> bool {
    return framed.finished;
}

#scope_file

FramedAnimation :: struct {
    name: string;
    start: int;
    end: int;
    loop: bool;
}

find_animation :: (framed: FramedSprite, name: string) -> FramedAnimation, bool {
    for anim: framed.animations {
        if anim.name == name {
            return anim, true;
        }
    }

    return .{}, false;
}

#import "Math";