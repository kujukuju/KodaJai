












calculate_bounding_sphere :: (vertex_iterator: $T) -> Sphere {
    start := seconds_since_init() * 1000;
    defer print("Calculate bounding sphere took % ms.\n", seconds_since_init() * 1000 - start);
    
    points: [..] Vector3;
    defer array_free(points);

    for vertex: vertex_iterator {
        array_add(*points, vertex);
    }

    // shuffle points randomly
    for index: 0..points.count - 1 {
        random_index := random_get() % cast(u64) points.count;
        points[index], points[random_index] = points[random_index], points[index];
    }

    StackEntry :: struct {
        phase: int;
        point_count: int;
        supports: [4] Vector3;
        support_count: int;
        p: Vector3;
    }

    stack: [..] StackEntry;

    get_first :: (array: [..] StackEntry) -> *StackEntry {
        return *array[array.count - 1];
    }

    push_first :: (array: *[..] StackEntry, entry: StackEntry) {
        array_add(array, entry);
    }

    pop_first :: (array: *[..] StackEntry) {
        array.count -= 1;
    }

    sphere: Sphere;

    empty_supports: [4] Vector3;
    push_first(*stack, StackEntry.{
        0,
        points.count,
        empty_supports,
        0,
        .{},
    });

    while stack.count > 0 {
        using get_first(stack);

        if phase == 0 {
            if point_count == 0 || support_count == 4 {
                if support_count == 4 {
                    sphere = create_sphere(supports[0], supports[1], supports[2], supports[3]);
                    pop_first(*stack);
                    continue;
                } else if support_count == 3 {
                    sphere = create_sphere(supports[0], supports[1], supports[2]);
                    pop_first(*stack);
                    continue;
                } else if support_count == 2 {
                    sphere = create_sphere(supports[0], supports[1]);
                    pop_first(*stack);
                    continue;
                } else if support_count == 1 {
                    sphere = create_sphere(supports[0]);
                    pop_first(*stack);
                    continue;
                } else {
                    sphere = .{};
                    pop_first(*stack);
                    continue;
                }
            }

            p = points[point_count - 1];
            phase = 1;

            next_entry := StackEntry.{
                0,
                point_count - 1,
                supports,
                support_count,
                .{},
            };
            push_first(*stack, next_entry);
            continue;
        } else if phase == 1 {
            if contains(sphere, p) {
                pop_first(*stack);
                continue;
            }

            supports[support_count] = p;
            support_count += 1;

            next_entry := StackEntry.{
                0,
                point_count - 1,
                supports,
                support_count,
                .{},
            };
            pop_first(*stack);
            push_first(*stack, next_entry);
            continue;
        }
    }

    return sphere;
}

// calculate_bounding_sphere :: (vertex_iterator: $T) -> Sphere {
//     start := seconds_since_init() * 1000;
//     defer print("Calculate bounding sphere took % ms.\n", seconds_since_init() * 1000 - start);
    
//     // TODO no allocation
//     points: [..] Vector3;
//     defer array_free(points);
//     supports: [4] Vector3;

//     index := 0;
//     for vertex: vertex_iterator {
//         array_add(*points, vertex);
//     }

//     SphereEntry :: struct {
//         sphere: Sphere;
//         support_points: [4] Vector3;
//         support_count: int;
//     }

//     // support_count: int;
//     spheres: BlockAllocator(SphereEntry, 1024);
//     defer free(spheres);

//     // largest_distance :: (sphere: Sphere, points: [] Vector3, inclusion_end: int) -> float {
//     //     largest_distance := 0.0;
//     //     for i: 0..inclusion_end {
//     //         largest_distance = max(largest_distance, distance_squared(sphere.center, points[i]));
//     //     }
//     //     return largest_distance;
//     // }

