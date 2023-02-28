create_cube :: (half: Vector3, double_sided: bool = false, with_normals: bool = false, with_texcoords: bool = false, with_unwrapped_texcoords: bool = false) -> *Geometry {
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

    unwrapped_texcoords: [24] Vector2 : .[
        // left top left
        .{0.0, 1.0 / 3.0},
        // left bottom left
        .{0.0, 2.0 / 3.0},
        // left bottom right
        .{1.0 / 4.0, 2.0 / 3.0},
        // left top right
        .{1.0 / 4.0, 1.0 / 3.0},

        // top top left
        .{1.0 / 4.0, 0.0},
        // top bottom left
        .{1.0 / 4.0, 1.0 / 3.0},
        // top bottom right
        .{2.0 / 4.0, 1.0 / 3.0},
        // top top right
        .{2.0 / 4.0, 0.0},

        // front top left
        .{1.0 / 4.0, 1.0 / 3.0},
        // front bottom left
        .{1.0 / 4.0, 2.0 / 3.0},
        // front bottom right
        .{2.0 / 4.0, 2.0 / 3.0},
        // front top right
        .{2.0 / 4.0, 1.0 / 3.0},

        // bottom top left
        .{1.0 / 4.0, 2.0 / 3.0},
        // bottom bottom left
        .{1.0 / 4.0, 1.0},
        // bottom bottom right
        .{2.0 / 4.0, 1.0},
        // bottom top right
        .{2.0 / 4.0, 2.0 / 3.0},

        // right top left
        .{2.0 / 4.0, 1.0 / 3.0},
        // right bottom left
        .{2.0 / 4.0, 2.0 / 3.0},
        // right bottom right
        .{3.0 / 4.0, 2.0 / 3.0},
        // right top right
        .{3.0 / 4.0, 1.0 / 3.0},

        // back top left
        .{3.0 / 4.0, 1.0 / 3.0},
        // back bottom left
        .{3.0 / 4.0, 2.0 / 3.0},
        // back bottom right
        .{1.0, 2.0 / 3.0},
        // back top right
        .{1.0, 1.0 / 3.0},
    ];

    if with_unwrapped_texcoords {
        unwrapped_vertices: [24] Vector3;
        // left top left
        unwrapped_vertices[0] = vertices[3]; //
        // left bottom left
        unwrapped_vertices[1] = vertices[2];
        // left bottom right
        unwrapped_vertices[2] = vertices[1]; //
        // left top right
        unwrapped_vertices[3] = vertices[0]; //
        // top top left
        unwrapped_vertices[4] = vertices[3];
        // top bottom left
        unwrapped_vertices[5] = vertices[0];
        // top bottom right
        unwrapped_vertices[6] = vertices[4];
        // top top right
        unwrapped_vertices[7] = vertices[7];
        // front top left
        unwrapped_vertices[8] = vertices[0];
        // front bottom left
        unwrapped_vertices[9] = vertices[1];
        // front bottom right
        unwrapped_vertices[10] = vertices[5];
        // front top right
        unwrapped_vertices[11] = vertices[4];
        // bottom top left
        unwrapped_vertices[12] = vertices[1];
        // bottom bottom left
        unwrapped_vertices[13] = vertices[2];
        // bottom bottom right
        unwrapped_vertices[14] = vertices[6];
        // bottom top right
        unwrapped_vertices[15] = vertices[5];
        // right top left
        unwrapped_vertices[16] = vertices[4];
        // right bottom left
        unwrapped_vertices[17] = vertices[5];
        // right bottom right
        unwrapped_vertices[18] = vertices[6];
        // right top right
        unwrapped_vertices[19] = vertices[7];
        // back top left
        unwrapped_vertices[20] = vertices[7];
        // back bottom left
        unwrapped_vertices[21] = vertices[6];
        // back bottom right
        unwrapped_vertices[22] = vertices[2];
        // back top right
        unwrapped_vertices[23] = vertices[3];

        unwrapped_indices: [36] u32 = .[
            // left
            3, 0, 2,
            0, 1, 2,
            // front
            11, 8, 10,
            8, 9, 10,
            // bottom
            15, 12, 14,
            12, 13, 14,
            // back
            23, 20, 22, // guessing after this
            20, 21, 22,
            // top
            7, 4, 6,
            4, 5, 6,
            // right
            19, 16, 18,
            16, 17, 18,
        ];

        array_reserve(*geometry.vertices, unwrapped_vertices.count * 5);
        for i: 0..unwrapped_vertices.count - 1 {
            array_add(*geometry.vertices, ..unwrapped_vertices[i].component);
            array_add(*geometry.vertices, ..unwrapped_texcoords[i].component);
        }

        array_add(*geometry.indices, ..unwrapped_indices);
    } else {
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

        if double_sided {
            i := 0;
            while i < indices.count {
                array_add(*geometry.indices, indices[i + 2], indices[i + 1], indices[i]);

                i += 3;
            }
        }
    }

    add_attribute(geometry, .Position);
    if with_normals {
        add_attribute(geometry, .Normal);
    }
    if with_texcoords || with_unwrapped_texcoords {
        add_attribute(geometry, .Texcoord);
    }

    gen_geometry(geometry);

    return geometry;
}
