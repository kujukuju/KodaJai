create_grid :: (x_count: int, y_count: int, gap: float, up: Vector3 = .{0, 1, 0}) -> Geometry {
    width := (x_count - 1) * gap;
    height := (y_count - 1) * gap;

    geometry: Geometry;

    for x: 0..x_count - 1 {
        x_offset := x * gap - width / 2.0;
        v1 := Vector3.{x_offset, 0.0, -height / 2.0};
        v2 := Vector3.{x_offset, 0.0, height / 2.0};

        array_add(*geometry.vertices, v1.x, v1.y, v1.z);
        array_add(*geometry.vertices, v2.x, v2.y, v2.z);
    }

    for y: 0..y_count - 1 {
        y_offset := y * gap - height / 2.0;
        v1 := Vector3.{-width / 2.0, 0.0, y_offset};
        v2 := Vector3.{width / 2.0, 0.0, y_offset};

        array_add(*geometry.vertices, v1.x, v1.y, v1.z);
        array_add(*geometry.vertices, v2.x, v2.y, v2.z);
    }

    gen_geometry(*geometry);

    return geometry;
}