
ParticleSystem :: struct (ParticleGpu: Type, ParticleCpu: Type, Particle: Type, update_function: #type (particle: *Particle, time: float, dt: float), sort: bool = true) {
    last_render_time: float64;
    particles_gpu: [..] ParticleGpu;
    particles_cpu: [..] ParticleCpu;
    particles_gpu_buffer: [..] ParticleGpu;
    particles_cpu_buffer: [..] ParticleCpu;
    depth_values: [..] DepthEntry;
    vao: GLuint;
    vbo: GLuint;
    ebo: GLuint;
    particle_vbo: GLuint;
    particle_vbo_allocated: int;
    shader: *Shader;
    uniforms: ShaderUniforms;
    indices_count: int;
    synchronous_lock: Mutex;
}

particle_system_create :: (shader: *Shader, $PG: Type, $PC: Type, $P: Type, $update_function: #type (particle: *P, time: float, dt: float), geometry: *Geometry = null, $sort: bool = true) -> ParticleSystem(PG, PC, P, update_function, sort) {
    system: ParticleSystem(PG, PC, P, update_function, sort);
    system.shader = shader;
    init(*system.synchronous_lock);

    geometry_vertices: [] float;
    geometry_indices: [] u32;
    geometry_attributes: [] Attribute;
    if geometry {
        geometry_vertices = geometry.vertices;
        geometry_indices = geometry.indices;
        geometry_attributes = geometry.attributes;
    } else {
        geometry_vertices = particle_vertices;
        geometry_indices = particle_indices;
        geometry_attributes = particle_attributes;
    }
    system.indices_count = geometry_indices.count;

    glGenVertexArrays(1, *system.vao);
    glGenBuffers(1, *system.vbo);
    glGenBuffers(1, *system.ebo);
    glGenBuffers(1, *system.particle_vbo);

    glBindVertexArray(system.vao);

    glBindBuffer(GL_ARRAY_BUFFER, system.vbo);
    glBufferData(GL_ARRAY_BUFFER, geometry_vertices.count * size_of(float32), geometry_vertices.data, GL_STATIC_DRAW);  

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, system.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, geometry_indices.count * size_of(u32), geometry_indices.data, GL_STATIC_DRAW);

    total_float_size := cast(u32) get_attribute_stride(geometry_attributes);
    current_attribute: u32;
    float_offset: s32;
    for attribute: geometry_attributes {
        attribute_size := cast(s32) get_attribute_size(attribute);
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, attribute_size, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));

        current_attribute += 1;
        float_offset += attribute_size;
    }

    // generate the particle vbo, but currently we have no data
    glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
    glBufferData(GL_ARRAY_BUFFER, 128 * size_of(PG), null, GL_DYNAMIC_DRAW);
    system.particle_vbo_allocated = 128;

    // insert particle type vertex attribute data
    starting_attribute := current_attribute;

    #insert #run () -> string {
        struct_type := cast(*Type_Info_Struct) PG;
        assert(struct_type.type == .STRUCT, "Your graphics particle must be a struct.");

        builder: String_Builder;

        real_member_count := 0;

        skip_indices: [..] int;
        visited_offsets: [..] int;
        for member, index: struct_type.members {
            if array_find(visited_offsets, member.offset_in_bytes) {
                array_add(*skip_indices, index);
                continue;
            }

            array_add(*visited_offsets, member.offset_in_bytes);
            real_member_count += 1;
        }

        total_stride := 0;
        for member, index: struct_type.members {
            if array_find(skip_indices, index) {
                continue;
            }

            assert(member.type.runtime_size != -1, "Particle gpu member sizes cannot be -1, this indicates it's not yet been compiled.");

            total_stride += member.type.runtime_size;
        }

        stride_offset := 0;
        for member, index: struct_type.members {
            if array_find(skip_indices, index) {
                continue;
            }
            
            member_stride := member.type.runtime_size;

            append(*builder, tprint("glEnableVertexAttribArray(current_attribute);\n"));
            append(*builder, tprint("glVertexAttribPointer(current_attribute, %, GL_FLOAT, GL_FALSE, %, cast(*void) %);\n", member_stride / size_of(float32), total_stride, stride_offset));

            append(*builder, "current_attribute += 1;\n");

            stride_offset += member_stride;
        }

        for i: 0..real_member_count - 1 {
            append(*builder, tprint("glVertexAttribDivisor(starting_attribute + %, 1);\n", i));
        }

        return builder_to_string(*builder);
    }();

    glBindVertexArray(0);

    return system;
}

