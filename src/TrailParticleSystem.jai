
TrailParticleSystem :: struct ($PG: Type, $PC: Type, $update_function: (gpu: *PG, cpu: *PC, time: float, dt: float) -> bool = null) {
    CombinedPG :: struct {
        using qd: TrailDirections;
        using pg: PG;
    }

    last_render_time: float64;
    particles_gpu: [..] PG;
    particles_cpu: [..] PC;
    particle_trails: [..] TrailDirections;
    particle_ids: [..] int;
    particles_remove: [..] bool;
    next_particle_id: int = 1;
    vao: GLuint;
    ebo: GLuint;
    vbo: GLuint;
    particle_vbo: GLuint;
    particle_vbo_allocated: int;
    shader: *Shader;
    uniforms: ShaderUniforms;
    depth_func: DepthFunc = .LessEqual;
    cull_face: bool;
    synchronous_lock: Mutex;
    parallel_limit: int = 128;
    bands_per_quad: int;

    temp_buffer: [..] u8;
}

TrailDirections :: struct {
    front_position: Vector3;
    front_axis: Vector3;
    back_position: Vector3;
    back_axis: Vector3;
}

// the problem with why you can see the edges when you're viewing the trail at a steep angle is that
// when you take one edge of a quad and rotate it around its forward axis
// the triangles between the two edges rotate in different ways and you end up being able to see both sides when it's transparent
// the ways I can think to fix this are subdivide and interpolate the position, which would work I guess
// or do a depth pre-pass but on an individual trail basis which would be really slow
// or you can do some weird shit with a stencil buffer to only draw each trail once per fragment maybe

// vertically subdividing via bands_per_quad seems to fix it

trail_particle_system_init :: (system: *TrailParticleSystem($PG, $PC, $update_function), shader: *Shader, bands_per_quad: int = 4) {
    init(*system.synchronous_lock);

    CombinedPG :: TrailParticleSystem(PG, PC, update_function).CombinedPG;

    system.shader = shader;
    system.bands_per_quad = bands_per_quad;

    // making a quad with a through the center so it can bend properly-ish

    initial_vertices := Vector3.[
        .{-1, 0, -1},
        .{-1, 0, 1},
        .{0, 0, 1},
        .{1, 0, 1},
        .{1, 0, -1},
        .{0, 0, -1},
    ];
    initial_indices := u32.[
        0, 1, 2,
        0, 2, 5,
        5, 2, 3,
        5, 3, 4,
    ];
    attributes := Attribute.[
        .Position,
    ];

    vertices := NewArray(initial_vertices.count * bands_per_quad, Vector3,, temp);
    indices := NewArray(initial_indices.count * bands_per_quad, u32,, temp);

    for layer: 0..bands_per_quad - 1 {
        for vertex, vi: initial_vertices {
            actual_vertex := vertex;
            actual_vertex.z = actual_vertex.z * 0.5 + 0.5;
            actual_vertex.z *= 1.0 / bands_per_quad;
            actual_vertex.z += cast(float) layer / bands_per_quad;
            actual_vertex.z = actual_vertex.z * 2.0 - 1.0;

            vertices[layer * initial_vertices.count + vi] = actual_vertex;
        }

        for index, ii: initial_indices {
            indices[layer * initial_indices.count + ii] = index + cast(u32) layer * initial_vertices.count;
        }
    }

    glGenVertexArrays(1, *system.vao);
    glGenBuffers(1, *system.vbo);
    glGenBuffers(1, *system.ebo);
    glGenBuffers(1, *system.particle_vbo);

    glBindVertexArray(system.vao);

    glBindBuffer(GL_ARRAY_BUFFER, system.vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vector3), vertices.data, GL_STATIC_DRAW);  

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, system.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.count * size_of(u32), indices.data, GL_STATIC_DRAW);

    total_float_size := cast(u32) get_attribute_stride(attributes);
    current_attribute: u32;
    float_offset: s32;
    for attribute: attributes {
        attribute_size := cast(s32) get_attribute_size(attribute);
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, attribute_size, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));

        current_attribute += 1;
        float_offset += attribute_size;
    }

    default_particle_count :: 64;

    array_reserve(*system.particles_gpu, default_particle_count);
    array_reserve(*system.particles_cpu, default_particle_count);
    array_reserve(*system.particle_trails, default_particle_count);
    array_reserve(*system.particle_ids, default_particle_count);
    array_reserve(*system.particles_remove, default_particle_count);

    // generate the particle vbo, but currently we have no data
    glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
    glBufferData(GL_ARRAY_BUFFER, default_particle_count * size_of(CombinedPG), null, GL_DYNAMIC_DRAW);
    system.particle_vbo_allocated = default_particle_count;

    // insert particle type vertex attribute data
    gpu_attributes :: #run get_attributes_from_struct(CombinedPG);
    #insert #run get_instanced_opengl_initialization("current_attribute", gpu_attributes);

    glBindVertexArray(0);
}

