// Mesh :: struct {
//     geometry: Geometry;
//     materials: [..] Material;
// }

// free :: (mesh: Mesh) {

// }

// add_material :: (mesh: *Mesh, texture: Texture) -> *Material {
//     material: Material;
//     material.texture = texture;

//     array_add(*mesh.materials, material);

//     return *mesh.materials[mesh.materials.count - 1];
// }

// add_material :: (mesh: *Mesh, material: Material) {
//     array_add(*mesh.materials, material);
// }

// draw_mesh :: (mesh: Mesh, position: Vector3 = .{}, rotation: Quaternion = .{}) {
//     use_shader(*default_shader3);

//     projection := get_perspective_matrix();
//     model := make_translation_matrix4(position);
//     view := koda.view;

//     uniforms: ShaderUniforms;
//     defer free(uniforms);
    
//     uniforms["projection"] = create_uniform("projection", projection);
//     uniforms["model"] = create_uniform("model", model);
//     uniforms["view"] = create_uniform("view", view);

//     for i: 0..mesh.materials.count - 1 {
//         glActiveTexture(xx (GL_TEXTURE0 + i));
//         glBindTexture(GL_TEXTURE_2D, mesh.materials[i].texture.buffer);

//     uniforms["view"] = create_uniform("view", view);
//         set_uniform(*default_shader, tprint("uTexture%", i), i);
//     }
//     glActiveTexture(GL_TEXTURE0);

//     glBindVertexArray(mesh.geometry.vao_);
//     glDrawElements(GL_TRIANGLES, xx mesh.geometry.indices.count, GL_UNSIGNED_INT, xx 0);
//     glBindVertexArray(0);
//     glBindTexture(GL_TEXTURE_2D, 0);
// }
