
#run {
    set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace();
    options := get_build_options();
    options.output_type = .EXECUTABLE;
    options.output_executable_name = "example";
    options.debug_for_expansions = true;
    options.import_path = .["C:/jai/modules", #run tprint("%../../", #filepath), "/usr/jai/modules"];
    
    // set_optimization(*options, .VERY_OPTIMIZED);

    set_build_options(options, w);

    files := file_list(tprint("%src", #filepath), true);
    for file: files {
        if !ends_with(file, ".jai") {
            continue;
        }

        add_build_file(file, w);
    }
}

#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "File_Utilities";
