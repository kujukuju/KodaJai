
get_aabb :: (models: [] *Model) -> AABB2 {
    aabb: AABB2;
    aabb_set := false;
    for model: models {
        print("model %\n", model);
        for vertex: get_vertices(model) {
            if !aabb_set {
                aabb_set = true;

                aabb.lower = .{vertex.x, vertex.z};
                aabb.upper = .{vertex.x, vertex.z};
            } else {
                aabb.lower = min(aabb.lower, .{vertex.x, vertex.z});
                aabb.upper = max(aabb.upper, .{vertex.x, vertex.z});
            }
        }
    }

    return aabb;
}

create_sdf_image :: (model_aabb: AABB2, pixel_units: float, format: PixelFormat, $sample: (position: Vector2, data: $T) -> Color, data: T) -> Image, AABB2, Vector2 {
    aabb := model_aabb;
    dimensions := aabb.upper - aabb.lower;
    width := cast(int) round(dimensions.x / pixel_units);
    height := cast(int) round(dimensions.y / pixel_units);

    // the number of units actually inside a given pixel after rounding
    width_units := dimensions.x / width;
    height_units := dimensions.y / height;

    width += 2;
    height += 2;

    aabb.lower.x -= width_units;
    aabb.lower.y -= height_units;
    aabb.upper.x += width_units;
    aabb.upper.y += height_units;
    dimensions = aabb.upper - aabb.lower;

    assert(abs(width_units - dimensions.x / width) < 0.00001);
    assert(abs(height_units - dimensions.y / height) < 0.00001);

    image := create_image(width, height, format);

    for y: 0..image.height - 1 {
        for x: 0..image.width - 1 {
            index := x + y * image.width;

            position := aabb.lower;
            position += Vector2.{x + 0.5, y + 0.5} * Vector2.{width_units, height_units};

            color := sample(position, data);

            draw_pixel(*image, .{x, y}, color);
        }
    }

    return image, aabb, Vector2.{width_units, height_units};
}

create_sdf_image :: (model_aabb: AABB3, pixel_units: float, format: PixelFormat, $sample: (position: Vector3, data: $T) -> Color, data: T, $parallel: bool = false, $print_progress: bool = false) -> Image3, AABB3, Vector3 {
    aabb := model_aabb;
    dimensions := aabb.upper - aabb.lower;
    width := cast(int) round(dimensions.x / pixel_units);
    height := cast(int) round(dimensions.y / pixel_units);
    depth := cast(int) round(dimensions.z / pixel_units);

    // the number of units actually inside a given pixel after rounding
    width_units := dimensions.x / width;
    height_units := dimensions.y / height;
    depth_units := dimensions.z / depth;

    width += 2;
    height += 2;
    depth += 2;

    aabb.lower.x -= width_units;
    aabb.lower.y -= height_units;
    aabb.lower.z -= depth_units;
    aabb.upper.x += width_units;
    aabb.upper.y += height_units;
    aabb.upper.z += depth_units;
    dimensions = aabb.upper - aabb.lower;

    assert(abs(width_units - dimensions.x / width) < 0.00001, "Invalid width units. % %\n", width_units, dimensions.x / width);
    assert(abs(height_units - dimensions.y / height) < 0.00001, "Invalid height units. % %\n", height_units, dimensions.y / height);
    assert(abs(depth_units - dimensions.z / depth) < 0.00001, "Invalid depth units. % %\n", depth_units, dimensions.z / depth);

    image := create_image3(width, height, depth, format);

    #if parallel {
        parallel_for(0, image.depth, (z: int, thread: int, using data: struct {
            image: *Image3;
            aabb: AABB3;
            width_units: float;
            height_units: float;
            depth_units: float;
            sample_data: T;
        }) {
            if thread == 0 && print_progress {
                print("Sdf progress: % / %\n", z * get_thread_count() + 1, image.depth);
            }

            for y: 0..image.height - 1 {
                for x: 0..image.width - 1 {
                    index := x + y * image.width + z * image.width * image.height;

                    position := aabb.lower;
                    position += Vector3.{x + 0.5, y + 0.5, z + 0.5} * Vector3.{width_units, height_units, depth_units};

                    color := sample(position, sample_data);

                    draw_pixel(image, .{x, y, z}, color);
                }
            }
        }, .{
            *image,
            aabb,
            width_units,
            height_units,
            depth_units,
            data,
        });
    } else {
        for z: 0..image.depth - 1 {
            if print_progress {
                print("Sdf progress: % / %\n", z + 1, image.depth);
            }

            for y: 0..image.height - 1 {
                for x: 0..image.width - 1 {
                    index := x + y * image.width + z * image.width * image.height;

                    position := aabb.lower;
                    position += Vector3.{x + 0.5, y + 0.5, z + 0.5} * Vector3.{width_units, height_units, depth_units};

                    color := sample(position, data);

                    draw_pixel(*image, .{x, y, z}, color);
                }
            }
        }
    }


    return image, aabb, Vector3.{width_units, height_units, depth_units};
}

