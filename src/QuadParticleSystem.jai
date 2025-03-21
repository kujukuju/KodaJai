
QuadParticleSystem :: struct ($PG: Type, $PC: Type, $update_function: (gpu: *PG, cpu: *PC, time: float, dt: float) -> bool = null) {
    CombinedPG :: struct {
        using qv: QuadVertex;
        using pg: PG;
    }

    last_render_time: float64;
    particles_gpu: [..] PG;
    particles_cpu: [..] PC;
    particle_quads: [..] QuadVertices;
    particle_ids: [..] int;
    particles_remove: [..] bool;
    next_particle_id: int = 1;
    vao: GLuint;
    vbo: GLuint;
    particle_vbo_allocated: int;
    shader: *Shader;
    uniforms: ShaderUniforms;
    depth_func: DepthFunc = .LessEqual;
    cull_face: bool;
    synchronous_lock: Mutex;
    parallel_limit: int = 128;

    temp_buffer: [..] u8;
}

QuadVertex :: struct {
    v: Vector3;
    n: Vector3;
    uv: Vector2;
}

QuadVertices :: struct {
    verts: [6] QuadVertex;
}

quad_particle_system_init :: (system: *QuadParticleSystem($PG, $PC, $update_function), shader: *Shader) {
    init(*system.synchronous_lock);

    CombinedPG :: QuadParticleSystem(PG, PC, update_function).CombinedPG;

    system.shader = shader;

    glGenVertexArrays(1, *system.vao);
    glGenBuffers(1, *system.vbo);

    glBindVertexArray(system.vao);

    default_count :: 64;
    gpu_attributes :: #run get_attributes_from_struct(CombinedPG);

    glBindBuffer(GL_ARRAY_BUFFER, system.vbo);
    glBufferData(GL_ARRAY_BUFFER, default_count * size_of(CombinedPG), null, GL_DYNAMIC_DRAW);

    total_float_size := cast(u32) get_attribute_stride(gpu_attributes);
    current_attribute: u32;
    float_offset: s32;
    for attribute: gpu_attributes {
        attribute_size := cast(s32) get_attribute_size(attribute);
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, attribute_size, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));

        current_attribute += 1;
        float_offset += attribute_size;
    }

    array_reserve(*system.particles_gpu, default_count);
    array_reserve(*system.particles_cpu, default_count);
    array_reserve(*system.particle_quads, default_count);
    array_reserve(*system.particle_ids, default_count);

    system.particle_vbo_allocated = default_count;

    glBindVertexArray(0);
}

quad_particle_system_update_and_render :: (system: *QuadParticleSystem($PG, $PC, $update_function), time: float64) {
    inline quad_particle_system_update_and_render(system, time, get_perspective_matrix());
}

quad_particle_system_update_and_render :: (system: *QuadParticleSystem($PG, $PC, $update_function), time: float64, projection: Matrix4) {
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
                array_reserve(*system.particles_remove, system.particles_gpu.count);
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
                        system.particle_quads[insert_index] = system.particle_quads[check_index];
                        system.particle_ids[insert_index] = system.particle_ids[check_index];
                    }

                    insert_index += 1;
                    check_index += 1;
                }
            }
            system.particles_gpu.count -= check_index - insert_index;
            system.particles_cpu.count -= check_index - insert_index;
            system.particle_quads.count -= check_index - insert_index;
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
                        system.particle_quads[insert_index] = system.particle_quads[check_index];
                        system.particle_ids[insert_index] = system.particle_ids[check_index];
                    }

                    insert_index += 1;
                    check_index += 1;
                }
            }
            system.particles_gpu.count -= check_index - insert_index;
            system.particles_cpu.count -= check_index - insert_index;
            system.particle_quads.count -= check_index - insert_index;
            system.particle_ids.count -= check_index - insert_index;
        }
    } else {
        assert(false, "Empty update functions not yet handled but it should be.\n");
    }

    CombinedPG :: QuadParticleSystem(PG, PC, update_function).CombinedPG;
    combined_size :: size_of(CombinedPG);

    total_size := system.particles_gpu.count * combined_size * 6;
    if system.temp_buffer.allocated < total_size {
        array_reserve(*system.temp_buffer, total_size);
        system.temp_buffer.count = total_size;
    }

    for i: 0..system.particles_gpu.count - 1 {
        data_offset := i * combined_size * 6;

        vertices := system.particle_quads[i];

        for a: 0..vertices.verts.count - 1 {
            vert_offset := a * combined_size;

            memcpy(system.temp_buffer.data + data_offset + vert_offset, vertices.verts.data + a, size_of(QuadVertex));
            memcpy(system.temp_buffer.data + data_offset + vert_offset + size_of(QuadVertex), system.particles_gpu.data + i, size_of(PG));
        }
    }

    if system.particle_vbo_allocated >= system.temp_buffer.count {
        glBindBuffer(GL_ARRAY_BUFFER, system.vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, system.temp_buffer.count, system.temp_buffer.data);
    } else {
        system.particle_vbo_allocated = system.temp_buffer.allocated;

        glBindBuffer(GL_ARRAY_BUFFER, system.vbo);
        glBufferData(GL_ARRAY_BUFFER, system.temp_buffer.allocated, system.temp_buffer.data, GL_DYNAMIC_DRAW);
    }

    quad_particle_system_render(system, time, projection);
}

