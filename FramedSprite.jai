FramedSprite :: struct {
    using animated_sprite: AnimatedSprite;
    animations: [..] FramedAnimation; // oh well
    frame_f: float;
}

create_framed_sprite :: (sprite: AnimatedSprite) -> FramedSprite {
    framed: FramedSprite;
    framed.animated_sprite = sprite;

    return framed;
}

draw_sprite :: (framed: FramedSprite, position: Vector2) {
    // TODO don't do it this way?
    // TODO this doesnt allocate memory... right?
    new := framed;
    new.position = position;

    draw_sprite(new);
}

draw_sprite :: (framed: FramedSprite) {
    // calculate the frame
    draw_sprite(framed.animated_sprite);
}

add_animation :: (framed: *FramedSprite, name: string, start: int, end: int) {
    for anim: framed.animations {
        if anim.name == name {
            return;
        }
    }

    animation: FramedAnimation = ---;
    animation.name = name;
    animation.start = start;
    animation.end = end;

    array_add(*framed.animations, animation);
}

goto_animation :: (framed: *FramedSprite, name: string, frame: int) {
    animation, exists := find_animation(<< framed, name);
    if !exists {
        return;
    }

    frame_count := animation.end - animation.start + 1;
    framed.frame_f = cast(float) (frame % frame_count + animation.start);
    framed.frame = cast(int) framed.frame_f;
}

step_animation :: (framed: *FramedSprite, name: string) {
    step_animation(framed, name, 1.0);
}

step_animation :: (framed: *FramedSprite, name: string, frames: float) {
    animation, exists := find_animation(<< framed, name);
    if !exists {
        return;
    }

    frame_count := animation.end - animation.start + 1.0;
    frame := framed.frame_f - animation.start;
    if frame < 0 || frame >= frame_count {
        frame = 0;
    } else {
        frame += frames;
    }

    // why doesnt floating mod % mod exist?
    framed.frame_f = fmod(frame, frame_count) + animation.start;
    framed.frame = cast(int) framed.frame_f;
}

#scope_file

FramedAnimation :: struct {
    name: string;
    start: int;
    end: int;
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