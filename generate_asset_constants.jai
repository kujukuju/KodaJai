#run () {
    files := file_list("assets/");
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

        builder: String_Builder;
        append(*builder, constant_name);
        append(*builder, " :: #string DONE\n");
        append(*builder, file);
        append(*builder, "\nDONE");

        new_filepath := tprint("assets/%", new_filename);
        print("Writing file. %\n", new_filepath);
        write_entire_file(new_filepath, builder_to_string(*builder));
    }
    
    print("Done writing files.");
}();

#scope_file

#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";