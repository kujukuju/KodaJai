insert_glsl_methods :: (body: string) -> string {
    method_headers: Table(string, string);
    method_headers.allocator = temp;

    for method: GLSL_METHODS {
        header_start_index := -1;
        header_end_index := -1;

        lookahead := 0;

        while header_start_index == -1 || header_end_index == -1 {
            if header_start_index == -1 && is_non_whitespace(method.data[lookahead]) {
                header_start_index = lookahead;
            }

            if header_end_index == -1 && method.data[lookahead] == #char "{" {
                header_end_index = lookahead;
            }

            lookahead += 1;
        }

        existing_header: string;
        existing_header.data = method.data + header_start_index;
        existing_header.count = header_end_index - header_start_index;

        header := copy_string(existing_header,, allocator = temp);
        header.data[header.count - 1] = #char ";";

        table_set(*method_headers, header, method);
    }

    final := body;
    for entry, header: method_headers {
        // split is temp allocated
        segments := split(final, header,, allocator = temp);
        // join is assigned to temp allocated
        final = join(..segments, entry,, allocator = temp);
    }

    return final;
}

is_non_whitespace :: (character: u8) -> bool {
    return character != #char " " && character != #char "\t" && character != #char "\r" && character != #char "\n";
}

// was gonna use this to insert constants so I can be sure its the entire constant name and not a sub part
is_variable_character :: (character: u8) -> bool {
    valid := character >= #char "A" && character <= #char "Z";
    valid = valid || character >= #char "a" && character <= #char "z";
    valid = valid || character >= #char "a" && character <= #char "z";
    valid = valid || character >= #char "0" && character <= #char "9";
    valid = valid || character == #char "_";
    return valid;
}

insert_constants :: (body: string, $constants: ..string) -> string {
    replaced := body;

    // for constant: constants {
    //     replaced = replace(replaced, constant, tprint("%", #insert constant));
    // }

    // this allocates memory but I think it's fine because it's compile time
    #insert #run () -> string {
        builder: String_Builder;
        for constant: constants {
            append(*builder, tprint("replaced = replace(replaced, \"%\", tprint(\"%%\", %));", constant, constant));
        }

        return builder_to_string(*builder);
    }();

    return replaced;
}

GLSL_METHODS :: string.[
    #string ___glsl
    float curve(float value) {
        return value * value;
    }
    ___glsl,
];