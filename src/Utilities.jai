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

get_default_font :: () -> *Font {
    #run {
        file_bytes: [] u8;
        file_bytes.data = TriplexSansBold.data;
        file_bytes.count = TriplexSansBold.count;

        character_set :: #run create_character_set(.[0, 255]);
        font := create_font(file_bytes, 14, character_set, false);

        serialized_path := tprint("%/assets/TriplexSansBoldSerialized.font", #filepath);
        write_serialized(serialized_path, .[], font, reuse_memory = false);
    };

    if !default_font_loaded {
        default_font_loaded = true;

        serialized_path := tprint("%/assets/TriplexSansBoldSerialized.font", #filepath);
        success := read_serialized(serialized_path, .[], *default_font, reuse_memory = false);
        assert(success, "Could not load default font.\n");

        upload(default_font);
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
        white_texture = create_texture(white_texture_bytes, .Clamp, .Nearest);
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
    // TODO this shouldn't work this way
    if koda.projection == Matrix4Identity {
        koda.projection = calculate_perspective_matrix();
    }

    return koda.projection;
}

calculate_perspective_matrix :: (fovy: float = 0, aspect_ratio: float = 0) -> Matrix4 {
    if fovy == 0 then fovy = koda.fovy;
    if aspect_ratio == 0 then aspect_ratio = cast(float) koda.width / koda.height;

    // fwiw its possible to do infinite perspective matrix
    // this seems to be the _only_ matrix that doesn't rotate your camera around the near plane

    height := tan(fovy / 2.0);
    width := aspect_ratio * height;

    matrix := make_frustum_matrix_clipping(-width, width, -height, height, 0.1, -0.1);

    if koda.render_flipped {
        inverted_matrix := Matrix4Identity;
        inverted_matrix._22 = -1.0;
        matrix = matrix * inverted_matrix;
    }

    return matrix;
}

get_orthographic_matrix :: () -> Matrix4 {
    left := 0.0;
    right := cast(float) koda.width;
    top := cast(float) ifx koda.height < 0 then -koda.height else 0;
    bottom := cast(float) ifx koda.height > 0 then koda.height else 0;
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
    
    // return orthographic_projection_matrix(0.0, xx koda.width, 0.0, xx koda.height, 1.0, -1.0); 
}

create_orthographic_matrix :: (left: float, right: float, bottom: float, top: float, near: float, far: float) -> Matrix4 {
    ortho: Matrix4;

    ortho._11 = 2.0 / (right - left);
    ortho._22 = 2.0 / (top - bottom);
    ortho._33 = 2.0 / (far - near);
    ortho._44 = 1.0;
    
    ortho._14 = -(right + left) / (right - left);
    ortho._24 = -(top + bottom) / (top - bottom);
    ortho._34 = -(far + near) / (far - near);

    return ortho;
}

open_url :: (path: string) {
    HWND :: *void;
    LPCWSTR :: *u16;
    HINSTANCE :: *void;
    SW_SHOWNORMAL :: 1;

    shell32 :: #system_library "shell32";
    ShellExecuteW :: (hwnd: HWND, lpOperation: LPCWSTR, lpFile: LPCWSTR, lpParameters: LPCWSTR, lpDirectory: LPCWSTR, nShowCmd: s32) -> HINSTANCE #foreign shell32;
    path_string := NewArray(path.count + 1, u16,, allocator = temp);
    for i: 0..path.count - 1 {
        path_string[i] = path[i];
    }

    ShellExecuteW(null, null, path_string.data, null, null, SW_SHOWNORMAL);
}

print_caller_trace :: () #expand {
    node := context.stack_trace;
    if node && node.info then print("% at %:%\n", node.info.name, node.info.location.fully_pathed_filename, node.line_number);
}

print_stack_trace :: () #expand {
    node := context.stack_trace;
    while node {
        // There are two different line numbers available.
        // node.info.location has a line number, but this is the location of
        // the start of the procedure. That may be useful in some cases, but often
        // what we really want is the line number of the procedure call, which is
        // stored in node.line_number. That's what we print in this case.
        
        if node.info print("% at %:%\n", node.info.name, node.info.location.fully_pathed_filename, node.line_number);
        node = node.next;
    }
}

EfficientRemove :: struct (T: Type) {
    captured: *[] T;
}

efficient_remove :: (captured: *[] $T) -> EfficientRemove(T) {
    return EfficientRemove(T).{captured};
}

