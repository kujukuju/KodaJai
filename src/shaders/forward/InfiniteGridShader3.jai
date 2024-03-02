
InfiniteGridShader3 :: struct {
    using #as shader: Shader;

    shader.name = "InfiniteGridShader3";
    shader.vertex = INFINITE_GRID_VERTEX_SHADER3;
    shader.fragment = INFINITE_GRID_FRAGMENT_SHADER3;
}

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
    cameraCoord.z = -1.0;
    cameraCoord.w = 0.0;

    vec4 worldDirection = inverse(view) * cameraCoord;

    return normalize(worldDirection.xyz);
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

            float width = length(rayVec) / 1000.0 * 1.5;
            if (coord.x > -width * 2.0 && coord.x < width * 2.0) {
                width *= 2.0;
            } else if (coord.y > -width * 2.0 && coord.y < width * 2.0) {
                width *= 2.0;
            }

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
                vec4 clipSpace = inverse(projection) * viewSpace;
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