quad_particle_system_render :: (system: *QuadParticleSystem($PG, $PC, $update_function), time: float64) {
    inline quad_particle_system_render(system, time, get_perspective_matrix());
}

quad_particle_system_render :: (system: *QuadParticleSystem($PG, $PC, $update_function), time: float64, projection: Matrix4) {
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
    // glDrawArraysInstanced(GL_TRIANGLES, 0, cast(u32) system.particles_gpu.count * 2, GL_UNSIGNED_INT, null, cast(u32) system.particles_gpu.count);
    glDrawArrays(GL_TRIANGLES, 0, cast(u32) system.particles_gpu.count * 6);
    glBindVertexArray(0);

    if system.cull_face != cull_face {
        set_cull_face(cull_face);
    }
}

quad_particle_system_add_quad :: (system: *QuadParticleSystem($PG, $PC, $update_function), quad: [4] Vector3, gpu: PG, cpu: PC) -> int {
    array_add(*system.particles_gpu, gpu);
    array_add(*system.particles_cpu, cpu);

    vertices := create_quad_vertices(quad);
    array_add(*system.particle_quads, vertices);

    particle_id := system.next_particle_id;
    system.next_particle_id += 1;

    array_add(*system.particle_ids, particle_id);

    // we add 1 so that we never return 0
    return particle_id;
}

quad_particle_system_update_quad :: (system: *QuadParticleSystem($PG, $PC, $update_function), id: int, quad: [4] Vector3, gpu: PG, cpu: PC) {
    particle_found, particle_index := array_find(system.particle_ids, id);
    if !particle_found {
        assert(false, "Could not find particle for id %.", id);
        return;
    }

    system.particles_gpu[particle_index] = gpu;
    system.particles_cpu[particle_index] = cpu;

    vertices := create_quad_vertices(quad);
    system.particle_quads[particle_index] = vertices;
}

quad_particle_system_has_quad :: (system: *QuadParticleSystem($PG, $PC, $update_function), id: int) -> bool {
    return array_find(system.particle_ids, id);
}

#scope_file

create_quad_vertices :: (quad: [4] Vector3) -> QuadVertices {
    // moving up kind of
    // 3 --- 2
    // |     |
    // 0 --- 1

    n1 := normalize(cross(quad[2] - quad[0], quad[2] - quad[1]));
    n2 := normalize(cross(quad[0] - quad[2], quad[0] - quad[3]));

    vertices: QuadVertices = ---;
    vertices.verts[0].v = quad[0];
    vertices.verts[0].n = n1;
    vertices.verts[0].uv = .{0, 1};
    vertices.verts[1].v = quad[1];
    vertices.verts[1].n = n1;
    vertices.verts[1].uv = .{1, 1};
    vertices.verts[2].v = quad[2];
    vertices.verts[2].n = n1;
    vertices.verts[2].uv = .{1, 0};
    vertices.verts[3].v = quad[2];
    vertices.verts[3].n = n2;
    vertices.verts[3].uv = .{1, 0};
    vertices.verts[4].v = quad[3];
    vertices.verts[4].n = n2;
    vertices.verts[4].uv = .{0, 0};
    vertices.verts[5].v = quad[0];
    vertices.verts[5].n = n2;
    vertices.verts[5].uv = .{0, 1};

    return vertices;
}
