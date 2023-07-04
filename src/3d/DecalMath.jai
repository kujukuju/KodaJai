
get_decal_vertices :: (vertices: *[..] float32, indices: *[..] u32, triangle: [3] Vector3, normals: [3] Vector3, colors: [3] Vector4, uv_range: [2] Vector2, decal_position: Vector3, decal_rotation: Quaternion, decal_width: float, decal_height: float, decal_depth: float) {
    transform := Matrix4;
    transform := translate(transform, decal_position);
    transform := rotate(transform, decal_rotation);
    transform := scale(transform, Vector3.{decal_width, decal_height, decal_depth});

    inline get_decal_vertices(vertuces, indices, triangle, normals, colors, uv_range, transform);
}

get_decal_vertices :: (vertices: *[..] float32, indices: *[..] u32, triangle: [3] Vector3, normals: [3] Vector3, colors: [3] Vector4, uv_range: [2] Vector2, transform: Matrix4) {
    inverted_transform := inverse(decal_transform);

    inline get_decal_vertices(vertices, indices, triangle, normals, colors, uv_range, transform, inverted_transform);
}

get_decal_vertices :: (vertices: *[..] float32, indices: *[..] u32, world_triangle: [3] Vector3, world_normals: [3] Vector3, colors: [3] Vector4, uv_range: [2] Vector2, transform: Matrix4, inverted_transform: Matrix4) {
    // this method actually clips the triangles, but I suepect it ends up creating a lot more triangles than if we were to just copy intersecting triangles

    // we'll assume the decal is a cube that's perfectly axis aligned, with all dimensions being 1
    // and we'll transform the triangle into this perspective
    // and clip the triangle vertices here
    // and then transform the newly clipped triangle back into the correct alignment

    copy_normals :: true;
    copy_colors :: true;
    assert(copy_normals && copy_colors, "Non-copy operations not yet supported but started.");

    transformed_triangle: [3] Vector3 = ---;
    transformed_triangle[0] = transform_point(inverted_transform, world_triangle[0]);
    transformed_triangle[1] = transform_point(inverted_transform, world_triangle[1]);
    transformed_triangle[2] = transform_point(inverted_transform, world_triangle[2]);

    transformed_normals: [3] Vector3 = ---;
    transformed_normals[0] = transform_vector(inverted_transform, world_normals[0]);
    transformed_normals[1] = transform_vector(inverted_transform, world_normals[1]);
    transformed_normals[2] = transform_vector(inverted_transform, world_normals[2]);

    // conditions are
    // both points inside the triangle, keep it
    // neither point inside the triangle, skip it entirely
    // only one point inside the triangle

    // basically we want to start at any random point
    // if its inside the cube we add it
    // we check if the current triangle line ever exits the cube
    // if so we calculate the intersection and add it
    // then we continue towards the vertex, and if its inside the cube we add it
    // and repeat

    // I think whatever shape is generated is guaranteed to be convex so we can just split it up from there into a simple triangle fan
    // if no points were ever added we add the entire intersection with the cube because the triangle encompasses the entire cube

    // if you re enter the cube from being outside, you have to add in all intersections of the cube along the way between the lines?

    // so actually I think you just want to clip all existing triangles to each of the 6 planes
    
    // and as a pre pass it might be more optimal to start by clipping each triangle using each of the 12 edges?
    // because this will potentially result in fewer total triangles, but I think its more expensive

    // so I guess for now I will just clip all triangles to all 6 planes

    planes: [6] Plane3 : .[
        #run create_plane3(.{-0.5, 0.0, 0.0}, .{-1.0, 0.0, 0.0}),
        #run create_plane3(.{0.5, 0.0, 0.0}, .{1.0, 0.0, 0.0}),
        #run create_plane3(.{0.0, -0.5, 0.0}, .{0.0, -1.0, 0.0}),
        #run create_plane3(.{0.0, 0.5, 0.0}, .{0.0, 1.0, 0.0}),
        #run create_plane3(.{0.0, 0.0, -0.5}, .{0.0, 0.0, -1.0}),
        #run create_plane3(.{0.0, 0.0, 0.5}, .{0.0, 0.0, 1.0}),
    ];

    TriangleEntry :: struct {
        vertices: [3] Vector3;
        normals: [3] Vector3;
        colors: [3] Vector4;
        texcoords: [3] Vector2;
    }

    current_triangles: [..] TriangleEntry;
    current_triangles.allocator = temp;

    generated_triangles: [..] TriangleEntry;
    generated_triangles.allocator = temp;

    uv_size := uv_range[1] - uv_range[0];

    first_entry := array_add(*current_triangles);
    first_entry.vertices = transformed_triangle;
    first_entry.normals = transformed_normals;
    first_entry.colors = colors;
    first_entry.texcoords[0].x = (transformed_triangle[0].x + 0.5) * uv_size.x + uv_range[0].x;
    first_entry.texcoords[0].y = (transformed_triangle[0].y + 0.5) * uv_size.y + uv_range[0].y;
    first_entry.texcoords[1].x = (transformed_triangle[1].x + 0.5) * uv_size.x + uv_range[0].x;
    first_entry.texcoords[1].y = (transformed_triangle[1].y + 0.5) * uv_size.y + uv_range[0].y;
    first_entry.texcoords[2].x = (transformed_triangle[2].x + 0.5) * uv_size.x + uv_range[0].x;
    first_entry.texcoords[2].y = (transformed_triangle[2].y + 0.5) * uv_size.y + uv_range[0].y;

    // we only want the parts of the triangle that are under each plane
    for plane: planes {
        for triangle: current_triangles {
            if outside(plane, triangle.vertices[0]) {
                if outside(plane, triangle.vertices[1]) {
                    if inside(plane, triangle.vertices[2]) {
                        // only c is inside
                        // we explicitly check the c case because if nothing is inside we throw away the triangle
                        clip_a, perc_a := intersection_simple(plane, Ray3.{triangle.vertices[2], triangle.vertices[0] - triangle.vertices[2]});
                        clip_b, perc_b := intersection_simple(plane, Ray3.{triangle.vertices[2], triangle.vertices[1] - triangle.vertices[2]});
                        clipped_triangle: TriangleEntry = ---;
                        clipped_triangle.vertices[0] = clip_a;
                        clipped_triangle.vertices[1] = clip_b;
                        clipped_triangle.vertices[2] = triangle.vertices[2];

                        #if copy_normals {
                            clipped_triangle.normals = triangle.normals;
                        } else {
                            // normal_progress_a := length(triangle.vertices[0] - triangle.vertices[2]) / length(triangle.clipped_triangle[0] - triangle.clipped_triangle[2]);
                            // clipped_triangle.normals[0] = normalize(normal_progress_a * (triangle.normals[0] - triangle.normals[2]) + triangle.normals[2]);
                        }

                        #if copy_colors {
                            clipped_triangle.colors = triangle.colors;
                        }

                        clipped_triangle.texcoords[0] = perc_a * (triangle.texcoords[0] - triangle.texcoords[2]) + triangle.texcoords[2];
                        clipped_triangle.texcoords[1] = perc_b * (triangle.texcoords[1] - triangle.texcoords[2]) + triangle.texcoords[2];
                        clipped_triangle.texcoords[2] = triangle.texcoords[2];

                        array_add(*generated_triangles, clipped_triangle);
                    }
                } else if outside(plane, triangle.vertices[2]) {
                    // only b is inside
                    clip_a, perc_a := intersection_simple(plane, Ray3.{triangle.vertices[1], triangle.vertices[0] - triangle.vertices[1]});
                    clip_c, perc_c := intersection_simple(plane, Ray3.{triangle.vertices[1], triangle.vertices[2] - triangle.vertices[1]});
                    clipped_triangle: TriangleEntry = ---;
                    clipped_triangle.vertices[0] = clip_a;
                    clipped_triangle.vertices[1] = triangle.vertices[1];
                    clipped_triangle.vertices[2] = clip_c;

                    #if copy_normals {
                        clipped_triangle.normals = triangle.normals;
                    }

                    #if copy_colors {
                        clipped_triangle.colors = triangle.colors;
                    }

                    clipped_triangle.texcoords[0] = perc_a * (triangle.texcoords[0] - triangle.texcoords[1]) + triangle.texcoords[1];
                    clipped_triangle.texcoords[1] = triangle.texcoords[1];
                    clipped_triangle.texcoords[2] = perc_c * (triangle.texcoords[2] - triangle.texcoords[1]) + triangle.texcoords[1];

                    array_add(*generated_triangles, clipped_triangle);
                } else {
                    // b and c are both inside
                    clip_l, perc_l := intersection_simple(plane, Ray3.{triangle.vertices[1], triangle.vertices[0] - triangle.vertices[1]});
                    clip_r, perc_r := intersection_simple(plane, Ray3.{triangle.vertices[2], triangle.vertices[0] - triangle.vertices[2]});

                    clipped_triangle_l: TriangleEntry = ---;
                    clipped_triangle_l.vertices[0] = clip_l;
                    clipped_triangle_l.vertices[1] = triangle.vertices[1];
                    clipped_triangle_l.vertices[2] = clip_r;

                    clipped_triangle_r: TriangleEntry = ---;
                    clipped_triangle_r.vertices[0] = clip_r;
                    clipped_triangle_r.vertices[1] = triangle.vertices[1];
                    clipped_triangle_r.vertices[2] = triangle.vertices[2];

                    #if copy_normals {
                        clipped_triangle_l.normals = triangle.normals;
                        clipped_triangle_r.normals = triangle.normals;
                    }

                    #if copy_colors {
                        clipped_triangle_l.colors = triangle.colors;
                        clipped_triangle_r.colors = triangle.colors;
                    }

                    clipped_triangle_l.texcoords[0] = perc_l * (triangle.texcoords[0] - triangle.texcoords[1]) + triangle.texcoords[1];
                    clipped_triangle_l.texcoords[1] = triangle.texcoords[1];
                    clipped_triangle_l.texcoords[2] = perc_r * (triangle.texcoords[0] - triangle.texcoords[2]) + triangle.texcoords[2];

                    clipped_triangle_r.texcoords[0] = perc_r * (triangle.texcoords[0] - triangle.texcoords[2]) + triangle.texcoords[2];
                    clipped_triangle_r.texcoords[1] = triangle.texcoords[1];
                    clipped_triangle_r.texcoords[2] = triangle.texcoords[2];

                    array_add(*generated_triangles, clipped_triangle_l);
                    array_add(*generated_triangles, clipped_triangle_r);
                }
            } else if outside(plane, triangle.vertices[1]) {
                // we could remove the only c case because its covered above
                if outside(plane, triangle.vertices[2]) {
                    // only a is inside
                    clip_b, perc_b := intersection_simple(plane, Ray3.{triangle.vertices[0], triangle.vertices[1] - triangle.vertices[0]});
                    clip_c, perc_c := intersection_simple(plane, Ray3.{triangle.vertices[0], triangle.vertices[2] - triangle.vertices[0]});

                    clipped_triangle: TriangleEntry = ---;
                    clipped_triangle.vertices[0] = triangle.vertices[0];
                    clipped_triangle.vertices[1] = clip_b;
                    clipped_triangle.vertices[2] = clip_c;

                    #if copy_normals {
                        clipped_triangle.normals = triangle.normals;
                    }

                    #if copy_colors {
                        clipped_triangle.colors = triangle.colors;
                    }

                    clipped_triangle.texcoords[0] = triangle.texcoords[0];
                    clipped_triangle.texcoords[1] = perc_b * (triangle.texcoords[1] - triangle.texcoords[0]) + triangle.texcoords[0];
                    clipped_triangle.texcoords[2] = perc_c * (triangle.texcoords[2] - triangle.texcoords[0]) + triangle.texcoords[0];

                    array_add(*generated_triangles, clipped_triangle);
                } else {
                    // a and c are both inside
                    clip_l, perc_l := intersection_simple(plane, Ray3.{triangle.vertices[2], triangle.vertices[1] - triangle.vertices[2]});
                    clip_r, perc_r := intersection_simple(plane, Ray3.{triangle.vertices[0], triangle.vertices[1] - triangle.vertices[0]});

                    clipped_triangle_l: TriangleEntry = ---;
                    clipped_triangle_l.vertices[0] = clip_r;
                    clipped_triangle_l.vertices[1] = clip_l;
                    clipped_triangle_l.vertices[2] = triangle.vertices[2];

                    clipped_triangle_r: TriangleEntry = ---;
                    clipped_triangle_r.vertices[0] = triangle.vertices[0];
                    clipped_triangle_r.vertices[1] = clip_r;
                    clipped_triangle_r.vertices[2] = triangle.vertices[2];

                    #if copy_normals {
                        clipped_triangle_l.normals = triangle.normals;
                        clipped_triangle_r.normals = triangle.normals;
                    }

                    #if copy_colors {
                        clipped_triangle_l.colors = triangle.colors;
                        clipped_triangle_r.colors = triangle.colors;
                    }

                    clipped_triangle_l.texcoords[0] = perc_r * (triangle.texcoords[1] - triangle.texcoords[0]) + triangle.texcoords[0];
                    clipped_triangle_l.texcoords[1] = perc_l * (triangle.texcoords[1] - triangle.texcoords[2]) + triangle.texcoords[2];
                    clipped_triangle_l.texcoords[2] = triangle.texcoords[2];

                    clipped_triangle_r.texcoords[0] = triangle.texcoords[0];
                    clipped_triangle_r.texcoords[1] = perc_r * (triangle.texcoords[1] - triangle.texcoords[0]) + triangle.texcoords[0];
                    clipped_triangle_r.texcoords[2] = triangle.texcoords[2];

                    array_add(*generated_triangles, clipped_triangle_l);
                    array_add(*generated_triangles, clipped_triangle_r);
                }
            } else if outside(plane, triangle.vertices[2]) {
                // we could remove the only b case because its covered above
                // we could remove the only a case because its covered above
                // so a and b are both inside
                clip_l, perc_l := intersection_simple(plane, Ray3.{triangle.vertices[0], triangle.vertices[2] - triangle.vertices[0]});
                clip_r, perc_r := intersection_simple(plane, Ray3.{triangle.vertices[1], triangle.vertices[2] - triangle.vertices[1]});

                clipped_triangle_l: TriangleEntry = ---;
                clipped_triangle_l.vertices[0] = triangle.vertices[0];
                clipped_triangle_l.vertices[1] = clip_r;
                clipped_triangle_l.vertices[2] = clip_l;

                clipped_triangle_r: TriangleEntry = ---;
                clipped_triangle_r.vertices[0] = triangle.vertices[0];
                clipped_triangle_r.vertices[1] = triangle.vertices[1];
                clipped_triangle_r.vertices[2] = clip_r;

                #if copy_normals {
                    clipped_triangle_l.normals = triangle.normals;
                    clipped_triangle_r.normals = triangle.normals;
                }

                #if copy_colors {
                    clipped_triangle_l.colors = triangle.colors;
                    clipped_triangle_r.colors = triangle.colors;
                }

                clipped_triangle_l.texcoords[0] = triangle.texcoords[0];
                clipped_triangle_l.texcoords[1] = perc_r * (triangle.texcoords[2] - triangle.texcoords[1]) + triangle.texcoords[1];
                clipped_triangle_l.texcoords[2] = perc_l * (triangle.texcoords[2] - triangle.texcoords[0]) + triangle.texcoords[0];

                clipped_triangle_r.texcoords[0] = triangle.texcoords[0];
                clipped_triangle_r.texcoords[1] = triangle.texcoords[1];
                clipped_triangle_r.texcoords[2] = perc_r * (triangle.texcoords[2] - triangle.texcoords[1]) + triangle.texcoords[1];

                array_add(*generated_triangles, clipped_triangle_l);
                array_add(*generated_triangles, clipped_triangle_r);
            } else {
                // the entire triangle is within the plane, so keep it
                array_add(*generated_triangles, triangle);
            }
        }

        // for each plane we swap and reset the generated triangles
        current_triangles, generated_triangles = swap(current_triangles, generated_triangles);
        generated_triangles.count = 0;
    }

    expected_stride :: 3 + 3 + 2 + 4;

    for triangle: current_triangles {
        for vertex_index: 0..2 {
            current_index := vertices.count / expected_stride;

            vertex := triangle.vertices[vertex_index];
            normal := triangle.normals[vertex_index];
            texcoord := triangle.texcoords[vertex_index];
            color := triangle.colors[vertex_index];

            world_vertex := transform_point(transform, vertex);
            world_normal := transform_vector(transform, normal);

            array_add(vertices, ..world_vertex.component);
            array_add(vertices, ..world_normal.component);
            array_add(vertices, ..texcoord.component);
            array_add(vertices, ..color.component);

            array_add(indices, xx current_index);
        }
    }
}