for_expansion :: (wrapper: EfficientRemove($T), body: Code, flags: For_Flags) #expand {
    // you can't efficiently remove in reverse as far as I can tell unless you manually reverse first
    #assert(!(flags & .REVERSE));

    insert_index := 0;
    check_index := 0;

    defer {
        // handle breaks
        while insert_index != check_index && check_index < wrapper.captured.count {
            wrapper.captured.*[insert_index] = wrapper.captured.*[check_index];

            insert_index += 1;
            check_index += 1;
        }

        wrapper.captured.count -= check_index - insert_index;
    };

    while check_index < wrapper.captured.count {
        #if flags & .POINTER {
            `it := *wrapper.captured.*[check_index];
        } else {
            `it := wrapper.captured.*[check_index];
        }

        `it_index := check_index;

        should_keep := true;
        defer if should_keep {
            if insert_index != check_index {
                wrapper.captured.*[insert_index] = wrapper.captured.*[check_index];
            }

            insert_index += 1;
            check_index += 1;
        }
        #insert (remove={check_index += 1; should_keep = false;}) body;
    }
}

EfficientRemove2 :: struct (A: Type, B: Type) {
    captured_left: *[] A;
    captured_right: *[] B;
}

efficient_remove :: (captured_left: *[] $A, captured_right: *[] $B) -> EfficientRemove2(A, B) {
    return EfficientRemove2(A, B).{captured_left, captured_right};
}

for_expansion :: (wrapper: EfficientRemove2($A, $B), body: Code, flags: For_Flags) #expand {
    // you can't efficiently remove in reverse as far as I can tell unless you manually reverse first
    #assert(!(flags & .REVERSE));

    insert_index := 0;
    check_index := 0;

    defer {
        // handle breaks
        while insert_index != check_index && check_index < wrapper.captured_left.count {
            wrapper.captured_left.*[insert_index] = wrapper.captured_left.*[check_index];
            wrapper.captured_right.*[insert_index] = wrapper.captured_right.*[check_index];

            insert_index += 1;
            check_index += 1;
        }

        wrapper.captured_left.count -= check_index - insert_index;
        wrapper.captured_right.count -= check_index - insert_index;
    };

    while check_index < wrapper.captured_left.count {
        #if flags & .POINTER {
            Value :: struct {
                left: *A;
                right: *B;
            }
            `it := Value.{*wrapper.captured_left.*[check_index], *wrapper.captured_right.*[check_index]};
        } else {
            Value :: struct {
                left: A;
                right: B;
            }
            `it := Value.{wrapper.captured_left.*[check_index], wrapper.captured_right.*[check_index]};
        }

        `it_index := check_index;

        should_keep := true;
        defer if should_keep {
            if insert_index != check_index {
                wrapper.captured_left.*[insert_index] = wrapper.captured_left.*[check_index];
                wrapper.captured_right.*[insert_index] = wrapper.captured_right.*[check_index];
            }

            insert_index += 1;
            check_index += 1;
        }
        #insert (remove={check_index += 1; should_keep = false;}) body;
    }
}

// efficient removal exmaple
// #run {
//     first_valid := 0;
//     array: [..] int;
//     array_add(*array, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20);

//     for value: efficient_remove(*array) {
//         if value == 1 || value >= 4 && value < 14 || value == 15 || value == 20 {
//             remove;
//         } else {
//             if !first_valid {
//                 first_valid = value;
//             }
//             print("Valid %.\n", value);

//             if value % 2 {
//                 continue;
//             }

//             // if value >= 16 {
//             //     break;
//             // }
//         }
//     }

//     print("First valid. %\n", first_valid);
//     print("Final array. Should be missing 1, 4 through 13, 15, and 20. %\n", array);
// }

// efficient_remove :: (captured: *[] $T, code: Code) #expand {
//     insert_index := 0;
//     check_index := 0;
//     while check_index < captured.count {
//         it := captured.*[check_index];
//         it_index := check_index;

//         should_remove := false;

//         defer if should_remove {
//             check_index += 1;
//         } else {
//             if insert_index != check_index {
//                 captured.*[insert_index] = captured.*[check_index];
//             }

//             insert_index += 1;
//             check_index += 1;
//         }

//         #insert,scope() code;
//     }

//     // handle breaks
//     while insert_index != check_index && check_index < captured.count {
//         captured.*[insert_index] = captured.*[check_index];

//         insert_index += 1;
//         check_index += 1;
//     }

//     captured.count -= check_index - insert_index;
// }

// efficient removal function test
// #run {
//     first_valid := 0;
//     array: [..] int;
//     array_add(*array, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20);

//     efficient_remove(*array, #code {
//         if it == 1 || it >= 4 && it < 14 || it == 15 || it == 20 {
//             should_remove = true;
//         } else {
//             if !`first_valid {
//                 `first_valid = it;
//             }
//             print("Valid %.\n", it);
            
//             if it % 2 {
//                 continue;
//             }

//             // if it >= 16 {
//             //     break;
//             // }
//         }
//     });

//     print("First valid. %\n", first_valid);
//     print("Final array. Should be missing 1, 4 through 13, 15, and 20. %\n", array);
// }

// this copies all context additions defined outside of the base context
// however, that includes all context additions made by modules, such as random_state
copy_context_additions :: (parent: Context) {
    info :: type_info(Context);

    #insert #run () -> string {
        builder: String_Builder;
        for member: info.members {
            if member.type == cast(*Type_Info) Context_Base {
                continue;
            }

            append(*builder, "context.");
            append(*builder, member.name);
            append(*builder, " = parent.");
            append(*builder, member.name);
            append(*builder, ";\n");
        }
        return builder_to_string(*builder);
    }();
} @thread

#scope_file

default_font_loaded: bool = false;
default_font: *Font;

white_texture_loaded: bool = false;
white_texture: Texture;

#import "Math";
