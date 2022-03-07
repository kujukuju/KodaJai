enum_count :: ($t: Type) -> s64 {
    return enum_highest_value(t) + 1;
}

get_string :: (s: *u8) -> string {
    count := 0;
    while s[count] != 0 {
        count += 1;
    }

    result: string = ---;
    result.data = s;
    result.count = count;
    return result;
}

get_default_text :: () -> Text {
    if !default_loaded {
        default_loaded = true;
        default_text = create_text("", KODA_ASSET_PATH, "TriplexSans-Bold.otf", 24);
    }

    return default_text;
}

get_white_texture :: () -> Texture {
    if !white_texture_loaded {
        white_texture_loaded = true;
        white_texture = load_texture(tprint("%white.png", KODA_ASSET_PATH));
    }

    return white_texture;
}

push_temporary_context :: () #expand {
    old_allocator := context.allocator;

    // TODO can you just do defer context.allocator = context.allocator or will that not copy appropriately?
    context.allocator = __temporary_allocator;
    defer context.allocator = old_allocator;
}

Matrix4Identity :: Matrix4.{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
};

#scope_file

default_loaded: bool = false;
default_text: Text;

white_texture_loaded: bool = false;
white_texture: Texture;

#import "Math";
