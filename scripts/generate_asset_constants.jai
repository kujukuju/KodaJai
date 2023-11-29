#run () {
    files := file_list(tprint("%/../src/assets/", #filepath));
    for file: files {
        if ends_with(file, "jai") {
            continue;
        }

        slash_parts: [..] string;
        defer array_free(slash_parts);
        array_copy(*slash_parts, split(file, "/"));
        filename := slash_parts[slash_parts.count - 1];

        filename_parts: [..] string;
        defer array_free(filename_parts);
        array_copy(*filename_parts, split(filename, "."));
        array_ordered_remove_by_index(*filename_parts, filename_parts.count - 1);
        constant_name := join(..filename_parts, ".");
        array_add(*filename_parts, "jai");
        new_filename := join(..filename_parts, ".");

        file, success := read_entire_file(file);
        if !success {
            print("Could not write file. %\n", filename);
            continue;
        }

        if contains(file, "DONE") {
            print("File contains key DONE. %\n", filename);
            continue;
        }

        bytes: [] u8;
        bytes.data = file.data;
        bytes.count = file.count;

        result := write_asset(bytes);
        defer free(result);

        builder: String_Builder;
        append(*builder, constant_name);
        append(*builder, " :: #string DONE\n");
        append(*builder, result);
        append(*builder, "\nDONE");

        new_filepath := tprint("%../src/assets/%", #filepath, new_filename);
        print("Writing file. %\n", new_filepath);
        write_entire_file(new_filepath, builder_to_string(*builder));
    }
    
    print("Done writing files.");
}();

write_asset :: (bytes: [] u8) -> string {
    rn_count := 0;
    for i: 0..bytes.count - 2 {
        if bytes[i] == #char "\r" && bytes[i + 1] == #char "\n" {
            rn_count += 1;
        }
    }

    if rn_count == 0 {
        result: string;
        result.data = alloc(bytes.count);
        memcpy(result.data, bytes.data, bytes.count);
        result.count = bytes.count;
        return result;
    }

    memory := cast(*u8) alloc(bytes.count + rn_count);

    write_offset := 0;
    for i: 0..bytes.count - 1 {
        if i < bytes.count - 1 && bytes[i] == #char "\r" && bytes[i + 1] == #char "\n" {
            memory[i + write_offset] = #char "\r";
            memory[i + write_offset + 1] = #char "\r";
            write_offset += 1;
        } else {
            memory[i + write_offset] = bytes[i];
        }
    }

    result: string;
    result.data = memory;
    result.count = bytes.count + rn_count;
    return result;
}

#scope_file

#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";