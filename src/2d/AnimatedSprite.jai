// loads a basic animated sprite in row first order, where each cell is the same size
// later might add a way to load animated sprites that are packed

AnimatedSprite :: struct {
    using #as sprite: Sprite;
    columns: int;
    frame_count: int;
    frame: int;
}

SpriteAnimation :: struct {
    name: string;
    start: int;
    count: int;
}

create_animated_sprite :: (sprite: Sprite, columns: int, frame_count: int, frame: int = 0) -> AnimatedSprite {
    animated: AnimatedSprite;
    animated.sprite = sprite;
    animated.columns = columns;
    animated.frame_count = frame_count;
    animated.frame = frame;

    return animated;
}

draw :: (sprite: AnimatedSprite, position: Vector2) {
    // TODO don't do it this way?
    new := sprite;
    new.position = position;

    draw(new);
}

draw :: (sprite: AnimatedSprite) {
    // TODO dont do it this way
    new := sprite;

    rows := (new.frame_count - 1) / new.columns + 1;

    row := new.frame / new.columns;
    column := new.frame % new.columns;

    new.texture_frame.x = cast(float) column / new.columns;
    new.texture_frame.y = cast(float) row / rows;
    new.texture_frame.z = 1.0 / new.columns;
    new.texture_frame.w = 1.0 / rows;

    draw(new.sprite);
}

#scope_file
#import "Math";