
create_icosphere :: (radius: float, subdivision: int, with_normals: bool = false, with_texcoords: bool = false) -> *Geometry {
    H_ANGLE: float : PI / 180.0 * 72.0;
    V_ANGLE: float : #run atan(1.0 / 2.0);
    S_STEP: float : 186.0 / 2048.0;
    T_STEP: float : 322.0 / 1024.0;

    compute_half_vertex :: (v1: Vector3, v2: Vector3, radius: float) -> Vector3 {
        newV: Vector3;
        newV.x = v1.x + v2.x;
        newV.y = v1.y + v2.y;
        newV.z = v1.z + v2.z;

        scale := radius / sqrt(newV.x * newV.x + newV.y * newV.y + newV.z * newV.z);
        newV.x *= scale;
        newV.y *= scale;
        newV.z *= scale;

        return newV;
    }

    compute_half_tex_coord :: (t1: Vector2, t2: Vector2) -> Vector2 {
        newT: Vector2 = ---;
        newT.x = (t1.x + t2.x) * 0.5;
        newT.y = (t1.y + t2.y) * 0.5;
        return newT;
    }

    compute_face_normal :: (v1: Vector3, v2: Vector3, v3: Vector3) -> Vector3 {
        EPSILON :: 0.000001;

        n: Vector3;

        // find 2 edge vectors: v1-v2, v1-v3
        ex1 := v2.x - v1.x;
        ey1 := v2.y - v1.y;
        ez1 := v2.z - v1.z;
        ex2 := v3.x - v1.x;
        ey2 := v3.y - v1.y;
        ez2 := v3.z - v1.z;

        // cross product: e1 x e2
        nx := ey1 * ez2 - ez1 * ey2;
        ny := ez1 * ex2 - ex1 * ez2;
        nz := ex1 * ey2 - ey1 * ex2;

        // normalize only if the length is > 0
        length := sqrt(nx * nx + ny * ny + nz * nz);
        if length > EPSILON {
            // normalize
            length_inv := 1.0 / length;
            n.x = nx * length_inv;
            n.y = ny * length_inv;
            n.z = nz * length_inv;
        }

        return n;
    }

    hAngle1: float = -PI / 2 - H_ANGLE / 2;
    hAngle2: float = -PI / 2;

    geometry := New(Geometry);
    vertices: [..] Vector3;
    normals: [..] Vector3;
    tex_coords: [..] Vector2;
    indices: [..] u32;

    // compute the first 12 vertices that start the icosahedron
    temp_vertices: [..] Vector3;

    array_resize(*temp_vertices, 12);
    temp_vertices[0].x = 0.0;
    temp_vertices[0].y = 0.0;
    temp_vertices[0].z = radius;

    for i: 1..5 {
        i1 := i;
        i2 := i + 5;

        z := radius * sin(V_ANGLE);
        xy := radius * cos(V_ANGLE);

        temp_vertices[i1].x = xy * cos(hAngle1);
        temp_vertices[i2].x = xy * cos(hAngle2);
        temp_vertices[i1].y = xy * sin(hAngle1);
        temp_vertices[i2].y = xy * sin(hAngle2);
        temp_vertices[i1].z = z;
        temp_vertices[i2].z = -z;

        hAngle1 += H_ANGLE;
        hAngle2 += H_ANGLE;
    }

    temp_vertices[11].x = 0.0;
    temp_vertices[11].y = 0.0;
    temp_vertices[11].z = -radius;

    // compute the flat vertices for the flat shading
    v0 := temp_vertices[0];
    v11 := temp_vertices[11];

    index: u32;

    for i: 1..5 {
        v1 := temp_vertices[i];
        v2: Vector3;
        if i < 5 {
            v2 = temp_vertices[i + 1];
        } else {
            v2 = temp_vertices[1];
        }

        v3 := temp_vertices[i + 5];
        v4: Vector3;
        if i + 5 < 10 {
            v4 = temp_vertices[i + 6];
        } else {
            v4 = temp_vertices[6];
        }

        t0 := xy((2 * i - 1) * S_STEP, 0.0);
        t1 := xy((2 * i - 2) * S_STEP, T_STEP);
        t2 := xy(2 * i * S_STEP, T_STEP);
        t3 := xy((2 * i - 1) * S_STEP, T_STEP * 2);
        t4 := xy((2 * i + 1) * S_STEP, T_STEP * 2);
        t11 := xy(2 * i * S_STEP, T_STEP * 3);

        n := compute_face_normal(v0, v1, v2);
        array_add(*vertices, v0, v1, v2);
        array_add(*normals, n, n, n);
        array_add(*tex_coords, t0, t1, t2);
        array_add(*indices, index, index + 1, index + 2);

        n = compute_face_normal(v1, v3, v2);
        array_add(*vertices, v1, v3, v2);
        array_add(*normals, n, n, n);
        array_add(*tex_coords, t1, t3, t2);
        array_add(*indices, index + 3, index + 4, index + 5);

        n = compute_face_normal(v2, v3, v4);
        array_add(*vertices, v2, v3, v4);
        array_add(*normals, n, n, n);
        array_add(*tex_coords, t2, t3, t4);
        array_add(*indices, index + 6, index + 7, index + 8);

        // add a triangle in 3rd row
        n = compute_face_normal(v3, v11, v4);
        array_add(*vertices, v3, v11, v4);
        array_add(*normals, n, n, n);
        array_add(*tex_coords, t3, t11, t4);
        array_add(*indices, index + 9, index + 10, index + 11);

        index += 12;
    }

    for i: 1..subdivision {
        temp_vertices: [..] Vector3;
        temp_tex_coords: [..] Vector2;
        temp_indices: [..] u32;
        defer array_free(temp_vertices);
        defer array_free(temp_tex_coords);
        defer array_free(temp_indices);
        array_copy(*temp_vertices, vertices);
        array_copy(*temp_tex_coords, tex_coords);
        array_copy(*temp_indices, indices);

        vertices.count = 0;
        normals.count = 0;
        tex_coords.count = 0;
        indices.count = 0;

        index = 0;

        j := 0;
        while j < temp_indices.count {
            defer j += 3;
            
            v1 := temp_vertices[temp_indices[j]];
            v2 := temp_vertices[temp_indices[j + 1]];
            v3 := temp_vertices[temp_indices[j + 2]];
            t1 := temp_tex_coords[temp_indices[j]];
            t2 := temp_tex_coords[temp_indices[j + 1]];
            t3 := temp_tex_coords[temp_indices[j + 2]];

            newV1 := compute_half_vertex(v1, v2, radius);
            newV2 := compute_half_vertex(v2, v3, radius);
            newV3 := compute_half_vertex(v1, v3, radius);
            newT1 := compute_half_tex_coord(t1, t2);
            newT2 := compute_half_tex_coord(t2, t3);
            newT3 := compute_half_tex_coord(t1, t3);

            normal := compute_face_normal(v1, newV1, newV3);
            array_add(*vertices, v1, newV1, newV3);
            array_add(*normals, normal, normal, normal);
            array_add(*tex_coords, t1, newT1, newT3);
            array_add(*indices, index, index + 1, index + 2);

            normal = compute_face_normal(newV1, v2, newV2);
            array_add(*vertices, newV1, v2, newV2);
            array_add(*normals, normal, normal, normal);
            array_add(*tex_coords, newT1, t2, newT2);
            array_add(*indices, index + 3, index + 4, index + 5);

            normal = compute_face_normal(newV1, newV2, newV3);
            array_add(*vertices, newV1, newV2, newV3);
            array_add(*normals, normal, normal, normal);
            array_add(*tex_coords, newT1, newT2, newT3);
            array_add(*indices, index + 6, index + 7, index + 8);

            normal = compute_face_normal(newV3, newV2, v3);
            array_add(*vertices, newV3, newV2, v3);
            array_add(*normals, normal, normal, normal);
            array_add(*tex_coords, newT3, newT2, t3);
            array_add(*indices, index + 9, index + 10, index + 11);

            index += 12;
        }
    }

    stride := 3;
    if with_normals {
        stride += 3;
    }
    if with_texcoords {
        stride += 2;
    }

    offset := 0;

    assert(vertices.count == normals.count && vertices.count == tex_coords.count, "Must have the same amount of all things.");
    array_copy(*geometry.indices, indices);
    array_resize(*geometry.vertices, vertices.count * stride);
    for i: 0..vertices.count - 1 {
        vertex := vertices[i];
        normal := normals[i];
        tex_coord := tex_coords[i];

        geometry.vertices[offset] = vertex.x;
        geometry.vertices[offset + 1] = vertex.y;
        geometry.vertices[offset + 2] = vertex.z;
        offset += 3;
        
        if with_normals {
            geometry.vertices[offset] = normal.x;
            geometry.vertices[offset + 1] = normal.y;
            geometry.vertices[offset + 2] = normal.z;
            offset += 3;
        }
        
        if with_texcoords {
            geometry.vertices[offset] = tex_coord.x;
            geometry.vertices[offset + 1] = tex_coord.y;
            offset += 2;
        }
    }

    add_attribute(*geometry, .Position);
    if with_normals {
        add_attribute(*geometry, .Normal);
    }
    if with_texcoords {
        add_attribute(*geometry, .Texcoord);
    }

    // print("genning %\n", geometry, << geometry);
    gen_geometry(geometry);

    return geometry;
}

