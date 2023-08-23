
ParticleSystem :: struct (TextureType: Type, ParticleGpu: Type, ParticleCpu: Type, Particle: Type, update_function: #type (particle: *Particle, time: float, dt: float), sort: bool = true) {
    texture: TextureType;
    last_render_time: float64;
    particles_gpu: [..] ParticleGpu;
    particles_cpu: [..] ParticleCpu;
    particles_gpu_buffer: [..] ParticleGpu;
    particles_cpu_buffer: [..] ParticleCpu;
    vao: GLuint;
    vbo: GLuint;
    ebo: GLuint;
    particle_vbo: GLuint;
    particle_vbo_allocated: int;
    shader: *Shader;
    uniforms: ShaderUniforms;
}

particle_system_create :: (texture: $T, shader: *Shader, $PG: Type, $PC: Type, $P: Type, $update_function: #type (particle: *P, time: float, dt: float), $sort: bool = true) -> ParticleSystem(T, PG, PC, P, update_function, sort) {
    system: ParticleSystem(T, PG, PC, P, update_function, sort);
    system.texture = texture;
    system.shader = shader;

    glGenVertexArrays(1, *system.vao);
    glGenBuffers(1, *system.vbo);
    glGenBuffers(1, *system.ebo);
    glGenBuffers(1, *system.particle_vbo);

    glBindVertexArray(system.vao);

    glBindBuffer(GL_ARRAY_BUFFER, system.vbo);
    glBufferData(GL_ARRAY_BUFFER, particle_vertices.count * size_of(float32), particle_vertices.data, GL_STATIC_DRAW);  

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, system.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, particle_indices.count * size_of(u32), particle_indices.data, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(float32) * 5, cast(*void) 0);

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(float32) * 5, cast(*void) (size_of(float32) * 3));

    // generate the particle vbo, but currently we have no data
    glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
    glBufferData(GL_ARRAY_BUFFER, 128 * size_of(PG), null, GL_DYNAMIC_DRAW);
    system.particle_vbo_allocated = 128;

    // insert particle type vertex attribute data
    #insert #run () -> string {
        attribute_starting_offset := 2;

        struct_type := cast(*Type_Info_Struct) PG;
        assert(struct_type.type == .STRUCT, "Your graphics particle must be a struct.");

        builder: String_Builder;

        total_stride := 0;
        for member: struct_type.members {
            assert(member.type.runtime_size != -1, "Particle gpu member sizes cannot be -1, this indicates it's not yet been compiled.");

            total_stride += member.type.runtime_size;
        }

        attribute_offset := attribute_starting_offset;
        stride_offset := 0;
        for member: struct_type.members {   
            member_stride := member.type.runtime_size;

            append(*builder, tprint("glEnableVertexAttribArray(%);\n", attribute_offset));
            append(*builder, tprint("glVertexAttribPointer(%, %, GL_FLOAT, GL_FALSE, %, cast(*void) %);\n", attribute_offset, member_stride / size_of(float32), total_stride, stride_offset));

            attribute_offset += 1;
            stride_offset += member_stride;
        }

        for i: attribute_starting_offset..attribute_offset - 1 {
            append(*builder, tprint("glVertexAttribDivisor(%, 1);\n", i));
        }

        return builder_to_string(*builder);
    }();

    glBindVertexArray(0);

    return system;
}