// TODO this should reuse the above function, but in 3d
create_sdf_image :: (models: [] *Model, pixel_units: float) -> Image3, AABB3, Vector3 {
    // validity check
    for model: models {
        geometry := model.geometry;

        assert(geometry.attributes.count == 1, "Sdf models must have only one position attribute.\n");
        assert(geometry.attributes[0] == .Position, "Sdf models must have a position attribute.\n");

        geometry_vertices: [] Vector3;

        geometry_vertices.data = cast(*Vector3) geometry.vertices.data;
        geometry_vertices.count = geometry.vertices.count / 3;
        assert(detect_convex_hull(geometry_vertices, geometry.indices), "Sdf models must be convex.\n");
    }

    // calculate aabb
    aabb: AABB3;
    aabb_set := false;
    for model: models {
        for vertex: get_vertices(model) {
            if !aabb_set {
                aabb_set = true;

                aabb.lower = vertex;
                aabb.upper = vertex;
            } else {
                aabb.lower = min(aabb.lower, vertex);
                aabb.upper = max(aabb.upper, vertex);
            }
        }
    }

    dimensions := aabb.upper - aabb.lower;
    width := cast(int) round(dimensions.x / pixel_units);
    height := cast(int) round(dimensions.y / pixel_units);
    depth := cast(int) round(dimensions.z / pixel_units);

    // the number of units actually inside a given pixel after rounding
    width_units := dimensions.x / width;
    height_units := dimensions.y / height;
    depth_units := dimensions.z / depth;

    width += 2;
    height += 2;
    depth += 2;

    aabb.lower.x -= width_units;
    aabb.lower.y -= height_units;
    aabb.lower.z -= depth_units;
    aabb.upper.x += width_units;
    aabb.upper.y += height_units;
    aabb.upper.z += depth_units;
    dimensions = aabb.upper - aabb.lower;

    assert(abs(width_units - dimensions.x / width) < 0.00001);
    assert(abs(height_units - dimensions.y / height) < 0.00001);
    assert(abs(depth_units - dimensions.z / depth) < 0.00001);

    model_tree := create_bounding_tree(*Model);
    defer free_bounding_tree(model_tree);
    for model: models {
        world_aabb := get_aabb(model);

        create_proxy(*model_tree, world_aabb, model);
    }

    image := create_image3(width, height, depth, .R8);

    for z: 0..image.depth - 1 {
        for y: 0..image.height - 1 {
            for x: 0..image.width - 1 {
                index := x + y * image.width + z * image.width * image.height;

                position := aabb.lower;
                position += Vector3.{x + 0.5, y + 0.5, z + 0.5} * Vector3.{width_units, height_units, depth_units};

                smallest_sdf_distance := FLOAT32_MAX;
                radius := 0.0;
                while smallest_sdf_distance == FLOAT32_MAX {
                    query_aabb := AABB3.{position, position};
                    query_aabb.lower -= radius;
                    query_aabb.upper += radius;

                    for model: query(*model_tree, query_aabb) {
                        nearest_distance_squared := FLOAT32_MAX;
                        nearest_triangle: Triangle3;
                        for triangle: get_triangles(model) {
                            point := nearest_point(triangle, position);

                            current_distance_squared := distance_squared(point, position);
                            if current_distance_squared < nearest_distance_squared {
                                nearest_distance_squared = current_distance_squared;
                                nearest_triangle = triangle;
                            }
                        }

                        if nearest_distance_squared < FLOAT32_MAX {
                            normal := get_normal(nearest_triangle);
                            outside := dot(normal, position - nearest_triangle.a) > 0.00001;

                            sdf_distance := sqrt(nearest_distance_squared);
                            sdf_distance *= ifx outside then 1 else -1;

                            if sdf_distance < smallest_sdf_distance {
                                smallest_sdf_distance = sdf_distance;
                            }
                        }
                    }

                    radius += pixel_units;
                }

                // the sdf byte value goes between [-pixel_units, pixel_units] from [0, 255]
                byte_sdf_distance := (smallest_sdf_distance + pixel_units) / (pixel_units * 2);
                byte_sdf_distance = clamp(byte_sdf_distance, 0, 1);
                byte_sdf_distance = min(byte_sdf_distance * 256, 255);

                image.pixels[index] = cast(u8) byte_sdf_distance;
            }
        }
    }

    return image, aabb, Vector3.{width_units, height_units, depth_units};
}

