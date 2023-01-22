CloudModel :: struct {
    using #as model: Model;
    noise: Texture3;
}

create_volumetric_cloud :: (center: Vector3, half_dimensions: Vector3) -> *Model {
    render_cube := create_cube(.{1, 1, 1});

    // up := normalize(Vector3.{1, 1, -1});
    // up_pitch_angle := PI / 2.0 - atan2(up.y, length(.{up.x, up.z}));
    // up_yaw_angle := PI / 2 - atan2(up.z, up.x);
    // pitch_rotation := make_rotation_quaternion(.{1, 0, 0}, up_pitch_angle);
    // yaw_rotation := make_rotation_quaternion(.{0, 1, 0}, up_yaw_angle);
    // rotation := yaw_rotation * pitch_rotation;

    cloud := New(CloudModel);
    array_resize(*cloud.geometry, 1);
    cloud.geometry[0] = render_cube;
    cloud.position = center;
    // cloud.rotation = rotation;
    cloud.scale = half_dimensions;

    // basically each cube in the volumetric cloud is this size, so each pixel in the 3d texture is this size
    cell_resolution := 0.2;

    // TODO this shouldnt be necessary, texture code is wrong, I guess?
    next_power_of_two :: (i: int) -> int {
        val := 1;
        while val < i {
            val += val;
        }
        return val;
    }

    resolution: Point3;
    resolution.x = next_power_of_two(cast(int) ceil(half_dimensions.x / cell_resolution));
    resolution.y = next_power_of_two(cast(int) ceil(half_dimensions.y / cell_resolution));
    resolution.z = next_power_of_two(cast(int) ceil(half_dimensions.z / cell_resolution));

    // TODO start this sample somewhere random offset into perlin space

    // TODO parallelize

    image := create_image3(resolution.x, resolution.y, resolution.z, .Gray);
    defer destroy(image);
    for z: 0..resolution.z - 1 {
        for y: 0..resolution.y - 1 {
            for x: 0..resolution.x - 1 {
                value := abs(noise3(x * 0.2, y * 0.2, z * 0.2));
                assert(value >= 0 && value <= 1, "Perlin noise value must be between 0 and 1.");

                image.pixels[x + y * resolution.x + z * resolution.y * resolution.x] = cast(u8) (value * 255);
            }
        }
    }

    cloud.noise = create_texture3(image);

    print("Cloud resolution: %\n", resolution);

    // for i: 0..cloud.noise.count - 1 {
    //     tex := cloud.noise[i];
    //     image := create_image(tex);
    //     defer destroy(image);

    //     save_image(image, tprint("image%.png", i));
    // }

    resolution_float: Vector3;
    resolution_float.x = xx resolution.x;
    resolution_float.y = xx resolution.y;
    resolution_float.z = xx resolution.z;

    cloud.uniforms["uNoiseDimensions"] = create_uniform("uNoiseDimensions", resolution_float);
    cloud.uniforms["uNoiseTexture"] = create_uniform("uNoiseTexture", cloud.noise);
    // cloud.uniforms["uNoise"] = create_uniform("uNoise", cloud.noise[0]);

    return cloud;
}
