
// TODO ensure the shader being used here matches the attributes of the particle system geometry... but liberally

ParticleSystem :: struct (ParticleGpu: Type, ParticleCpu: Type, update_function: #type (particle_gpu: *ParticleGpu, particle_cpu: *ParticleCpu, time: float, dt: float) = null, sort: bool = true) {
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
    depth_func: DepthFunc = .LessEqual;
    indices_count: int;
    synchronous_lock: Mutex;
    limit_replace_index: int;
    last_uploaded_index: int;
    cull_face: bool;
    parallel_limit: int = 128;
}

ParentParticle :: struct (PG: Type, PC: Type) {
    using pg: *PG;
    using pc: *PC;
}

particle_system_create :: (shader: *Shader, $PG: Type, $PC: Type, $update_function: #type (particle_gpu: *PG, particle_cpu: *PC, time: float, dt: float) = null, geometry: *Geometry = null, $sort: bool = true) -> ParticleSystem(PG, PC, update_function, sort) {
    system: ParticleSystem(PG, PC, update_function, sort);
    particle_system_init(*system, shader, geometry);

    return system;
}

particle_system_init :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), shader: *Shader, geometry: *Geometry = null) {
    init(*system.synchronous_lock);

    system.shader = shader;

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

    default_particle_count :: 64;

    array_reserve(*system.particles_gpu, default_particle_count);
    array_reserve(*system.particles_cpu, default_particle_count);

    // generate the particle vbo, but currently we have no data
    glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
    glBufferData(GL_ARRAY_BUFFER, default_particle_count * size_of(PG), null, GL_DYNAMIC_DRAW);
    system.particle_vbo_allocated = default_particle_count;

    // insert particle type vertex attribute data
    gpu_attributes :: #run get_attributes_from_struct(PG);
    #insert #run get_instanced_opengl_initialization("current_attribute", gpu_attributes);

    glBindVertexArray(0);
}

particle_system_update_and_render :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), time: float64) {
    inline particle_system_update_and_render(system, time, get_perspective_matrix());
}

particle_system_update_and_render :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), time: float64, projection: Matrix4) {
    dt := cast(float) (time - system.last_render_time);
    system.last_render_time = time;

    if system.particles_gpu.count == 0 {
        return;
    }

    #if update_function {
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
    }

    is_parallel := system.particles_gpu.count >= system.parallel_limit;

    #if update_function {
        time_float := cast(float) time;

        if is_parallel {
            callback :: (i: int, thread: int, using data: struct {
                system: *ParticleSystem(PG, PC, update_function, sort);
                time_float: float;
                dt: float;}) {

                inline update_function(system.particles_gpu.data + i, system.particles_cpu.data + i, time_float, dt);
            } @thread_unlocked(particle_system)

            parallel_for(0, system.particles_gpu.count, callback, .{system, time_float, dt});
        } else {
            for i: 0..system.particles_gpu.count - 1 {
                inline update_function(system.particles_gpu.data + i, system.particles_cpu.data + i, time_float, dt);
            }
        }
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

        // TODO the potential problem here is the behavior is actually different I think
        // in the parallel case it doesn't guarantee same depth entries will maintain their order, potentially flickering
        if is_parallel {
            quick_sort_threaded(system.depth_values);
        } else {
            quick_sort(system.depth_values, (a: DepthEntry, b: DepthEntry) -> float {
                return a.depth - b.depth;
            });
        }

        for entry, index: system.depth_values {
            system.particles_gpu_buffer[index] = system.particles_gpu[entry.index];
            system.particles_cpu_buffer[index] = system.particles_cpu[entry.index];
        }

        system.particles_gpu.data, system.particles_gpu_buffer.data = system.particles_gpu_buffer.data, system.particles_gpu.data;
        system.particles_cpu.data, system.particles_cpu_buffer.data = system.particles_cpu_buffer.data, system.particles_cpu.data;
    }

    if system.particle_vbo_allocated >= system.particles_gpu.count {
        #if update_function {
            // if theres an update function we can expect every particle to change every frame
            glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
            glBufferSubData(GL_ARRAY_BUFFER, 0, system.particles_gpu.count * size_of(PG), system.particles_gpu.data);
        } else {
            // glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
            // glBufferSubData(GL_ARRAY_BUFFER, 0, system.particles_gpu.count * size_of(PG), system.particles_gpu.data);

            // TODO WHY DOESNT THIS VERSION WORK THOUGH

            starting_byte := system.last_uploaded_index * size_of(PG);
            size_bytes := system.particles_gpu.count * size_of(PG) - starting_byte;

            glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
            glBufferSubData(GL_ARRAY_BUFFER, starting_byte, size_bytes, (cast(*u8) system.particles_gpu.data) + starting_byte);

            system.last_uploaded_index = system.particles_gpu.count;
        }
    } else {
        system.particle_vbo_allocated = system.particles_gpu.allocated;
        glBindBuffer(GL_ARRAY_BUFFER, system.particle_vbo);
        glBufferData(GL_ARRAY_BUFFER, system.particles_gpu.allocated * size_of(PG), system.particles_gpu.data, GL_DYNAMIC_DRAW);  
    }

    cull_face := koda.cull_face;
    if system.cull_face != cull_face {
        set_cull_face(system.cull_face);
    }

    use_shader(system.shader);

    apply_uniforms(system.shader, system.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms[xx "projection"] = create_uniform("projection", projection);
    uniforms[xx "view"] = create_uniform("view", view);
    
    apply_uniforms(system.shader, uniforms);

    depth_func := get_depth_func();
    defer set_depth_func(depth_func);
    set_depth_func(system.depth_func);

    glBindVertexArray(system.vao);
    glDrawElementsInstanced(GL_TRIANGLES, cast(u32) system.indices_count, GL_UNSIGNED_INT, null, cast(u32) system.particles_gpu.count);
    glBindVertexArray(0);

    if system.cull_face != cull_face {
        set_cull_face(cull_face);
    }
}