particle_system_update_and_render :: (system: *ParticleSystem($T, $PG, $PC, $P, $update_function, $sort), time: float64) {
    dt := cast(float) (time - system.last_render_time);
    system.last_render_time = time;

    // TODO I could do this a LOT better by removing them all in a single pass, man am I dumb
    insert_index := 0;
    check_index := 0;
    while check_index < system.particles_cpu.count {
        if system.particles_cpu[check_index].destroy {
            check_index += 1;
        } else {
            if insert_index != check_index {
                system.particles_cpu[insert_index] = system.particles_cpu[check_index];
                system.particles_gpu[insert_index] = system.particles_gpu[check_index];
            }

            insert_index += 1;
            check_index += 1;
        }
    }
    system.particles_cpu.count -= check_index - insert_index;
    system.particles_gpu.count -= check_index - insert_index;

    // i := 0;
    // while i < system.particles_gpu.count {
    //     if system.particles_cpu[i].destroy {
    //         array_ordered_remove_by_index(*system.particles_gpu, i);
    //         array_ordered_remove_by_index(*system.particles_cpu, i);
    //     } else {
    //         i += 1;
    //     }
    // }

    time_float := cast(float) time;

    parallel_for(0, system.particles_gpu.count, (i: int, system: *ParticleSystem($T, $PG, $PC, $P, $update_function, $sort), time: float, dt: float) {
        particle: P = ---;
        particle.particle_gpu = system.particles_gpu[i];
        particle.particle_cpu = system.particles_cpu[i];

        inline update_function(*particle, time_float, dt);

        system.particles_gpu[i] = particle.particle_gpu;
        system.particles_cpu[i] = particle.particle_cpu;
    }, system, cast(float) time, dt);
    // for i: 0..system.particles_gpu.count - 1 {
    //     particle: P = ---;
    //     particle.particle_gpu = system.particles_gpu[i];
    //     particle.particle_cpu = system.particles_cpu[i];

    //     inline update_function(*particle, time_float, dt);

    //     system.particles_gpu[i] = particle.particle_gpu;
    //     system.particles_cpu[i] = particle.particle_cpu;
    // }

    array_reserve(*depth_values, system.particles_gpu.allocated);
    array_reserve(*system.particles_gpu_buffer, system.particles_gpu.allocated);
    array_reserve(*system.particles_cpu_buffer, system.particles_gpu.allocated);

    depth_values.count = system.particles_gpu.count;
    system.particles_gpu_buffer.count = system.particles_gpu.count;
    system.particles_cpu_buffer.count = system.particles_gpu.count;

    view := koda.view;
    #if sort {
        p := Vector4.{0, 0, 0, 1};
        for particle, index: system.particles_gpu {
            p.xyz = particle.position;
            
            w := view._41 * p.x + view._42 * p.y + view._43 * p.z + view._44 * p.w;
            z := view._31 * p.x + view._32 * p.y + view._33 * p.z + view._34 * p.w;
            depth_values[index] = .{z / w, cast(s32) index};
        }

        quick_sort_threaded(depth_values);
        // quick_sort(depth_values, (a: DepthEntry, b: DepthEntry) -> float {
        //     return a.depth - b.depth;
        // });

        for entry, index: depth_values {
            system.particles_gpu_buffer[index] = system.particles_gpu[entry.index];
            system.particles_cpu_buffer[index] = system.particles_cpu[entry.index];
        }

        system.particles_gpu.data, system.particles_gpu_buffer.data = system.particles_gpu_buffer.data, system.particles_gpu.data;
        system.particles_cpu.data, system.particles_cpu_buffer.data = system.particles_cpu_buffer.data, system.particles_cpu.data;
    }

    if system.particle_vbo_allocated >= system.particles_gpu.count {
        glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, system.particles_gpu.count * size_of(PG), system.particles_gpu.data);
    } else {
        system.particle_vbo_allocated = system.particles_gpu.allocated;
        glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
        glBufferData(GL_ARRAY_BUFFER, system.particles_gpu.allocated * size_of(PG), system.particles_gpu.data, GL_DYNAMIC_DRAW);  
    }

    if koda.cull_face {
        set_cull_face(false);
    }

    use_shader(system.shader);

    projection := get_perspective_matrix();

    apply_uniforms(system.shader, system.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms[xx "projection"] = create_uniform("projection", projection);
    uniforms[xx "view"] = create_uniform("view", view);
    uniforms[xx "uTexture0"] = create_uniform("uTexture0", system.texture);
    
    apply_uniforms(system.shader, uniforms);

    depth_func := get_depth_func();
    defer set_depth_func(depth_func);
    set_depth_func(.LessEqual);

    glBindVertexArray(system.vao);
    glDrawElementsInstanced(GL_TRIANGLES, cast(u32) particle_indices.count, GL_UNSIGNED_INT, null, cast(u32) system.particles_gpu.count);
    glBindVertexArray(0);
}

particle_system_add_particle :: (system: *ParticleSystem($T, $PG, $PC, $P, $update_function, $sort), particle: P) {
    array_add(*system.particles_gpu, particle.particle_gpu);
    array_add(*system.particles_cpu, particle.particle_cpu);
}

particle_system_add_particle :: (system: *ParticleSystem($T, $PG, $PC, $P, $update_function, $sort), particles: ..P) {
    if system.particles_gpu.allocated < system.particles_gpu.count + particles.count {
        desired_count := next_power_of_two(system.particles_gpu.count + particles.count);
        array_reserve(*system.particles_gpu, desired_count);
        array_reserve(*system.particles_cpu, desired_count);
    }

    for i: 0..particles.count - 1 {
        offset := system.particles_gpu.count + i;
        (system.particles_gpu.data + offset).* = particles[i].particle_gpu;
        (system.particles_cpu.data + offset).* = particles[i].particle_cpu;
    }

    system.particles_gpu.count += particles.count;
    system.particles_cpu.count += particles.count;
}

DepthEntry :: struct {
    depth: float;
    index: s32;
}

#scope_file

depth_values: [..] DepthEntry;

particle_quick_sort :: (array1: [] $T, array2: [] $O, f: (T, T) -> $R) {
    // TODO I should probably pre calculate all R values and sort 3 arrays at the same time

    quicksort_helper :: (a: *T, b: *O, n: s64, f: (T, T) -> R) {
        if n < 2 return;

        p := a[n / 2];

        i := 0;
        j := n-1;

        while true {
            while f(a[i], p) < 0  {i += 1;}
            while f(p, a[j]) < 0  {j -= 1;}

            if i >= j break;

            t1 := a[i];
            t2 := b[i];
            a[i] = a[j];
            b[i] = b[j];
            a[j] = t1;
            b[j] = t2;

            i += 1;
            j -= 1;
        }
        
        quicksort_helper(a, b, i, f);
        quicksort_helper(a + i, b + i, n - i, f);
    }

    quicksort_helper(array1.data, array2.data, array1.count, f);
}

// make the quad thats facing the camera
particle_vertices :: float.[
    -1, 1, 0,
    0, 0,
    -1, -1, 0,
    0, 1,
    1, -1, 0,
    1, 1,
    1, 1, 0,
    1, 0,
];
particle_indices :: u32.[
    0, 1, 2,
    0, 2, 3,
];

#import "Sort";