particle_system_update_and_render :: (system: *ParticleSystem($PG, $PC, $P, $update_function, $sort), time: float64) {
    dt := cast(float) (time - system.last_render_time);
    system.last_render_time = time;

    if system.particles_gpu.count == 0 {
        return;
    }

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

    time_float := cast(float) time;

    #if update_function {
        captured_update_loop := capture((i: int) {
            system: *ParticleSystem(PG, PC, P, update_function, sort); @capture
            time_float: float; @capture
            dt: float; @capture
            particle: P = ---;
            particle.particle_gpu = system.particles_gpu[i];
            particle.particle_cpu = system.particles_cpu[i];

            inline update_function(*particle, time_float, dt);

            system.particles_gpu[i] = particle.particle_gpu;
            system.particles_cpu[i] = particle.particle_cpu;
        });

        parallel_for(0, system.particles_gpu.count, captured_update_loop);
    }

    view := koda.view;
    #if sort {
        array_reserve(*system.depth_values, system.particles_gpu.allocated);
        array_reserve(*system.particles_gpu_buffer, system.particles_gpu.allocated);
        array_reserve(*system.particles_cpu_buffer, system.particles_gpu.allocated);

        system.depth_values.count = system.particles_gpu.count;
        system.particles_gpu_buffer.count = system.particles_gpu.count;
        system.particles_cpu_buffer.count = system.particles_gpu.count;

        p := Vector4.{0, 0, 0, 1};
        for particle, index: system.particles_gpu {
            p.xyz = particle.position;
            
            w := view._41 * p.x + view._42 * p.y + view._43 * p.z + view._44 * p.w;
            z := view._31 * p.x + view._32 * p.y + view._33 * p.z + view._34 * p.w;
            system.depth_values[index] = .{z / w, cast(s32) index};
        }

        quick_sort_threaded(system.depth_values);
        // quick_sort(depth_values, (a: DepthEntry, b: DepthEntry) -> float {
        //     return a.depth - b.depth;
        // });

        for entry, index: system.depth_values {
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

    // if koda.cull_face {
    //     set_cull_face(false);
    // }

    use_shader(system.shader);

    projection := get_perspective_matrix();

    apply_uniforms(system.shader, system.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms[xx "projection"] = create_uniform("projection", projection);
    uniforms[xx "view"] = create_uniform("view", view);
    
    apply_uniforms(system.shader, uniforms);

    depth_func := get_depth_func();
    defer set_depth_func(depth_func);
    set_depth_func(.LessEqual);

    glBindVertexArray(system.vao);
    glDrawElementsInstanced(GL_TRIANGLES, cast(u32) system.indices_count, GL_UNSIGNED_INT, null, cast(u32) system.particles_gpu.count);
    glBindVertexArray(0);
}

// TODO add particles sorted insert, because then presumably the list is already sorted if its sorted after each update
particle_system_add_particle :: (system: *ParticleSystem($PG, $PC, $P, $update_function, $sort), particle: P) {
    array_add(*system.particles_gpu, particle.particle_gpu);
    array_add(*system.particles_cpu, particle.particle_cpu);
}

particle_system_add_particle :: (system: *ParticleSystem($PG, $PC, $P, $update_function, $sort), particles: ..P) {
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

particle_system_add_particle_synchronous :: (system: *ParticleSystem($PG, $PC, $P, $update_function, $sort), particle: P) {
    lock(*system.synchronous_lock);
    defer unlock(*system.synchronous_lock);

    array_add(*system.particles_gpu, particle.particle_gpu);
    array_add(*system.particles_cpu, particle.particle_cpu);
}

particle_system_add_particle_synchronous :: (system: *ParticleSystem($PG, $PC, $P, $update_function, $sort), particles: ..P) {
    lock(*system.synchronous_lock);
    defer unlock(*system.synchronous_lock);
    
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
particle_attributes :: Attribute.[.Position, .Texcoord];
// particle_geometry :: #run () -> Geometry {
//     attributes := Attribute.[.Position, .Texcoord];
//     geometry_pointer := create_geometry(particle_vertices, particle_indices, attributes, should_upload = false);
//     return geometry_pointer.*;
// }();

#import "Sort";