// TODO addition_count is not technically correct because some particles could remove naturally
// but I guess the assumption is most of the time when you have a limit they never get removed

// TODO add particles sorted insert, because then presumably the list is already sorted if its sorted after each update
particle_system_add_particle :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), particle_gpu: PG, particle_cpu: PC, $limit: int = 0) {
    #if limit {
        if system.particles_gpu.count >= limit {
            system.limit_replace_index = system.limit_replace_index % limit;
            
            system.particles_gpu[system.limit_replace_index] = particle_gpu;
            system.particles_cpu[system.limit_replace_index] = particle_cpu;

            system.limit_replace_index = (system.limit_replace_index + 1) % limit;

            system.particles_gpu.count = limit;
            system.particles_cpu.count = limit;
        } else {
            desired_count := next_power_of_two(system.particles_gpu.count + 1);
            reserve_count := min(desired_count, limit);
            array_reserve(*system.particles_gpu, reserve_count);
            array_reserve(*system.particles_cpu, reserve_count);
            array_add(*system.particles_gpu, particle_gpu);
            array_add(*system.particles_cpu, particle_cpu);
        }
    } else {
        array_add(*system.particles_gpu, particle_gpu);
        array_add(*system.particles_cpu, particle_cpu);
    }
}

particle_system_add_particles :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), particles_gpu: [$N] PG, particles_cpu: [N] PC, $limit: int = 0) {
    gpu_view: [] PG = particles_gpu;
    cpu_view: [] PC = particles_cpu;

    particle_system_add_particles(system, gpu_view, cpu_view, limit);
}

