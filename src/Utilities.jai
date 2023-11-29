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

#run,stallable {
    file_bytes: [] u8;
    file_bytes.data = TriplexSansBold.data;
    file_bytes.count = TriplexSansBold.count;

    font := create_font(file_bytes, 24, false);
    bytes: [..] u8;
    serializer_write(*bytes, font, false);
    byte_string: string;
    byte_string.data = bytes.data;
    byte_string.count = bytes.count;

    write_entire_file(tprint("%/assets/TriplexSansBoldFont.font", #filepath), byte_string);
};

get_default_font :: () -> *Font {
    if !default_font_loaded {
        default_font_loaded = true;

        file_bytes: [] u8;
        file_bytes.data = TriplexSansBoldFont.data;
        file_bytes.count = TriplexSansBoldFont.count;
        serializer_read(file_bytes, *default_font, 0, false);

        // default_font_loaded = true;
        // default_font_bytes: [] u8;
        // default_font_bytes.data = TriplexSansBold.data;
        // default_font_bytes.count = TriplexSansBold.count;
        // default_font = create_font(default_text_bytes, 24);
    }

    return default_font;
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

make_frustum_matrix_clipping :: (l: float, r: float, b: float, t: float, n: float, f: float) -> Matrix4 {
    // this function is basically a copy of the make_frustum_matrix function but
    // it lets you modify the clipping planes without affecting the fov
    double_znear := 2.0;
    one_deltax := 1.0 / (r - l);
    one_deltay := 1.0 / (t - b);

    result := Matrix4_Identity;
    result._11 = double_znear * one_deltax;
    result._22 = double_znear * one_deltay;
    result._13 = (r + l) * one_deltax;
    result._23 = (t + b) * one_deltay;
    result._33 = -(f + n) / (f - n);
    result._43 = -1;
    result._34 = -(f * n * 2) / (f - n);
    result._44 = 0;

    return result;
}

get_perspective_matrix :: () -> Matrix4 {
    fovy := koda.fovy;
    // fwiw its possible to do infinite perspective matrix
    BUILTIN :: true;
    #if BUILTIN {
        // this seems to be the _only_ matrix that doesn't rotate your camera around the near plane
        aspect := cast(float) koda.viewport_width / koda.viewport_height;

        height := tan(fovy / 2.0);
        width := aspect * height;

        matrix := make_frustum_matrix_clipping(-width, width, -height, height, 0.1, -0.1);

        if koda.render_flipped {
            inverted_matrix := Matrix4Identity;
            inverted_matrix._22 = -1.0;
            matrix = matrix * inverted_matrix;
        }

		return matrix;
    } else {
        ZERO_ONE :: false;
        #if ZERO_ONE {
            // clip plane becomes [0, 1]
            fovy := 70.0 / 180.0 * PI;
            // aspect := cast(float) abs(koda.viewport_width) / abs(koda.viewport_height);
            z_near := 0.1;
            z_far := 1000.0;

            h := cos(0.5 * fovy) / sin(0.5 * fovy);
            w := h * koda.viewport_height / koda.viewport_width;

            matrix: Matrix4 = Matrix4Identity;
            matrix.coef[0][0] = w;
            matrix.coef[1][1] = h;
            matrix.coef[2][2] = z_far / (z_near - z_far);
            matrix.coef[3][2] = -1.0;
            matrix.coef[2][3] = -(z_far * z_near) / (z_far - z_near);
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

            flip_y := ifx koda.render_flipped < 0 then -1.0 else 1.0;

            tan_half_fovy := tan(fovy / 2.0);

            // TODO jai matrices are different major/minor

            matrix: Matrix4 = Matrix4Identity;
            matrix.coef[0][0] = flip_y * 1.0 / (aspect * tan_half_fovy);
            matrix.coef[1][1] = flip_y * 1.0 / tan_half_fovy;
            matrix.coef[2][2] = -(z_far + z_near) / (z_far - z_near);
            matrix.coef[2][3] = -(2.0 * z_far * z_near) / (z_far - z_near);
            matrix.coef[3][2] = -1.0;
            return matrix;
        }
    }
}

get_orthographic_matrix :: () -> Matrix4 {
    left := 0.0;
    right := cast(float) koda.viewport_width;
    top := cast(float) ifx koda.viewport_height < 0 then -koda.viewport_height else 0;
    bottom := cast(float) ifx koda.viewport_height > 0 then koda.viewport_height else 0;
    z_far := -1.0;
    z_near := 1.0;

    matrix: Matrix4 = Matrix4Identity;
    matrix.coef[0][0] = 2.0 / (right - left);
    matrix.coef[0][3] = -(right + left) / (right - left);
    matrix.coef[1][1] = 2.0 / (top - bottom);
    matrix.coef[1][3] = -(top + bottom) / (top - bottom);
    matrix.coef[2][2]  = 1.0 / (z_far - z_near);
    matrix.coef[2][3] = -z_near / (z_far - z_near);
    return matrix;
    
    // return orthographic_projection_matrix(0.0, xx koda.viewport_width, 0.0, xx koda.viewport_height, 1.0, -1.0); 
}

// Matrix4Identity :: Matrix4.{
//     1, 0, 0, 0,
//     0, 1, 0, 0,
//     0, 0, 1, 0,
//     0, 0, 0, 1,
// };

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

default_font_loaded: bool = false;
default_font: *Font;

white_texture_loaded: bool = false;
white_texture: Texture;

#import "Math";
