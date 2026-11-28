
is_amd_gpu :: () -> bool {
    if !is_amd_checked {
        is_amd_checked = true;
        is_amd = get_amd_gpu();
    }

    return is_amd;
}

#scope_file

get_amd_gpu :: () -> bool {
    vendor := to_string(glGetString(GL_VENDOR));
    // Match "ati technologies" rather than bare "ati", which matches "NVIDIA Corporation".
    if contains_nocase(vendor, "ati technologies") || contains_nocase(vendor, "amd") {
        return true;
    }

    renderer := to_string(glGetString(GL_RENDERER));
    if contains_nocase(renderer, "amd") || contains_nocase(renderer, "radeon") {
        return true;
    }

    return false;
}

is_amd_checked: bool;
is_amd: bool;