particle_system_add_particles :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), particles_gpu: [] PG, particles_cpu: [] PC, $limit: int = 0) {
    assert(particles_gpu.count == particles_cpu.count, "You must have the same amount of gpu and cpu particles.");
    
    // TODO now that I'm passing in arrays of gpu and cpu separately I can do this way more efficiently

    #if limit {
        if system.particles_gpu.count + particles_gpu.count > limit {
            system.limit_replace_index = system.limit_replace_index % limit;

            if system.particles_gpu.allocated < limit {
                array_reserve(*system.particles_gpu, limit);
                array_reserve(*system.particles_cpu, limit);
            }

            remaining_count := min(particles_gpu.count, limit);
            insert_count := max(limit - system.particles_gpu.count, 0);
            inserted_count := 0;

            // we insert into any available space
            if insert_count > 0 {
                memcpy(system.particles_gpu.data + system.particles_gpu.count, particles_gpu.data, insert_count * size_of(PG));
                memcpy(system.particles_cpu.data + system.particles_cpu.count, particles_cpu.data, insert_count * size_of(PC));
            }
            system.particles_gpu.count = limit;
            system.particles_cpu.count = limit;

            remaining_count -= insert_count;
            inserted_count += insert_count;

            trailing_space := limit - system.limit_replace_index;
            insert_count = min(remaining_count, trailing_space);

            // now we insert from the replace index to the end
            if insert_count > 0 {
                memcpy(system.particles_gpu.data + system.limit_replace_index, particles_gpu.data + inserted_count, insert_count * size_of(PG));
                memcpy(system.particles_cpu.data + system.limit_replace_index, particles_cpu.data + inserted_count, insert_count * size_of(PC));
            }

            remaining_count -= insert_count;
            inserted_count += insert_count;

            system.limit_replace_index = (system.limit_replace_index + insert_count) % limit;

            trailing_space := limit - system.limit_replace_index;
            insert_count = min(remaining_count, trailing_space);

            // now we insert from the new potentially looped replace index to the remaining count
            if insert_count > 0 {
                memcpy(system.particles_gpu.data + system.limit_replace_index, particles_gpu.data + inserted_count, insert_count * size_of(PG));
                memcpy(system.particles_cpu.data + system.limit_replace_index, particles_cpu.data + inserted_count, insert_count * size_of(PC));
            }

            system.limit_replace_index = (system.limit_replace_index + insert_count) % limit;
        } else {
            if system.particles_gpu.allocated < system.particles_gpu.count + particles_gpu.count {
                desired_count := next_power_of_two(system.particles_gpu.count + particles_gpu.count);
                reserve_count := min(desired_count, limit);
                array_reserve(*system.particles_gpu, reserve_count);
                array_reserve(*system.particles_cpu, reserve_count);
            }

            memcpy(system.particles_gpu.data + system.particles_gpu.count, particles_gpu.data, particles_gpu.count * size_of(PG));
            memcpy(system.particles_cpu.data + system.particles_cpu.count, particles_cpu.data, particles_cpu.count * size_of(PC));

            system.particles_gpu.count += particles_gpu.count;
            system.particles_cpu.count += particles_cpu.count;
        }
    } else {
        if system.particles_gpu.allocated < system.particles_gpu.count + particles_gpu.count {
            desired_count := next_power_of_two(system.particles_gpu.count + particles_gpu.count);
            array_reserve(*system.particles_gpu, desired_count);
            array_reserve(*system.particles_cpu, desired_count);
        }

        memcpy(system.particles_gpu.data + system.particles_gpu.count, particles_gpu.data, particles_gpu.count * size_of(PG));
        memcpy(system.particles_cpu.data + system.particles_cpu.count, particles_cpu.data, particles_cpu.count * size_of(PC));

        system.particles_gpu.count += particles_gpu.count;
        system.particles_cpu.count += particles_cpu.count;
    }
}

particle_system_add_particle_synchronous :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), particle_gpu: PG, particle_cpu: PC, $limit: int = 0) {
    lock(*system.synchronous_lock);
    defer unlock(*system.synchronous_lock);

    particle_system_add_particle(system, particle_gpu, particle_cpu, limit);
} @thread

particle_system_add_particles_synchronous :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), particles_gpu: [$N] PG, particles_cpu: [N] PC, $limit: int = 0) {
    gpu_view: [] PG = particles_gpu;
    cpu_view: [] PC = particles_cpu;

    particle_system_add_particles_synchronous(system, gpu_view, cpu_view, limit);
} @thread

particle_system_add_particles_synchronous :: (system: *ParticleSystem($PG, $PC, $update_function, $sort), particles_gpu: [] PG, particles_cpu: [] PC, $limit: int = 0) {
    lock(*system.synchronous_lock);
    defer unlock(*system.synchronous_lock);

    particle_system_add_particles(system, particles_gpu, particles_cpu, limit);
} @thread

particle_system_clear :: (system: *ParticleSystem) {
    system.particles_gpu.count = 0;
    system.particles_cpu.count = 0;
    system.particles_gpu_buffer.count = 0;
    system.particles_cpu_buffer.count = 0;
    system.depth_values.count = 0;
    system.last_uploaded_index = 0;
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
