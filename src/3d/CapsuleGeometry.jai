
// creates a capsule geometry where the half height represents the half height of the cylinder before the hemisphere begins
// slices is how many divisions around the axis
// stacks is how many divisions along the cylinder
create_capsule :: (half_height: float, radius: float, segments_radial: int = 8, segments_hemisphere: int = 4, should_upload: bool = true) -> *Geometry {
    vertices: [..] Vector3;
    vertices.allocator = temp;

    half_height = max(half_height, 0);

    for i: 0..segments_radial - 1 {
        curr_radians := cast(float) i / segments_radial * PI * 2;
        next_radians := (cast(float) i + 1) / segments_radial * PI * 2;

        curr_x := cos(curr_radians) * radius;
        curr_z := sin(curr_radians) * radius;
        next_x := cos(next_radians) * radius;
        next_z := sin(next_radians) * radius;

        if half_height > 0 {
            array_add(*vertices, .{next_x, -half_height, next_z});
            array_add(*vertices, .{curr_x, -half_height, curr_z});
            array_add(*vertices, .{curr_x, half_height, curr_z});

            array_add(*vertices, .{next_x, half_height, next_z});
            array_add(*vertices, .{next_x, -half_height, next_z});
            array_add(*vertices, .{curr_x, half_height, curr_z});
        }

        for a: 0..segments_hemisphere - 1 {
            curr_radians_hemi := cast(float) a / segments_hemisphere * PI / 2.0;
            next_radians_hemi := (cast(float) a + 1) / segments_hemisphere * PI / 2.0;

            curr_y := sin(curr_radians_hemi) * radius;
            next_y := sin(next_radians_hemi) * radius;
            curr_radius_mul := cos(curr_radians_hemi);
            next_radius_mul := cos(next_radians_hemi);

            // top
            array_add(*vertices, .{next_x * curr_radius_mul, curr_y + half_height, next_z * curr_radius_mul});
            array_add(*vertices, .{curr_x * curr_radius_mul, curr_y + half_height, curr_z * curr_radius_mul});
            array_add(*vertices, .{curr_x * next_radius_mul, next_y + half_height, curr_z * next_radius_mul});

            array_add(*vertices, .{next_x * next_radius_mul, next_y + half_height, next_z * next_radius_mul});
            array_add(*vertices, .{next_x * curr_radius_mul, curr_y + half_height, next_z * curr_radius_mul});
            array_add(*vertices, .{curr_x * next_radius_mul, next_y + half_height, curr_z * next_radius_mul});

            // bottom
            array_add(*vertices, .{curr_x * next_radius_mul, -next_y - half_height, curr_z * next_radius_mul});
            array_add(*vertices, .{curr_x * curr_radius_mul, -curr_y - half_height, curr_z * curr_radius_mul});
            array_add(*vertices, .{next_x * curr_radius_mul, -curr_y - half_height, next_z * curr_radius_mul});

            array_add(*vertices, .{curr_x * next_radius_mul, -next_y - half_height, curr_z * next_radius_mul});
            array_add(*vertices, .{next_x * curr_radius_mul, -curr_y - half_height, next_z * curr_radius_mul});
            array_add(*vertices, .{next_x * next_radius_mul, -next_y - half_height, next_z * next_radius_mul});
        }
    }

    indices := NewArray(vertices.count, u32,, temp);
    for i: 0..indices.count - 1 {
        indices[i] = cast(u32) i;
    }

    floats: [] float;
    floats.data  = cast(*float) vertices.data;
    floats.count = vertices.count * 3;

    geometry := create_geometry(floats, indices, .[.Position], should_upload = should_upload);
    return geometry;
}

