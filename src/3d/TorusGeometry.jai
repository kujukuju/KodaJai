
create_torus :: (major_radius: float, minor_radius: float, major_segments: int, minor_segments: int, with_normals: bool = false, with_texcoords: bool = false, should_upload: bool = true) -> *Geometry {
    geometry := New(Geometry);

    stride := 3;
    if with_normals {
        stride += 3;
    }
    if with_texcoords {
        stride += 2;
    }

    array_reserve(*geometry.vertices, major_segments * minor_segments * stride);
    array_reserve(*geometry.indices, major_segments * minor_segments * 6);

    for i: 0..major_segments - 1 {
        for j: 0..minor_segments - 1 {
            u := ((cast(float) j) / minor_segments) * PI * 2.0;
            v := ((cast(float) i) / major_segments) * PI * 2.0;

            // print("u deg % cos % sin %\n", u / PI * 180, cos(u), sin(u));

            center: Vector3;
            center.x = cos(v) * major_radius;
            center.y = 0.0;
            center.z = sin(v) * major_radius;

            vertex: Vector3;
            vertex.x = cos(v) * (major_radius + minor_radius * cos(u));
            vertex.y = minor_radius * sin(u);
            vertex.z = sin(v) * (major_radius + minor_radius * cos(u));

            array_add(*geometry.vertices, vertex.x, vertex.y, vertex.z);

            if with_normals {
                normal := normalize(vertex - center);
                array_add(*geometry.vertices, normal.x, normal.y, normal.z);
            }

            if with_texcoords {
                texcoord: Vector2;
                texcoord.x = cast(float) j / major_segments;
                texcoord.y = cast(float) i / minor_segments;
                array_add(*geometry.vertices, texcoord.x, texcoord.y);
            }
        }
    }

    for i: 0..major_segments - 1 {
        i_next := (i + 1) % major_segments;
        
        for j: 0..minor_segments - 1 {
            j_next := (j + 1) % minor_segments;

            i0 := cast(u32) (i * minor_segments + j);
            i1 := cast(u32) (i * minor_segments + j_next);
            i2 := cast(u32) (i_next * minor_segments + j_next);
            i3 := cast(u32) (i_next * minor_segments + j);

            array_add(*geometry.indices, i0, i1, i2);
            array_add(*geometry.indices, i0, i2, i3);
        }
    }

    add_attribute(geometry, .Position);
    if with_normals {
        add_attribute(geometry, .Normal);
    }
    if with_texcoords {
        add_attribute(geometry, .Texcoord);
    }

    if should_upload {
        upload(geometry);
    }

    return geometry;
}