#scope_file

// copied from koda physics
detect_convex_hull :: (vertices: [] Vector3, indices: [] $I) -> bool {
    // 1. each edge must have 2 triangles
    // 2. the dot product of the normal of each 2 adjacent triangles must be negative (pointing away from each other)

    EPSILON :: 0.0001;

    Edge :: struct {
        v1: Vector3;
        v2: Vector3;
    }

    EdgeTriangles :: struct {
        edge_triangles: [2] Triangle3;
        // edge_normals: [2] Vector3;
        edge_triangle_bits: u8;
    }

    hash_function :: inline (edge: Edge) -> u32 {
        values: [] u32;
        values.data = xx *edge.v1;
        values.count = 6;

        hash: u32;
        for value: values {
            hash ^= value;
        }

        return hash;
    }

    compare_function :: inline (e1: Edge, e2: Edge) -> bool {
        return e1.v1 == e2.v1 && e1.v2 == e2.v2;
    }

    equalish :: inline (t1: Triangle3, t2: Triangle3) -> bool {
        // if we can find all 3 points somewhere on the other triangle we can assume the triangles are equal regardless of order
        // its either this, or one of the triangles is a line
        matches := true;
        matches = matches && (t1.a == t2.a || t1.a == t2.b || t1.a == t2.c);
        matches = matches && (t1.b == t2.a || t1.b == t2.b || t1.b == t2.c);
        matches = matches && (t1.c == t2.a || t1.c == t2.b || t1.c == t2.c);
        return matches;
    }

    edge_triangles: Table(Edge, EdgeTriangles, hash_function, compare_function);
    edge_triangles.allocator = temp;

    index := 0;
    while index < indices.count {
        defer index += 3;
        
        a := vertices[indices[index]];
        b := vertices[indices[index + 1]];
        c := vertices[indices[index + 2]];

        // we want to insert the triangle so that the triangle edge ab is always shared
        edges: [6] Edge = ---;
        edges[0] = .{a, b};
        edges[1] = .{b, a};
        edges[2] = .{b, c};
        edges[3] = .{c, b};
        edges[4] = .{c, a};
        edges[5] = .{a, c};

        insertion_bits: [6] u8 = ---;
        insertion_bits[0] = 0x1;
        insertion_bits[1] = 0x2;
        insertion_bits[2] = 0x1;
        insertion_bits[3] = 0x2;
        insertion_bits[4] = 0x1;
        insertion_bits[5] = 0x2;

        corrected_triangles: [6] Triangle3 = ---;
        corrected_triangles[0] = .{a, b, c};
        corrected_triangles[1] = .{a, b, c};
        corrected_triangles[2] = .{b, c, a};
        corrected_triangles[3] = .{b, c, a};
        corrected_triangles[4] = .{c, a, b};
        corrected_triangles[5] = .{c, a, b};

        triangle := Triangle3.{a, b, c};

        for edge, i: edges {
            edge_info := find_or_add(*edge_triangles, edge);

            // if the triangle is already accounted for check the next edge
            // could check the equal bits but we might as well just compare against 0,0,0 triangles
            found := equalish(triangle, edge_info.edge_triangles[0]);
            found = found || equalish(triangle, edge_info.edge_triangles[1]);
            if found {
                continue;
            }

            insertion_bit := insertion_bits[i];
            if edge_info.edge_triangle_bits & insertion_bit {
                print("Potential convex hull has an edge that's already taken in this winding. %\n", edge);
                return false;
            }

            edge_info.edge_triangle_bits |= insertion_bit;
            edge_info.edge_triangles[insertion_bit - 1] = corrected_triangles[i];
        }
    }

    for edge_info: edge_triangles {
        if edge_info.edge_triangle_bits != 0x3 {
            print("Not convex due to edge triangle count.\n");
            return false;
        }

        triangle1 := edge_info.edge_triangles[0];
        normal1 := cross(triangle1.b - triangle1.a, triangle1.c - triangle1.a);

        triangle2 := edge_info.edge_triangles[1];

        // a and b are both part of the testing line, so we'll check that both are satisfied
        // to hopefully prevent floating point issues
        // or not

        if dot(triangle2.a - triangle2.c, normal1) < -EPSILON {
            return false;
        }
    }

    return true;
}