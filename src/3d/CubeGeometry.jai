create_cube :: (half: Vector3, with_normals: bool = false, with_texcoords: bool = false) -> *Geometry {
    geometry := New(Geometry);

    vertices: [8] Vector3;
    // top front left
    vertices[0] = .{-half.x, half.y, -half.z};
    // bottom front left
    vertices[1] = .{-half.x, -half.y, -half.z};
    // bottom back left
    vertices[2] = .{-half.x, -half.y, half.z};
    // top back left
    vertices[3] = .{-half.x, half.y, half.z};
    // top front right
    vertices[4] = .{half.x, half.y, -half.z};
    // bottom front right
    vertices[5] = .{half.x, -half.y, -half.z};
    // bottom back right
    vertices[6] = .{half.x, -half.y, half.z};
    // top back right
    vertices[7] = .{half.x, half.y, half.z};

    indices: [36] u32 : .[
        // left
        0, 1, 2,
        0, 2, 3,
        // front
        5, 1, 0,
        4, 5, 0,
        // bottom
        6, 2, 1,
        5, 6, 1,
        // back
        3, 2, 6,
        3, 6, 7,
        // top
        0, 3, 7,
        0, 7, 4,
        // right
        7, 6, 5,
        7, 5, 4,
    ];

    for vertex: vertices {
        array_add(*geometry.vertices, vertex.x, vertex.y, vertex.z);

        if with_normals {
            assert(false, "No normals yet.");
        }

        if with_texcoords {
            assert(false, "No texcoords yet.");
        }
    }

    for index: indices {
        array_add(*geometry.indices, index);
    }

    geometry.has_normal = with_normals;
    geometry.has_texcoord = with_texcoords;

    gen_geometry(geometry);

    return geometry;
}
