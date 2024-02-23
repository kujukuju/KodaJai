
// note depth calculations use the depth value from view space
// so we need to get the corners of the view matrix when they are max_depth distance away from the view camera plane

// 1. we will enable pixel snapping if fixed shadow direction or fixed view direction is supplied, and shadow dimensions are supplied
// 2. if pixel snapping is enabled the shadow projection dimensions will assume worst case scenario angles
//    if pixel snapping is enabled and fixed shadow direction is enabled and fixed view direction is enabled the shadow projection matrix will assume best case scenario angles
// 3. if lock ratio is enabled the boundaries will be expanded so from the shadows perspective each pixel is square
calculate_directional_shadow_matrices :: (
        forward: Vector3,
        max_depth: float,
        min_depth: float = 0.0,
        fixed_shadow_direction: bool = false,
        fixed_view_direction: bool = false,
        shadow_texture_dimensions: Point2 = .{},
        shadow_texture_lock_ratio: bool = false) -> view: Matrix4, projection: Matrix4 {
    shadow_forward := normalize(forward);

    view := koda.view;
    view_inv := inverse(view);
    projection := get_perspective_matrix();
    projection_inv := inverse(projection);

    camera_position := transform_point(view_inv, .{0, 0, 0});
    camera_forward := normalize(transform_vector(view_inv, .{0, 0, -1}));

    max_depth_plane := create_plane3(camera_position + camera_forward * max_depth, camera_forward);

    // TODO should the 4th value here really be 1.0? we're trying to get a direction are we not? idk....
    top_left_dir := transform_point(projection_inv, .{-1.0, 1.0, -1.0});
    top_left_dir = transform_vector(view_inv, top_left_dir);
    top_left_dir = normalize(top_left_dir);
    top_left_ray := Ray3.{camera_position, top_left_dir};

    top_right_dir := transform_point(projection_inv, .{1.0, 1.0, -1.0});
    top_right_dir = transform_vector(view_inv, top_right_dir);
    top_right_dir = normalize(top_right_dir);
    top_right_ray := Ray3.{camera_position, top_right_dir};

    bottom_left_dir := transform_point(projection_inv, .{-1.0, -1.0, -1.0});
    bottom_left_dir = transform_vector(view_inv, bottom_left_dir);
    bottom_left_dir = normalize(bottom_left_dir);
    bottom_left_ray := Ray3.{camera_position, bottom_left_dir};

    bottom_right_dir := transform_point(projection_inv, .{1.0, -1.0, -1.0});
    bottom_right_dir = transform_vector(view_inv, bottom_right_dir);
    bottom_right_dir = normalize(bottom_right_dir);
    bottom_right_ray := Ray3.{camera_position, bottom_right_dir};

    top_left_point := intersection_simple(max_depth_plane, top_left_ray);
    top_right_point := intersection_simple(max_depth_plane, top_right_ray);
    bottom_left_point := intersection_simple(max_depth_plane, bottom_left_ray);
    bottom_right_point := intersection_simple(max_depth_plane, bottom_right_ray);
    near_top_left_point := camera_position;
    near_top_right_point := camera_position;
    near_bottom_left_point := camera_position;
    near_bottom_right_point := camera_position;
    // TODO min_depth for near points if applicable

    incorrect_center := top_left_point + 
        top_right_point + 
        bottom_left_point + 
        bottom_right_point + 
        near_top_left_point + 
        near_top_right_point + 
        near_bottom_left_point + 
        near_bottom_right_point;
    incorrect_center /= 8.0;

    // calculate the point distances off of the 2 bounds defined at the camera origin

    shadow_up: Vector3;
    if abs(dot(.{1, 0, 0}, shadow_forward)) > abs(dot(.{0, 0, -1}, shadow_forward)) {
        // forward is more aligned with x so we choose z
        shadow_up = normalize(cross(.{0, 0, -1}, shadow_forward));
    } else {
        shadow_up = normalize(cross(.{1, 0, 0}, shadow_forward));
    }
    shadow_right := normalize(cross(shadow_forward, shadow_up));

    plane_up := create_plane3(incorrect_center, shadow_up);
    plane_right := create_plane3(incorrect_center, shadow_right);
    plane_forward := create_plane3(incorrect_center, shadow_forward);

    // now we go through and calculate the distances to each direction of the 6 sided cube ortho matrix relative to the incorrect center
    up_distance := 0.0;
    down_distance := 0.0;
    right_distance := 0.0;
    left_distance := 0.0;
    forward_distance := 0.0;
    backward_distance := 0.0;

    frustum_points := Vector3.[
        top_left_point, 
        top_right_point, 
        bottom_left_point, 
        bottom_right_point, 
        near_top_left_point,
        near_top_right_point,
        near_bottom_left_point,
        near_bottom_right_point,
    ];

    for frustum_point: frustum_points {
        plane_up_distance := distance(plane_up, frustum_point);
        plane_right_distance := distance(plane_right, frustum_point);
        plane_forward_distance := distance(plane_forward, frustum_point);

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
    ortho_center := incorrect_center + center_up_distance * shadow_up + center_right_distance * shadow_right;
    ortho_start := ortho_center - shadow_forward * backward_distance;

    ortho_depth := forward_distance + backward_distance;
    ortho_width := right_distance + left_distance;
    ortho_height := up_distance + down_distance;

    pixel_snapping := shadow_texture_dimensions != .{};
    if pixel_snapping && fixed_shadow_direction && fixed_view_direction {
        // I need to redo the calculations here with a position-fixed view matrix, but with the correct direction
        fixed_view_forward := transform_vector(view_inv, .{0, 0, -1});
        view_ident := make_look_at_matrix(.{0, 0, 0}, fixed_view_forward * 10000, .{0, 1, 0}, false);
        view_ident_inv := inverse(view_ident);

        
    } else if pixel_snapping {
        // we can't clamp the shadow projection accurately since things can rotate so we'll assume worst case scenario
        // we'll adjust the shadow dimensions based on this
        top_left_dir_ident := transform_point(projection_inv, .{-1, 1, -1});
        top_right_dir_ident := transform_point(projection_inv, .{1, 1, -1});
        bottom_left_dir_ident := transform_point(projection_inv, .{-1, -1, -1});
        bottom_right_dir_ident := transform_point(projection_inv, .{1, -1, -1});

        top_left_ray_ident := Ray3.{.{0, 0, 0}, top_left_dir_ident};
        top_right_ray_ident := Ray3.{.{0, 0, 0}, top_right_dir_ident};
        bottom_left_ray_ident := Ray3.{.{0, 0, 0}, bottom_left_dir_ident};
        bottom_right_ray_ident := Ray3.{.{0, 0, 0}, bottom_right_dir_ident};

        max_depth_plane_ident := create_plane3(.{0, 0, -max_depth}, .{0, 0, -1});

        top_left_ident := intersection_simple(max_depth_plane_ident, top_left_ray_ident);
        top_right_ident := intersection_simple(max_depth_plane_ident, top_right_ray_ident);
        bottom_left_ident := intersection_simple(max_depth_plane_ident, bottom_left_ray_ident);
        bottom_right_ident := intersection_simple(max_depth_plane_ident, bottom_right_ray_ident);
        near_top_left_ident := Vector3.{0, 0, 0};
        near_top_right_ident := Vector3.{0, 0, 0};
        near_bottom_left_ident := Vector3.{0, 0, 0};
        near_bottom_right_ident := Vector3.{0, 0, 0};

        // TODO remove this
        assert(abs(distance(top_left_ident, bottom_right_ident) - distance(top_right_ident, bottom_left_ident)) < 0.001, "Sanity check that your camera frustum is non-skewed.\n");
        assert(abs(distance(near_top_left_ident, near_bottom_right_ident) - distance(near_top_right_ident, near_bottom_left_ident)) < 0.001, "Sanity check that your camera frustum is non-skewed.\n");
        assert(distance(near_top_left_ident, bottom_right_ident) > distance(near_top_left_ident, top_right_ident) - 0.001, "Sanity check that I understand the limitations of what's possible with a rectangular frustum.\n");

        // along one of the edges
        required_ortho_size := max_depth;
        // along the front rectangle diagonal
        required_ortho_size = max(required_ortho_size, distance(top_left_ident, bottom_right_ident));
        // along the back rectangle diagonal
        required_ortho_size = max(required_ortho_size, distance(near_top_left_ident, near_bottom_right_ident));
        // along the inner diagonal
        required_ortho_size = max(required_ortho_size, distance(near_top_left_ident, bottom_right_ident));

        assert(required_ortho_size >= ortho_width - 0.1, "Sanity check to be sure we're not shrinking the projection width somehow.\n");
        assert(required_ortho_size >= ortho_height - 0.1, "Sanity check to be sure we're not shrinking the projection height somehow.\n");

        ortho_width = required_ortho_size;
        ortho_height = required_ortho_size;
    }

    if pixel_snapping {
        shadow_dimensions_float := vector2(shadow_texture_dimensions);
        world_pixel_size := Vector2.{ortho_width, ortho_height} / shadow_dimensions_float;
        // expand it by 1 pixel on each side, although I'm not sure if it's correct to expand it this way, or by expanding half a pixel on each side
        ortho_width += world_pixel_size.x * 2;
        ortho_height += world_pixel_size.y * 2;

        // recalculate the new world pixel size so we can snap to pixels
        // fewer pixels means larger world pixel size value
        world_pixel_size = Vector2.{ortho_width, ortho_height} / shadow_dimensions_float;

        shadow_origin_plane := create_plane3(.{0, 0, 0}, shadow_forward);
        ortho_coord, origin_plane_right, origin_plane_up := convert_coordinates(shadow_origin_plane, ortho_start);

        // fewer pixels means larger movement
        // so we divide this by the size per pixel
        ortho_coord /= world_pixel_size;
        ortho_coord_rounded := floor(ortho_coord);
        // ortho_coord *= world_pixel_size;
        ortho_coord_rounded *= world_pixel_size;

        shadow_forward_distance := dot(frustum_points[0], shadow_forward);
        for i: 1..frustum_points.count - 1 {
            shadow_forward_distance = min(shadow_forward_distance, dot(frustum_points[i], shadow_forward));
        }

        // calculate the ortho start from the shadow plane origin which is 0,0,0
        ortho_start = ortho_coord_rounded.x * origin_plane_right + ortho_coord_rounded.y * origin_plane_up + shadow_forward_distance * shadow_forward;
    }

    shadow_view := make_look_at_matrix(ortho_start, ortho_start + shadow_forward * 10000, .{0, 1, 0}, false);
    shadow_projection := create_orthographic_matrix(-ortho_width / 2, ortho_width / 2, -ortho_height / 2, ortho_height / 2, 0, -ortho_depth);

    return shadow_view, shadow_projection;
}