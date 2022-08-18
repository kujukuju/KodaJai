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
    if !default_text_loaded {
        default_text_loaded = true;
        default_text_bytes: [] u8;
        default_text_bytes.data = TriplexSansBold.data;
        default_text_bytes.count = TriplexSansBold.count;
        default_text = create_text("", default_text_bytes, 24);
    }

    return default_text;
}

get_white_texture :: () -> Texture {
    if !white_texture_loaded {
        white_texture_loaded = true;
        white_texture_bytes: [] u8;
        white_texture_bytes.data = White.data;
        white_texture_bytes.count = White.count;
        white_texture = create_texture(white_texture_bytes);
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

#scope_module

print_stack_trace :: () {
    node := context.stack_trace;
    while node {
        // There are two different line numbers available.
        // node.info.location has a line number, but this is the location of
        // the start of the procedure. That may be useful in some cases, but often
        // what we really want is the line number of the procedure call, which is
        // stored in node.line_number. That's what we print in this case.
        
        if node.info print("'%' at %:% ; call depth %, hash 0x%\n", node.info.name, node.info.location.fully_pathed_filename, node.line_number, node.call_depth, formatInt(node.hash, base=16));
        node = node.next;
    }
}

#scope_file

default_text_loaded: bool = false;
default_text: Text;

white_texture_loaded: bool = false;
white_texture: Texture;

#import "Math";
