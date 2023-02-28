
create_plane :: (half_width: float, half_height: float, double_sided: bool = false, with_normals: bool = false, with_texcoords: bool = false) -> Geometry {
    geometry: Geometry;

    stride := 3;
    if with_normals {
        stride += 3;
    }
    if with_texcoords {
        stride += 2;
    }

    array_reserve(*geometry.vertices, ifx double_sided then 8 * stride else 4 * stride);
    array_reserve(*geometry.indices, ifx double_sided then 12 else 6);

    vertices: [4] Vector3;
    vertices[0] = Vector3.{-half_width, 0.0, -half_height};
    vertices[1] = Vector3.{-half_width, 0.0, half_height};
    vertices[2] = Vector3.{half_width, 0.0, half_height};
    vertices[3] = Vector3.{half_width, 0.0, -half_height};

    array_add(*geometry.vertices, vertices[0].x, vertices[0].y, vertices[0].z);
    array_add(*geometry.vertices, vertices[1].x, vertices[1].y, vertices[1].z);
    array_add(*geometry.vertices, vertices[2].x, vertices[2].y, vertices[2].z);
    array_add(*geometry.vertices, vertices[3].x, vertices[3].y, vertices[3].z);

    if with_normals {
        array_add(*geometry.vertices, 0.0, 1.0, 0.0);
        array_add(*geometry.vertices, 0.0, 1.0, 0.0);
        array_add(*geometry.vertices, 0.0, 1.0, 0.0);
        array_add(*geometry.vertices, 0.0, 1.0, 0.0);
    }

    if with_texcoords {
        array_add(*geometry.vertices, 0.0, 0.0);
        array_add(*geometry.vertices, 0.0, 1.0);
        array_add(*geometry.vertices, 1.0, 1.0);
        array_add(*geometry.vertices, 1.0, 0.0);
    }

    if with_normals {
        array_add(*geometry.vertices, vertices[0].x, vertices[0].y, vertices[0].z);
        array_add(*geometry.vertices, vertices[1].x, vertices[1].y, vertices[1].z);
        array_add(*geometry.vertices, vertices[2].x, vertices[2].y, vertices[2].z);
        array_add(*geometry.vertices, vertices[3].x, vertices[3].y, vertices[3].z);
        
        array_add(*geometry.vertices, 0.0, -1.0, 0.0);
        array_add(*geometry.vertices, 0.0, -1.0, 0.0);
        array_add(*geometry.vertices, 0.0, -1.0, 0.0);
        array_add(*geometry.vertices, 0.0, -1.0, 0.0);

        if with_texcoords {
            array_add(*geometry.vertices, 0.0, 0.0);
            array_add(*geometry.vertices, 0.0, 1.0);
            array_add(*geometry.vertices, 1.0, 1.0);
            array_add(*geometry.vertices, 1.0, 0.0);
        }
    }

    indices: [6] u32;
    indices[0] = 0;
    indices[1] = 1;
    indices[2] = 2;
    indices[3] = 0;
    indices[4] = 2;
    indices[5] = 3;

    array_add(*geometry.indices, indices[0], indices[1], indices[2]);
    array_add(*geometry.indices, indices[3], indices[4], indices[5]);

    if double_sided {
        array_add(*geometry.indices, indices[2], indices[1], indices[0]);
        array_add(*geometry.indices, indices[5], indices[4], indices[3]);
    }

    add_attribute(*geometry, .Position);
    if with_normals {
        add_attribute(*geometry, .Normal);
    }
    if with_texcoords {
        add_attribute(*geometry, .Texcoord);
    }

    gen_geometry(*geometry);

    return geometry;
}