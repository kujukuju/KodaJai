
FileChangeWatcher :: struct {
    using #as file_watcher: File_Watcher(void);
    initialized: bool;
    folders: [..] string;
    modified_files: [..] string;
    watching_files: [..] string;
    next_allowed_process_time: float64;
}

watch_file :: (watcher: *FileChangeWatcher, file: string) -> bool {
    folder := get_file_folder(file);

    if !watcher.initialized {
        if init(*watcher.file_watcher, watcher_callback, events_to_watch = .MODIFIED, watch_recursively = false) {
            watcher.initialized = true;
        } else {
            assert(false, "Could not initialize file change watcher.\n");
        }
    }
    
    if !watcher.initialized {
        return false;
    }

    if !array_find(watcher.watching_files, file) {
        array_add(*watcher.watching_files, copy_string(file));
    }

    if !array_find(watcher.folders, folder) {
        array_add(*watcher.folders, copy_string(folder));
        return add_directories(*watcher.file_watcher, folder);
    }

    return true;
}

get_changes :: (watcher: *FileChangeWatcher) -> [] string {
    if !watcher.initialized {
        return .[];
    }

    if seconds_since_init() < watcher.next_allowed_process_time {
        return .[];
    }

    watcher.modified_files.count = 0;
    changed, needs_wait, wait_seconds := process_changes(*watcher.file_watcher);

    if needs_wait {
        watcher.next_allowed_process_time = seconds_since_init() + wait_seconds;
    }

    return watcher.modified_files;
}

#scope_file

file_equals :: (a: string, b: string) -> bool {
    ai := 0;
    bi := 0;

    while ai < a.count && bi < b.count {
        if to_lower(a[ai]) != to_lower(b[bi]) {
            return false;
        }

        ai += 1;
        bi += 1;

        has_space_a := false;
        has_space_b := false;

        while ai < a.count && (a[ai] == #char "\\" || a[ai] == #char "/") {
            has_space_a = true;
            ai += 1;
        }
        while bi < b.count && (b[bi] == #char "\\" || b[bi] == #char "/") {
            has_space_b = true;
            bi += 1;
        }

        if has_space_a != has_space_b {
            return false;
        }
    }

    return true;
}

watcher_callback :: (directory_watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
    watcher := cast(*FileChangeWatcher) directory_watcher;

    // don't readd modified files
    for file: watcher.modified_files {
        if file_equals(file, change.full_path) {
            return;
        }
    }

    // don't add non tracked files
    for file: watcher.watching_files {
        if file_equals(file, change.full_path) {
            array_add(*watcher.modified_files, file);
            return;
        }
    }
}

get_file_folder :: (file: string) -> string {
    folder: string;
    folder.data = file.data;
    folder.count = file.count;

    while folder.count > 0 && folder[folder.count - 1] != #char "\\" && folder[folder.count - 1] != #char "/" {
        folder.count -= 1;
    }

    while folder.count > 0 && (folder[folder.count - 1] == #char "\\" && folder[folder.count - 1] == #char "/") {
        folder.count -= 1;
    }

    return folder;
}
