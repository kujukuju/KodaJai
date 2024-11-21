
Shader :: struct {
    program: u32;
    uniforms: ShaderUniforms;
    vertex_parts: [] ResolvedShaderPart;
    fragment_parts: [] ResolvedShaderPart;
    output_channels: [] int;
    uniform_locations: [] UniformLocation;
    name: string;
    has_vertex_shader: bool;
    has_fragment_shader: bool;

    #if HOT_LOAD_SHADERS {
        watching: bool;
        watch_files: [] string;
        last_dependencies: [] Any;
        last_dependency_names: [] string;
    }
}

UniformLocation :: struct {
    name: FixedString(UNIFORM_LENGTH);
    type: ShaderUniformType;
    location: s32;
}

ShaderDependency :: struct {
    name: string;
    value: Any;
}

HOT_LOAD_SHADERS :: false;