trail_particle_system_update_and_render :: (system: *TrailParticleSystem($PG, $PC, $update_function), time: float64) {
    inline trail_particle_system_update_and_render(system, time, get_perspective_matrix());
}

trail_particle_system_update_and_render :: (system: *TrailParticleSystem($PG, $PC, $update_function), time: float64, projection: Matrix4) {
    dt := time - system.last_render_time;
    system.last_render_time = time;

    if system.particles_gpu.count == 0 {
        return;
    }

    #if update_function {
        time_float := cast(float) time;
        dt_float := cast(float) dt;

        is_parallel := system.particles_gpu.count >= system.parallel_limit;
        if is_parallel {
            if system.particles_remove.allocated < system.particles_gpu.count {
                array_reserve(*system.particles_remove, system.particles_gpu.allocated);
            }

            system.particles_remove.count = system.particles_gpu.count;
            memset(system.particles_remove.data, 0, system.particles_remove.count * size_of(bool));

            // update particles, track removal requests
            for i: 0..system.particles_gpu.count - 1 {
                system.particles_remove[i] = inline update_function(*system.particles_gpu[i], *system.particles_cpu[i], time_float, dt_float);
            }

            // apply removals
            insert_index := 0;
            check_index := 0;
            while check_index < system.particles_gpu.count {
                if system.particles_remove[check_index] {
                    check_index += 1;
                } else {
                    if insert_index != check_index {
                        system.particles_gpu[insert_index] = system.particles_gpu[check_index];
                        system.particles_cpu[insert_index] = system.particles_cpu[check_index];
                        system.particle_trails[insert_index] = system.particle_trails[check_index];
                        system.particle_ids[insert_index] = system.particle_ids[check_index];
                    }

                    insert_index += 1;
                    check_index += 1;
                }
            }
            system.particles_gpu.count -= check_index - insert_index;
            system.particles_cpu.count -= check_index - insert_index;
            system.particle_trails.count -= check_index - insert_index;
            system.particle_ids.count -= check_index - insert_index;
        } else {
            // apply removals
            insert_index := 0;
            check_index := 0;
            while check_index < system.particles_gpu.count {
                removal := inline update_function(*system.particles_gpu[check_index], *system.particles_cpu[check_index], time_float, dt_float);
                if removal {
                    check_index += 1;
                } else {
                    if insert_index != check_index {
                        system.particles_gpu[insert_index] = system.particles_gpu[check_index];
                        system.particles_cpu[insert_index] = system.particles_cpu[check_index];
                        system.particle_trails[insert_index] = system.particle_trails[check_index];
                        system.particle_ids[insert_index] = system.particle_ids[check_index];
                    }

                    insert_index += 1;
                    check_index += 1;
                }
            }
            system.particles_gpu.count -= check_index - insert_index;
            system.particles_cpu.count -= check_index - insert_index;
            system.particle_trails.count -= check_index - insert_index;
            system.particle_ids.count -= check_index - insert_index;
        }
    } else {
        assert(false, "Empty update functions not yet handled but it should be.\n");
    }

    CombinedPG :: TrailParticleSystem(PG, PC, update_function).CombinedPG;
    combined_size :: size_of(CombinedPG);

    total_size := system.particles_gpu.count * combined_size;
    if system.temp_buffer.allocated < total_size {
        array_reserve(*system.temp_buffer, total_size);
        system.temp_buffer.count = total_size;
    }

    for i: 0..system.particles_gpu.count - 1 {
        data_offset := i * combined_size;

        memcpy(system.temp_buffer.data + data_offset, system.particle_trails.data + i, size_of(TrailDirections));
        memcpy(system.temp_buffer.data + data_offset + size_of(TrailDirections), system.particles_gpu.data + i, size_of(PG));
    }

    if system.particle_vbo_allocated >= system.temp_buffer.count {
        glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, system.temp_buffer.count, system.temp_buffer.data);
    } else {
        system.particle_vbo_allocated = system.temp_buffer.allocated;

        glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
        glBufferData(GL_ARRAY_BUFFER, system.temp_buffer.allocated, system.temp_buffer.data, GL_DYNAMIC_DRAW);
    }

    trail_particle_system_render(system, time, projection);
}

