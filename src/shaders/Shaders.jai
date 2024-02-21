
// TODO for now I'm just calling glGetUniformLocation every time, but I probably shouldnt be
Shader :: struct {
    program: u32;
    vertex: string;
    fragment: string;
    uniforms: ShaderUniforms;
    vertex_extra: [] string;
    fragment_extra: [] string;
}

// TODO I need to auto create shaders with all their uniforms and defaults
// TODO then I can allow textures in passes to have uniform names, and assign them like
/*

GLint baseImageLoc = glGetUniformLocation(program, "baseImage");
GLint normalMapLoc = glGetUniformLocation(program, "normalMap");
GLint shadowMapLoc = glGetUniformLocation(program, "shadowMap");

glUseProgram(program);
glUniform1i(baseImageLoc, 0); // Texture unit 0 is for base images.
glUniform1i(normalMapLoc, 2); // Texture unit 2 is for normal maps.
glUniform1i(shadowMapLoc, 4); // Texture unit 4 is for shadow maps.

// When rendering an object with this program.
glActiveTexture(GL_TEXTURE0 + 0);
glBindTexture(GL_TEXTURE_2D, object1BaseImage);
glBindSampler(0, linearFiltering);
glActiveTexture(GL_TEXTURE0 + 2);
glBindTexture(GL_TEXTURE_2D, object1NormalMap);
glBindSampler(2, linearFiltering); // Same filtering as before
glActiveTexture(GL_TEXTURE0 + 4);
glBindTexture(GL_TEXTURE_2D, shadowMap);
glBindSampler(4, depthComparison); // Special sampler for depth comparisons.

*/

operator == :: (a: Shader, b: Shader) -> bool {
    return a.vertex.data == b.vertex.data && a.fragment.data == b.fragment.data;
}

initialize_shader :: (shader: *Shader) {
    if shader.program > 0 {
        return;
    }

    make_shader_object :: (shader: string, extra: [] string, shader_type: GLenum) -> GLuint, bool #must {
        shader_object := glCreateShader(shader_type);

        source_strings := NewArray(extra.count + 1, *u8,, allocator = temp);
        source_lengths := NewArray(extra.count + 1, s32,, allocator = temp);

        source_strings[source_strings.count - 1] = shader.data;
        source_lengths[source_strings.count - 1] = cast(s32) shader.count;
        for i: 0..extra.count - 1 {
            source_strings[i] = extra[i].data;
            source_lengths[i] = cast(s32) extra[i].count;
        }

        glShaderSource(shader_object, 1, source_strings.data, source_lengths.data);
        glCompileShader(shader_object);

        success: s32;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success {
            message: [512] u8;
            glGetShaderInfoLog(shader_object, 512, null, message.data);

            type_string: string;
            if shader_type == {
                case GL_VERTEX_SHADER;
                    type_string = "Vertex Shader";
                case GL_FRAGMENT_SHADER;
                    type_string = "Fragment Shader";
                case;
                    type_string = "Unknown Shader Type";
            }

            // try to build out the error data, but we're allowed to exit at any point to avoid super deep nesting
            error_line: string = "Could not find shader error line. This is an internal library error.";
            defer print("Shader compile error:\n\t%\n\t%\n\t%\n", type_string, error_line, to_string(message.data));

            source_index_string: string;
            source_index_string.data = message.data;
            source_index_string.count = message.count;
            
            if source_index_string[0] == #char "\0" {
                return 0, false;
            }

            index := 0;
            while index < source_index_string.count && source_index_string[index] != #char "(" && source_index_string[index] != #char "\0" {
                index += 1;
            }
            source_index_string.count = index;

            source_index, source_index_found := parse_int(*source_index_string);
            if !source_index_found {
                return 0, false;
            }

            if message[index] != #char "(" {
                return 0, false;
            }

            line_number_string: string;
            line_number_string.data = message.data + index + 1;
            line_number_string.count = message.count - index - 1;

            index = 0;
            while index < line_number_string.count && line_number_string[index] != #char ")" && line_number_string[index] != #char "\0" {
                index += 1;
            }
            line_number_string.count = index;

            line_number, line_number_found := parse_int(*line_number_string);
            if !line_number_found {
                return 0, false;
            }
            line_index := line_number - 1;

            error_source: string;
            error_source.data = source_strings[source_index];
            error_source.count = source_lengths[source_index];

            shader_lines := split(error_source, "\n",, allocator = temp);
            if line_index < shader_lines.count {
                error_line = shader_lines[line_index];
            }

            return 0, false;
        }

        return shader_object, true;
    }

    shader_v, success_v := make_shader_object(shader.vertex, shader.vertex_extra, GL_VERTEX_SHADER);
    defer glDeleteShader(shader_v);
    if !success_v {
        print("Could not initialized vertex shader.\n");
    }
    shader_f, success_f := make_shader_object(shader.fragment, shader.fragment_extra, GL_FRAGMENT_SHADER);
    defer glDeleteShader(shader_f);
    if !success_f {
        print("Could not initialized fragment shader.\n");
    }
    shader.program = glCreateProgram();

    if !success_v || !success_f || !shader.program {
        glDeleteProgram(shader.program);
        print("Failure initalizing shader.\n");

        shader.program = 0;

        assert(false, "Failure initializing shader.");
    }

    glAttachShader(shader.program, shader_v);
    glAttachShader(shader.program, shader_f);
    glLinkProgram(shader.program);

    success: GLint;
    glGetProgramiv(shader.program, GL_LINK_STATUS, *success);

    if !success {
        message: [512] u8;
        glGetProgramInfoLog(shader.program, 512, null, message.data);
        print("Shader error: %\n", to_string(message.data));

        glDeleteProgram(shader.program);
        shader.program = 0;

        assert(false, "Shader error.");
    }
}

