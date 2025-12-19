
is_amd_gpu :: () -> bool {
    if !is_amd_checked {
        is_amd_checked = true;
        is_amd = get_amd_gpu();
    }

    return is_amd;
}

#scope_file

get_amd_gpu :: () -> bool {
    renderer := to_string(glGetString(GL_RENDERER));
    if renderer && renderer.count > 0 {
        return contains_nocase(renderer, "amd");
    }

    vendor := to_string(glGetString(GL_VENDOR));
    if vendor && vendor.count > 0 {
        return contains_nocase(vendor, "ati");
    }

    return false;
}

is_amd_checked: bool;
is_amd: bool;
