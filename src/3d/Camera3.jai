Camera3 :: struct {
    position: Vector3;
    rotation: Quaternion;
}

get_transform :: (using camera: Camera3) -> Matrix4 {
    matrix: Matrix4 = Matrix4Identity;
    matrix = rotate(matrix, rotation);
    matrix = translate(matrix, -position);

    return matrix;
}

get_forward_vector :: (using camera: Camera3) -> Vector3 {
    forward := rotate(Vector3.{0, 0, -1}, conjugate(rotation));

    return forward;
}

get_up_vector :: (using camera: Camera3) -> Vector3 {
    up := rotate(Vector3.{0, 1, 0}, conjugate(rotation));

    return up;
}

get_right_vector :: (using camera: Camera3) -> Vector3 {
    right := rotate(Vector3.{1, 0, 0}, conjugate(rotation));

    return right;
}

look_at :: (using camera: *Camera3, target: Vector3) {
    matrix := make_look_at_matrix(camera.position, target, .{0, 1, 0}, false);
    camera.rotation = get_rotation(matrix);

    // to_vector := normalize(target - position);

    // // compute rotation axis
    // rot_axis := normalize(cross(.{0, 0, -1}, to_vector));
    // if length_squared(rot_axis) == 0 {
    //     rot_axis = .{0, 1, 0};
    // }

    // // find the angle around rotation axis
    // dot_product := dot(.{0, 0, -1}, to_vector);
    // ang := acos(dot_product);

    // rotation = make_rotation_quaternion(rot_axis, ang);
}
