DefaultEllipseShader :: struct {
    using shader: Shader;

    shader.vertex = DEFAULT_ELLIPSE_VERTEX_SHADER;
    shader.fragment = DEFAULT_ELLIPSE_FRAGMENT_SHADER;
}