//     create_sphere :: (supports: [$N] Vector3) -> SphereEntry {
//         #if N == 0 {
//             return SphereEntry.{
//                 Sphere.{},
//                 .[.{}, .{}, .{}, .{}],
//                 0,
//             };
//         } else #if N == 1 {
//             return SphereEntry.{
//                 create_sphere(supports[0]),
//                 .[supports[0], .{}, .{}, .{}],
//                 1,
//             };
//         } else #if N == 2 {
//             return SphereEntry.{
//                 create_sphere(supports[0], supports[1]),
//                 .[supports[0], supports[1], .{}, .{}],
//                 2,
//             };
//         } else #if N == 3 {
//             return SphereEntry.{
//                 create_sphere(supports[0], supports[1], supports[2]),
//                 .[supports[0], supports[1], supports[2], .{}],
//                 3,
//             };
//         } else #if N == 4 {
//             return SphereEntry.{
//                 create_sphere(supports[0], supports[1], supports[2], supports[3]),
//                 .[supports[0], supports[1], supports[2], supports[3]],
//                 4,
//             };
//         }
//     }

//     smallest_sphere: Sphere;

//     iteration := 0;

//     while sphere_loop := spheres.count > 0 {
//         iteration += 1;

//         sphere_entry := pop_first(*spheres);
//         sphere := sphere_entry.sphere;
//         supports := sphere_entry.support_points;
//         support_count := sphere_entry.support_count;

//         print("Iterations: % of %.\n", iteration, spheres.count);

//         i := 0;
//         while i < points.count {
//             if contains(sphere, points[i]) {
//                 continue;
//             }

//             if support_count == 0 {
//                 claim_end(*spheres, create_sphere(.[points[i]]));
//                 continue sphere_loop;
//             } else if support_count == 1 {
//                 claim_end(*spheres, create_sphere(.[supports[0], points[i]]));
//                 continue sphere_loop;
//             } else if support_count == 2 {
//                 claim_end(*spheres, create_sphere(.[supports[0], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], points[i]]));
//                 continue sphere_loop;
//             } else if support_count == 3 {
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[2]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], supports[2]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[2], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[2], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], supports[2], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], supports[2], points[i]]));
//                 continue sphere_loop;
//             } else if support_count == 4 {
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[2]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[3]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], supports[2]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], supports[3]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[2], supports[3]]));
//                 claim_end(*spheres, create_sphere(.[supports[2], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[3], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], supports[2]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], supports[3]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[2], supports[3]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[2], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], supports[2], supports[3]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], supports[2], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[2], supports[3], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], supports[2], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[1], supports[3], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[0], supports[2], supports[3], points[i]]));
//                 claim_end(*spheres, create_sphere(.[supports[1], supports[2], supports[3], points[i]]));
//                 continue sphere_loop;
//             }
//         }

//         if smallest_sphere.radius == 0 || sphere.radius < smallest_sphere.radius {
//             smallest_sphere = sphere;
//         }
//     }

//     return smallest_sphere;



//     // welzl_sphere :: (points: [] Vector3, point_count: int, supports: [] Vector3, support_count: int) -> Sphere {
//     //     if point_count == 0 {
//     //         if support_count == {
//     //             case 0;
//     //                 return .{};
//     //             case 1;
//     //                 return create_sphere(supports[0]);
//     //             case 2;
//     //                 return create_sphere(supports[0], supports[1]);
//     //             case 3;
//     //                 return create_sphere(supports[0], supports[1], supports[2]);
//     //             case 4;
//     //                 return create_sphere(supports[0], supports[1], supports[2], supports[3]);
//     //         }
//     //     }

//     //     index := point_count - 1;
//     //     smallest_sphere := welzl_sphere(points, point_count - 1, supports, support_count);

//     //     if contains(smallest_sphere, points[index]) {
//     //         return smallest_sphere;
//     //     }

//     //     supports[support_count] = points[index];

//     //     return welzl_sphere(points, point_count - 1, supports, support_count + 1);
//     // }

//     // return welzl_sphere(points, points.count, supports_view, 0);
// }

calculate_aabb :: (vertex_iterator: $T) -> AABB3 {
    set_aabb := false;
    aabb := AABB3.{};

    for vertex: vertex_iterator {
        if !set_aabb {
            set_aabb = true;
            aabb = .{vertex, vertex};
        } else {
            aabb.lower = min(aabb.lower, vertex);
            aabb.upper = max(aabb.upper, vertex);
        }
    }

    return aabb;
}