add_decal_vertices :: (vertices: *[..] float32, indices: *[..] u32, world_triangle: [3] Vector3, world_normals: [3] Vector3, colors: [3] Vector4, uv_range: [2] Vector3, inverted_transform: Matrix4) {
    triangle: Triangle3 = ---;
    triangle.a = inline transform_point(inverted_transform, world_triangle[0]);
    triangle.b = inline transform_point(inverted_transform, world_triangle[1]);
    triangle.c = inline transform_point(inverted_transform, world_triangle[2]);

    uv_size := uv_range[1] - uv_range[0];

    texcoords: [3] Vector3 = ---;
    texcoords[0].x = (triangle.a.x + 0.5) * uv_size.x + uv_range[0].x;
    texcoords[0].y = (triangle.a.y + 0.5) * uv_size.y + uv_range[0].y;
    texcoords[0].z = (triangle.a.z + 0.5) * uv_size.z + uv_range[0].z;
    texcoords[1].x = (triangle.b.x + 0.5) * uv_size.x + uv_range[0].x;
    texcoords[1].y = (triangle.b.y + 0.5) * uv_size.y + uv_range[0].y;
    texcoords[1].z = (triangle.b.z + 0.5) * uv_size.z + uv_range[0].z;
    texcoords[2].x = (triangle.c.x + 0.5) * uv_size.x + uv_range[0].x;
    texcoords[2].y = (triangle.c.y + 0.5) * uv_size.y + uv_range[0].y;
    texcoords[2].z = (triangle.c.z + 0.5) * uv_size.z + uv_range[0].z;

    aabb :: AABB3.{.{-0.5, -0.5, -0.5}, .{0.5, 0.5, 0.5}};

    // this thing expects vec3 texcoords
    expected_stride :: 3 + 3 + 3 + 4;
    add_vertices :: expected_stride * 3;
    memcpy_size :: expected_stride * size_of(float);

    vertex_entries: [expected_stride] float = ---;

    // were going to force the vertex array to be a minimum allocated size of like 1024
    // this way we can assume we don't have to resize individually ever
    if vertices.allocated < 1024 * expected_stride {
        inline array_reserve(vertices, 1024 * expected_stride);
    }

    if vertices.count + add_vertices > vertices.allocated {
        inline array_reserve(vertices, vertices.allocated * 2);
    }

    if inline intersects(aabb, triangle) {
        for vertex_index: 0..2 {
            current_index := cast(u32) vertices.count / expected_stride;

            vertex_entries[0] = world_triangle[vertex_index].x;
            vertex_entries[1] = world_triangle[vertex_index].y;
            vertex_entries[2] = world_triangle[vertex_index].z;
            vertex_entries[3] = world_normals[vertex_index].x;
            vertex_entries[4] = world_normals[vertex_index].y;
            vertex_entries[5] = world_normals[vertex_index].z;
            vertex_entries[6] = texcoords[vertex_index].x;
            vertex_entries[7] = texcoords[vertex_index].y;
            vertex_entries[8] = texcoords[vertex_index].z;
            vertex_entries[9] = colors[vertex_index].x;
            vertex_entries[10] = colors[vertex_index].y;
            vertex_entries[11] = colors[vertex_index].z;
            vertex_entries[12] = colors[vertex_index].w;

            memcpy(vertices.data + vertices.count, vertex_entries.data, memcpy_size);
            vertices.count += expected_stride;

            // inline array_add(vertices, ..vertex_entries);

            // vertex := world_triangle[vertex_index];
            // normal := world_normals[vertex_index];
            // texcoord := texcoords[vertex_index];
            // color := colors[vertex_index];

            // array_add(vertices, ..vertex.component);
            // array_add(vertices, ..normal.component);
            // array_add(vertices, ..texcoord.component);
            // array_add(vertices, ..color.component);

            inline array_add(indices, current_index);
        }
    }
}