destroy_shader :: (shader: Shader) {
    free(shader.vertex);
    free(shader.fragment);
    array_free(shader.uniforms.uniforms);
    glDeleteProgram(shader.program);
}

// TODO apply_uniform singular as well? maybe impossible bc of textures

apply_uniforms :: (shader: *Shader, uniforms: ShaderUniforms, printing: bool = false) {
    if shader != koda.shader {
        print("Applying uniforms to inactive shader. This is very unusual. I'm even considering disallowing this.\n");
        print_stack_trace();
    }

    // final_uniforms: ShaderUniforms;
    // defer destroy(final_uniforms);

    // for uniform: shader.uniforms.uniforms {
    //     shader.uniforms[xx uniform.name] = uniform;
    //     shader.uniforms[xx uniform.name].ownership = false;
    //     debug_shaders && print("set % % %\n", to_string(uniform.name), uniform, shader.uniforms[xx uniform.name].*);
    // }

    for uniform: uniforms.uniforms {
        existing := shader.uniforms[xx uniform.name];
        shader.uniforms[xx uniform.name] = uniform;
        shader.uniforms[xx uniform.name].ownership = false;
        
        if existing && existing.location {
            shader.uniforms[xx uniform.name].location = existing.location;
        }
    }

    // TODO because currently the shader does not own its own memory, this is leaking memory every frame
    // TODO so the shader should have uniforms that it owns, and then there should be an unowned stack uniform that gets applied or something

    // the uniforms stay in order for the shaders uniforms, so after we apply all the uniforms we can lookup the texture indices by iterating over them in order
    // for *uniform: uniforms.uniforms {
        texture_index: s32;

        for *uniform: shader.uniforms.uniforms {
            if uniform.location == -1 {
                continue;
            }

            // if uniform.name == shader_uniform.name {
                // TODO this could be improved if I force uniform names to be less than a certain size, and use fixed strings
                location := glGetUniformLocation(shader.program, uniform.name);
                uniform.location = location;
                if location == -1 {
                    continue;
                }

                if #complete uniform.type == {
                    case .Float1;
                        glUniform1f(location, uniform.float1);
                    case .Float1N;
                        glUniform1fv(location, xx uniform.float1n.count, uniform.float1n.data);
                    case .Float2;
                        glUniform2f(location, uniform.float2[0], uniform.float2[1]);
                    case .Float2N;
                        glUniform2fv(location, xx uniform.float2n.count, cast(*float) uniform.float2n.data);
                    case .Float3;
                        glUniform3f(location, uniform.float3[0], uniform.float3[1], uniform.float3[2]);
                    case .Float3N;
                        glUniform3fv(location, xx uniform.float3n.count, cast(*float) uniform.float3n.data);
                    case .Float4;
                        glUniform4f(location, uniform.float4[0], uniform.float4[1], uniform.float4[2], uniform.float4[3]);
                    case .Float4N;
                        glUniform4fv(location, xx uniform.float4n.count, cast(*float) uniform.float4n.data);
                    case .Int1;
                        glUniform1i(location, uniform.int1);
                    case .Int1N;
                        glUniform1iv(location, xx uniform.int1n.count, uniform.int1n.data);
                    case .Int2;
                        glUniform2i(location, uniform.int2[0], uniform.int2[1]);
                    case .Int2N;
                        glUniform2iv(location, xx uniform.int2n.count, cast(*s32) uniform.int2n.data);
                    case .Int3;
                        glUniform3i(location, uniform.int3[0], uniform.int3[1], uniform.int3[2]);
                    case .Int3N;
                        glUniform3iv(location, xx uniform.int3n.count, cast(*s32) uniform.int3n.data);
                    case .Int4;
                        glUniform4i(location, uniform.int4[0], uniform.int4[1], uniform.int4[2], uniform.int4[3]);
                    case .Int4N;
                        glUniform4iv(location, xx uniform.int4n.count, cast(*s32) uniform.int4n.data);
                    case .UInt1;
                        glUniform1ui(location, uniform.uint1);
                    case .UInt1N;
                        glUniform1uiv(location, xx uniform.uint1n.count, uniform.uint1n.data);
                    case .UInt2;
                        glUniform2ui(location, uniform.uint2[0], uniform.uint2[1]);
                    case .UInt2N;
                        glUniform2uiv(location, xx uniform.uint2n.count, cast(*u32) uniform.uint2n.data);
                    case .UInt3;
                        glUniform3ui(location, uniform.uint3[0], uniform.uint3[1], uniform.uint3[2]);
                    case .UInt3N;
                        glUniform3uiv(location, xx uniform.uint3n.count, cast(*u32) uniform.uint3n.data);
                    case .UInt4;
                        glUniform4ui(location, uniform.uint4[0], uniform.uint4[1], uniform.uint4[2], uniform.uint4[3]);
                    case .UInt4N;
                        glUniform4uiv(location, xx uniform.uint4n.count, cast(*u32) uniform.uint4n.data);
                    case .Mat2;
                        glUniformMatrix2fv(location, 1, true, cast(*float) uniform.mat2.data);
                    case .Mat2N;
                        glUniformMatrix2fv(location, xx uniform.mat2n.count, true, cast(*float) uniform.mat2n.data);
                    case .Mat3;
                        glUniformMatrix3fv(location, 1, true, cast(*float) uniform.mat3.data);
                    case .Mat3N;
                        glUniformMatrix3fv(location, xx uniform.mat3n.count, true, cast(*float) uniform.mat3n.data);
                    case .Mat4;
                        glUniformMatrix4fv(location, 1, true, cast(*float) uniform.mat4.data);
                    case .Mat4N;
                        glUniformMatrix4fv(location, xx uniform.mat4n.count, true, cast(*float) uniform.mat4n.data);
                    case .Texture;
                        glActiveTexture(GL_TEXTURE0 + cast(u32) texture_index);
                        glBindTexture(GL_TEXTURE_2D, uniform.texture.buffer);
                        glUniform1i(location, texture_index);

                        texture_index += 1;
                    case .Texture3;
                        glActiveTexture(GL_TEXTURE0 + cast(u32) texture_index);
                        glBindTexture(GL_TEXTURE_3D, uniform.texture3.buffer);
                        glUniform1i(location, texture_index);

                        texture_index += 1;
                    case .CubemapTexture;
                        glActiveTexture(GL_TEXTURE0 + cast(u32) texture_index);
                        glBindTexture(GL_TEXTURE_CUBE_MAP, uniform.cubemap_texture.buffer);
                        glUniform1i(location, texture_index);

                        texture_index += 1;
                    // case .TextureN;
                    //     // TODO no allocations
                    //     texture_values := NewArray(uniform.uint1n.count, u32, initialized = false);
                    //     defer array_free(texture_values);

                    //     for i: 0..uniform.uint1n.count - 1 {
                    //         glActiveTexture(GL_TEXTURE0 + texture_index);
                    //         glBindTexture(GL_TEXTURE_2D, uniform.uint1n[i]);
                    //         texture_values[i] = texture_index;

                    //         texture_index += 1;
                    //     }
                    //     glUniform1uiv(location, xx texture_values.count, texture_values.data);
                }
            // } else {
            //     if shader_uniform.type == {
            //         case .Texture;
            //             texture_index += 1;
            //         case .Texture3;
            //             texture_index += 1;
            //         case .CubemapTexture;
            //             texture_index += 1;
            //         // case .TextureN;
            //         //     texture_index += cast(u32) shader_uniform.uint1n.count;
            //     }
            // }
        }
    // }

    // TODO is it important to set back glActiveTexture(GL_TEXTURE0); here?
}

use_shader :: (shader: *Shader) {
    if !shader.program {
        initialize_shader(shader);

        if !shader.program {
            print("Cannot use shader. You must initialized it first.\n");
            assert(false, "Cannot use uninitialized shader.");
            return;
        }
    }

    if koda.active_program == shader.program {
        return;
    }

    glUseProgram(shader.program);
    koda.active_program = shader.program;
    koda.shader = shader;
}

#import "Basic";