trail_particle_system_render :: (system: *TrailParticleSystem($PG, $PC, $update_function), time: float64) {
    inline trail_particle_system_render(system, time, get_perspective_matrix());
}

trail_particle_system_render :: (system: *TrailParticleSystem($PG, $PC, $update_function), time: float64, projection: Matrix4) {
    cull_face := koda.cull_face;
    if system.cull_face != cull_face {
        set_cull_face(system.cull_face);
    }

    use_shader(system.shader);

    apply_uniforms(system.shader, system.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    view := koda.view;
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "view", view);
    
    apply_uniforms(system.shader, uniforms);

    depth_func := get_depth_func();
    defer set_depth_func(depth_func);
    set_depth_func(system.depth_func);

    glBindVertexArray(system.vao);
    glDrawElementsInstanced(GL_TRIANGLES, 12 * cast(u32) system.bands_per_quad, GL_UNSIGNED_INT, null, cast(u32) system.particles_gpu.count);
    glBindVertexArray(0);

    if system.cull_face != cull_face {
        set_cull_face(cull_face);
    }
}

trail_particle_system_add_trail :: (system: *TrailParticleSystem($PG, $PC, $update_function), trail: [3] Vector3, gpu: PG, cpu: PC) -> int {
    array_add(*system.particles_gpu, gpu);
    array_add(*system.particles_cpu, cpu);

    vertices := create_trail_vertices(trail);
    array_add(*system.particle_trails, vertices);

    particle_id := system.next_particle_id;
    system.next_particle_id += 1;

    array_add(*system.particle_ids, particle_id);

    // we add 1 so that we never return 0
    return particle_id;
}

trail_particle_system_update_trail :: (system: *TrailParticleSystem($PG, $PC, $update_function), id: int, trail: [3] Vector3, gpu: PG, cpu: PC) {
    particle_found, particle_index := array_find(system.particle_ids, id);
    if !particle_found {
        assert(false, "Could not find particle for id %.", id);
        return;
    }

    system.particles_gpu[particle_index] = gpu;
    system.particles_cpu[particle_index] = cpu;

    vertices := create_trail_vertices(trail);
    system.particle_trails[particle_index] = vertices;
}

trail_particle_system_has_trail :: (system: *TrailParticleSystem($PG, $PC, $update_function), id: int) -> bool {
    return array_find(system.particle_ids, id);
}

#scope_file

// trail [3] is
// old start
// new start
// new end
// because the new start has to have an axis of the old trail quad
create_trail_vertices :: (trail: [3] Vector3) -> TrailDirections {
    directions: TrailDirections = ---;
    directions.front_position = trail[1];
    directions.front_axis = normalize(trail[1] - trail[0]);
    directions.back_position = trail[2];
    directions.back_axis = normalize(trail[2] - trail[1]);

    return directions;
}
