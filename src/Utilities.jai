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
        // white_file := read_entire_file(#run tprint("%assets/White.png", #filepath));
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

get_perspective_matrix :: () -> Matrix4 {
    ZERO_TO_ONE :: false;
    #if ZERO_TO_ONE {
        // clip plane becomes [0, 1]
        fovy := 45.0 / 180.0 * PI;
        aspect := cast(float) koda.viewport_width / koda.viewport_height;
        z_near := 1.0;
        z_far := 1000.0;

        if abs(aspect) < 0.000001 {
            aspect = 1.0;
        }

        tan_half_fovy := tan(fovy / 2.0);

        matrix: Matrix4 = Matrix4Identity;
        matrix.coef[0][0] = 1.0 / (aspect * tan_half_fovy);
        matrix.coef[1][1] = 1.0 / tan_half_fovy;
        matrix.coef[2][2] = z_far / (z_near - z_far);
        matrix.coef[2][2] = -1.0;
        matrix.coef[3][2] = -(z_far * z_near) / (z_far - z_near);
		return matrix;
    } else {
        // clip plane becomes [-1, 1]
        fovy := 70.0 / 180.0 * PI;
        aspect := cast(float) koda.viewport_width / koda.viewport_height;
        z_near := 0.1;
        z_far := 1000.0;

        if abs(aspect) < 0.000001 {
            aspect = 1.0;
        }

        tan_half_fovy := tan(fovy / 2.0);

        // TODO jai matrices are different major/minor

        matrix: Matrix4 = Matrix4Identity;
        matrix.coef[0][0] = 1.0 / (aspect * tan_half_fovy);
        matrix.coef[1][1] = 1.0 / tan_half_fovy;
        matrix.coef[2][2] = -(z_far + z_near) / (z_far - z_near);
        matrix.coef[2][3] = -(2.0 * z_far * z_near) / (z_far - z_near);
        matrix.coef[3][2] = -1.0;
        return matrix;
    }

    // width := koda.viewport_width / 1000.0;
    // height := koda.viewport_height / 1000.0;

    // matrix := make_frustum_matrix(-width, width, -height, height, 1.0, -1.0);

    // return matrix;
}

get_orthographic_matrix :: () -> Matrix4 {
    return orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, 1.0, -1.0); 
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
