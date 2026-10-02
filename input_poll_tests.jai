// From KodaJai: /usr/local/bin/jai input_poll_tests.jai -quiet && ./.build/input_poll_tests
#import "Basic";
#import "Compiler";

#run,stallable {
    context.allocator = temp;
    current_workspace := get_current_workspace();
    set_build_options_dc(.{do_output = false}, current_workspace);

    workspace := compiler_create_workspace("Input Poll Tests");
    options := get_build_options(workspace);
    options.output_type = .EXECUTABLE;
    options.output_executable_name = "input_poll_tests";
    options.output_path = ".build";

    import_paths: [..] string;
    array_add(*import_paths, #run tprint("%../", #filepath));
    for get_build_options(current_workspace).import_path array_add(*import_paths, it);
    options.import_path = import_paths;

    set_build_options(options, workspace);
    set_working_directory(#filepath);
    add_build_file(tprint("%tests/InputPollTests.jai", #filepath), workspace);
};
