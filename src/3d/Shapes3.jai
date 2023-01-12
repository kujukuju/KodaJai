draw_line :: () {

}

draw_infinite_grid :: (center: Vector3 = .{0, 0, 0}, normal: Vector3 = .{0, 1, 0}, forward: Vector3 = .{1, 0, 0}, radius: float = 0.0, spacing: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    vertices: [6] Vector2;
    vertices[0] = .{-1, -1};
    vertices[1] = .{-1, 1};
    vertices[2] = .{1, 1};
    vertices[3] = .{-1, -1};
    vertices[4] = .{1, 1};
    vertices[5] = .{1, -1};

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), *vertices, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, size_of(Vector2), null);

    use_shader(*infinite_grid_shader);

    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer free(uniforms);

    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["view"] = create_uniform("view", view);
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uPosition"] = create_uniform("uPosition", center);
    uniforms["uNormal"] = create_uniform("uNormal", normal);
    uniforms["uForward"] = create_uniform("uForward", forward);
    uniforms["uRadius"] = create_uniform("uRadius", radius);
    uniforms["uSpacing"] = create_uniform("uSpacing", spacing);

    apply_uniforms(*infinite_grid_shader, uniforms);

    // depth_test := get_depth_test();
    // set_depth_test(false);
    // defer set_depth_test(depth_test);

    cull_face := get_cull_face();
    set_cull_face(false);
    defer set_cull_face(cull_face);

    glDepthMask(GL_TRUE);

    glDrawArrays(GL_TRIANGLES, 0, xx vertices.count);
}

draw_sphere :: (position: Vector3, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }

    draw_mesh(sphere, position);
}

draw_spheres :: (positions: [] Vector3, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }
    
    // bad duplicate code from draw_mesh :(

    use_shader(*instanced_shader3);

    projection := make_frustum_matrix(-1.92, 1.92, -1.08, 1.08, 1.4, -1.4);
    model := Matrix4_Identity;
    view := koda.transform;

    white_texture := get_white_texture();

    uniforms: ShaderUniforms;
    defer free(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uFrame"] = create_uniform("uFrame", Vector4.{0, 0, 1, 1});

    uniforms["uTexture0"] = create_uniform("uTexture0", white_texture.buffer);

    apply_uniforms(*instanced_shader3, loop_uniforms);

    // TODO use attributes or whatever instead of looping this shader 1000 times
    index: int;
    while index < positions.count {
        defer index += 1000;

        remaining_count := min(1000, positions.count - index);

        offsets: [] Vector3;
        offsets.data = positions.data + index;
        offsets.count = remaining_count;

        loop_uniforms: ShaderUniforms;
        defer free(loop_uniforms);
        loop_uniforms["offsets"] = create_uniform("offsets", offsets);

        apply_uniforms(*instanced_shader3, loop_uniforms);

        glBindVertexArray(sphere.geometry.vao_);
        glDrawElementsInstanced(GL_TRIANGLES, xx sphere.geometry.vertex_indices.count, GL_UNSIGNED_INT, xx 0, xx remaining_count);
    }

    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

#scope_file

INFINITE_GRID_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;

uniform mat4 view;
uniform mat4 projection;

out vec2 vPos;
// out vec3 vPos;

void main() {
    // vec4 position = vec4(aPos, 1.0, 1.0);

    // mat4 matrixInverse = inverse(view * projection);
    // vec4 world = position * matrixInverse;
    // world.w = 1.0 / world.w;
    // world.x *= world.w;
    // world.y *= world.w;
    // world.z *= world.w;

    // vPos = world.xyz;

    vPos = aPos;

    gl_Position = vec4(aPos, 0.0, 1.0);
}
DONE

INFINITE_GRID_FRAGMENT_SHADER3 :: #string DONE
#version 330 core

out vec4 FragColor;

uniform mat4 view;
uniform mat4 projection;

uniform vec4 uTint;
uniform vec3 uPosition;
uniform vec3 uNormal;
uniform vec3 uForward;
uniform float uRadius;
uniform float uSpacing;

in vec2 vPos;
// in vec3 vPos;

// TODO the ray can be moved to the vertex shader im almost certain

vec3 getRayDirection(vec2 uv) {
    vec4 cameraCoord = inverse(projection) * vec4(uv, -1.0, 1.0);
    cameraCoord.z -1.0;
    cameraCoord.w = 0.0;

    vec4 worldCoord = inverse(view) * cameraCoord;

    return normalize(worldCoord.xyz);
}

vec2 getCoordinate(vec3 point, vec3 center, vec3 normal, vec3 forward) {
    float distance = (point.x - center.x) * normal.x + 
        (point.y - center.y) * normal.y + 
        (point.z - center.z) * normal.z;

    vec3 projected = vec3(point.x - distance * normal.x, 
        point.y - distance * normal.y, 
        point.z - distance * normal.z);

    vec3 xaxis = forward;
    vec3 yaxis = vec3(
        normal.y * forward.z - normal.z * forward.y,
        normal.z * forward.x - normal.x * forward.z,
        normal.x * forward.y - normal.y * forward.x);

    return vec2(
        projected.x * xaxis.x + projected.y * xaxis.y + projected.z * xaxis.z,
        projected.x * yaxis.x + projected.y * yaxis.y + projected.z * yaxis.z);
}

void main() {
    vec3 planeCenter = uPosition;
    vec3 planeNormal = uNormal;
    vec3 planeForward = uForward;

    vec3 rayOrigin = (inverse(view) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 rayDir = getRayDirection(vPos);

    float denom = dot(rayDir, planeNormal);
    if (abs(denom) < 0.00001) {
        discard;
    } else {
        float t = dot(planeCenter - rayOrigin, planeNormal) / denom;
        if (t > 0) {
            vec3 rayVec = t * rayDir;
            vec3 p = rayOrigin + rayVec;

            vec2 coord = getCoordinate(p, planeCenter, planeNormal, planeForward);
            float xmod = mod(coord.x, uSpacing);
            float ymod = mod(coord.y, uSpacing);

            float width = length(rayVec) / 1000.0;

            float sub = 1.0;
            float alpha = 1.0;
            if (uRadius > 0.0) {
                sub = clamp((uRadius - length(p - planeCenter)) / 10.0, 0.0, 1.0);
                alpha = clamp((uRadius - length(p - planeCenter)) / uRadius, 0.0, 1.0);
                alpha = sqrt(alpha) * 0.75 + 0.25;
            }
            width = width * sub;
            float upper = uSpacing - width;
            float lower = width;

            if (xmod > upper || xmod < lower || ymod > upper || ymod < lower) {
                FragColor = vec4(1.0, 1.0, 1.0, 1.0) * alpha;

                vec4 viewSpace = view * vec4(p, 1.0);
                vec4 clipSpace = projection * viewSpace;
                float ndcDepth = clipSpace.z / clipSpace.w;
                float near = 0.0;
                float far = 1.0;
                gl_FragDepth = (((far - near) * ndcDepth) + near + far) / 2.0;
            } else {
                discard;
            }
        } else {
            discard;
        }
    }
}
DONE

InfiniteGridShader3 :: struct {
    using #as shader: Shader;

    shader.vertex = INFINITE_GRID_VERTEX_SHADER3;
    shader.fragment = INFINITE_GRID_FRAGMENT_SHADER3;
}

load_sphere :: () {
    if sphere_loaded {
        return;
    }

    sphere_loaded = true;
    sphere = create_icosphere(0.1, 1);
}

sphere: Geometry;
sphere_loaded: bool;
infinite_grid_shader: InfiniteGridShader3;