create_uv_sphere :: (radius: float, subdivisions: int, with_normals: bool = false, with_texcoords: bool = false) -> *Geometry {
    geometry := New(Geometry);

    assert(!with_normals, "Normals not yet supported for this geometry.");

    stride := 3;
    if with_normals {
        stride += 3;
    }
    if with_texcoords {
        stride += 2;
    }

    array_reserve(*geometry.vertices, subdivisions * subdivisions * stride);
    array_reserve(*geometry.indices, (subdivisions - 1) * (subdivisions - 1) * 6);

    for i: 0..subdivisions {
        theta := i * PI / subdivisions;
        sin_theta := sin(theta);
        cos_theta := cos(theta);

        for j: 0..subdivisions {
            phi := j * 2 * PI / subdivisions;
            sin_phi := sin(phi);
            cos_phi := cos(phi);

            x := radius * sin_theta * cos_phi;
            y := radius * cos_theta;
            z := -radius * sin_theta * sin_phi;

            array_add(*geometry.vertices, x, y, z);

            if with_texcoords {
                tx := cast(float) j / subdivisions;
                ty := cast(float) i / subdivisions;

                array_add(*geometry.vertices, tx, ty);
            }
        }
    }

    for i: 0..subdivisions - 1 {
        for j: 0..subdivisions - 1 {
            first := cast(u32) (i * (subdivisions + 1) + j);
            second := cast(u32) (first + subdivisions + 1);

            array_add(*geometry.indices, first, second, first + 1);
            array_add(*geometry.indices, second, second + 1, first + 1);
        }
    }

    add_attribute(geometry, .Position);
    if with_normals {
        add_attribute(geometry, .Normal);
    }
    if with_texcoords {
        add_attribute(geometry, .Texcoord);
    }

    gen_geometry(geometry);

    return geometry;
}

#scope_file

// arr :: (a: $T, b: T, c: T) -> [3] T {

// }

// array_add :: (array: *[..] $T, entries: [] T) {
//     // if I really wanted to I could do this smarter like manually resizing the array
//     for entry: entries { 
//         array_add(array, entry);
//     }
// }