
// note depth calculations use the depth value from view space
// so we need to get the corners of the view matrix when they are max_depth distance away from the view camera plane
calculate_directional_shadow_matrices :: (forward: Vector3, max_depth: float, min_depth: float = 0.0) -> view: Matrix4, projection: Matrix4 {
    shadow_forward := normalize(forward);

    view := koda.view;
    view_inv := inverse(view);
    projection := get_perspective_matrix();
    projection_inv := inverse(projection);

    camera_position := transform_point(view_inv, .{0, 0, 0});
    camera_forward := normalize(transform_vector(view_inv, .{0, 0, -1}));

    max_depth_plane := create_plane3(camera_position + camera_forward * max_depth, camera_forward);

    top_left := projection_inv * Vector4.{-1.0, 1.0, -1.0, 1.0};
    top_left.z -1.0;
    top_left.w = 0.0;
    top_left = view_inv * top_left;
    top_left_dir := normalize(top_left.xyz);
    top_left_ray := Ray3.{camera_position, top_left_dir};

    top_right := projection_inv * Vector4.{1.0, 1.0, -1.0, 1.0};
    top_right.z -1.0;
    top_right.w = 0.0;
    top_right = view_inv * top_right;
    top_right_dir := normalize(top_right.xyz);
    top_right_ray := Ray3.{camera_position, top_right_dir};

    bottom_left := projection_inv * Vector4.{-1.0, -1.0, -1.0, 1.0};
    bottom_left.z -1.0;
    bottom_left.w = 0.0;
    bottom_left = view_inv * bottom_left;
    bottom_left_dir := normalize(bottom_left.xyz);
    bottom_left_ray := Ray3.{camera_position, bottom_left_dir};

    bottom_right := projection_inv * Vector4.{1.0, -1.0, -1.0, 1.0};
    bottom_right.z -1.0;
    bottom_right.w = 0.0;
    bottom_right = view_inv * bottom_right;
    bottom_right_dir := normalize(bottom_right.xyz);
    bottom_right_ray := Ray3.{camera_position, bottom_right_dir};

    top_left_point := intersection_simple(max_depth_plane, top_left_ray);
    top_right_point := intersection_simple(max_depth_plane, top_right_ray);
    bottom_left_point := intersection_simple(max_depth_plane, bottom_left_ray);
    bottom_right_point := intersection_simple(max_depth_plane, bottom_right_ray);

    // calculate the point distances off of the 2 bounds defined at the camera origin

    shadow_up: Vector3;
    if abs(dot(.{1, 0, 0}, shadow_forward)) > abs(dot(.{0, 0, -1}, shadow_forward)) {
        // forward is more aligned with x so we choose z
        shadow_up = normalize(cross(.{0, 0, -1}, shadow_forward));
    } else {
        shadow_up = normalize(cross(.{1, 0, 0}, shadow_forward));
    }
    shadow_right := normalize(cross(shadow_forward, shadow_up));

    plane_up := create_plane3(camera_position, shadow_up);
    plane_right := create_plane3(camera_position, shadow_right);
    plane_forward := create_plane3(camera_position, shadow_forward);

    up_distance := 0.0;
    down_distance := 0.0;
    right_distance := 0.0;
    left_distance := 0.0;
    forward_distance := 0.0;
    backward_distance := 0.0;

    camera_points := Vector3.[camera_position, top_left_point, top_right_point, bottom_left_point, bottom_right_point];
    for camera_point: camera_points {
        plane_up_distance := distance(plane_up, camera_point);
        plane_right_distance := distance(plane_right, camera_point);
        plane_forward_distance := distance(plane_forward, camera_point);

        up_distance = max(up_distance, plane_up_distance);
        down_distance = max(down_distance, -plane_up_distance);
        right_distance = max(right_distance, plane_right_distance);
        left_distance = max(left_distance, -plane_right_distance);
        forward_distance = max(forward_distance, plane_forward_distance);
        backward_distance = max(backward_distance, -plane_forward_distance);
    }

    // TODO add a perspective lock thing that forces the light to a certain width height?
    // doesn't matter for fixed perspective games

    // basically adding the 2 directions and averaging them
    center_up_distance := (up_distance - down_distance) / 2.0;
    center_right_distance := (right_distance - left_distance) / 2.0;

    // if there needs to be padding add it to start
    ortho_center := camera_position + center_up_distance * shadow_up + center_right_distance * shadow_right;
    ortho_start := ortho_center - shadow_forward * backward_distance;

    ortho_depth := forward_distance + backward_distance;
    ortho_width := right_distance + left_distance;
    ortho_height := up_distance + down_distance;

    shadow_view := make_look_at_matrix(ortho_start, ortho_start + forward, .{0, 1, 0}, false);

    shadow_projection := create_orthographic_matrix(-ortho_width / 2, ortho_width / 2, -ortho_height / 2, ortho_height / 2, 0, -ortho_depth);
    // shadow_projection := orthographic_projection_matrix(-ortho_width / 2.0, ortho_width / 2.0, -ortho_height / 2.0, ortho_height / 2.0, ortho_depth, -ortho_depth, depth_range_01 = true);

    return shadow_view, shadow_projection;
}