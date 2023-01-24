CloudModel :: struct {
    using #as model: Model;
    noise: Texture3;
}

// TODO you should be able to boolean merge geometries in order to render this thing properly, and check when the ray exits the geometry somehow
// TODO this is an alternative solution to keeping track of an SDF grid for each cloud which is large and expensive
// TODO maybe you render the backface and then continue stepping until your z value is larger than the stored z value
// TODO and the correct way to do this is probably swap out the depth buffer before rendering clouds?
// TODO but I guess we need the existing depth buffer, so just render the back faces first, but we
// TODO nope you have to sample the light marching too so you just straight up need a big ol sdf
// TODO so I guess it would make the most sense to have an array of sdf uniforms that get sampled or something
// TODO but it feels so bad, its probably slower than a 3d texture sample
// TODO instead of dealing with any of this shit I can probably just only render spheres of various sizes bc the clouds seem permanently opaque anyways

create_volumetric_cloud :: (center: Vector3, half_dimensions: Vector3) -> *Model {
    render_cube := create_cube(.{1, 1, 1}, double_sided = true);

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

    // resolution: Point3;
    // resolution.x = next_power_of_two(cast(int) ceil(half_dimensions.x / cell_resolution));
    // resolution.y = next_power_of_two(cast(int) ceil(half_dimensions.y / cell_resolution));
    // resolution.z = next_power_of_two(cast(int) ceil(half_dimensions.z / cell_resolution));

    // TODO start this sample somewhere random offset into perlin space

    // TODO parallelize
    
    generate :: false;
    #if generate {
        perlin_worley_image := create_image3(64, 64, 64, .RG);
        defer destroy(perlin_worley_image);
        for z: 0..perlin_worley_image.depth - 1 {
            for y: 0..perlin_worley_image.height - 1 {
                for x: 0..perlin_worley_image.width - 1 {
                    uv := Vector3.{cast(float) x / perlin_worley_image.width, cast(float) y / perlin_worley_image.height, cast(float) z / perlin_worley_image.depth};

                    // 2??? really???
                    value := perlin_worley(uv, 2.0, 1.0);
                    value = clamp(value, Vector2.{0, 0}, Vector2.{1, 1});
                    assert(value.x >= 0 && value.x <= 1, "Worley noise value must be between 0 and 1.");
                    assert(value.y >= 0 && value.y <= 1, "Worley noise value must be between 0 and 1.");

                    perlin_worley_image.pixels[(x + y * perlin_worley_image.width + z * perlin_worley_image.width * perlin_worley_image.height) * 2 + 0] = cast(u8) (value.x * 255);
                    perlin_worley_image.pixels[(x + y * perlin_worley_image.width + z * perlin_worley_image.width * perlin_worley_image.height) * 2 + 1] = cast(u8) (value.y * 255);
                    // TODO for now I'm adding this layer because I'm worried theres some pma stuff going on
                    // perlin_worley_image.pixels[(x + y * perlin_worley_image.width + z * perlin_worley_image.width * perlin_worley_image.height) * 3 + 2] = cast(u8) 255;
                }
            }
        }

        save_image(perlin_worley_image, "perlin_worley32.png");

        cloud.noise = create_texture3(perlin_worley_image);
    } else {
        cloud.noise = load_texture3("perlin_worley32.png");
    }

    // worley_image := create_image(1024, 1024, .Gray);
    // defer destroy(worley_image);
    // for y: 0..1024 - 1 {
    //     for x: 0..1024 - 1 {
    //         uv := Vector3.{cast(float) x / 1024, cast(float) y / 1024, 0.0};

    //         value := perlin_worley(uv, 16.0, 1.0);
    //         assert(value >= 0 && value <= 1, "Worley noise value must be between 0 and 1.");

    //         worley_image.pixels[x + y * 1024] = cast(u8) (value * 255);
    //     }
    // }

    // save_image(worley_image, "perlin_worley.png");

    // image := create_image3(resolution.x, resolution.y, resolution.z, .Gray);
    // defer destroy(image);
    // for z: 0..resolution.z - 1 {
    //     for y: 0..resolution.y - 1 {
    //         for x: 0..resolution.x - 1 {
    //             value := abs(noise3(x * 0.2, y * 0.2, z * 0.2));
    //             assert(value >= 0 && value <= 1, "Perlin noise value must be between 0 and 1.");

    //             image.pixels[x + y * resolution.x + z * resolution.y * resolution.x] = cast(u8) (value * 255);
    //         }
    //     }
    // }

    // cloud.noise = create_texture3(image);

    // print("Cloud resolution: %\n", resolution);

    // for i: 0..cloud.noise.count - 1 {
    //     tex := cloud.noise[i];
    //     image := create_image(tex);
    //     defer destroy(image);

    //     save_image(image, tprint("image%.png", i));
    // }

    dimensions: Vector3;
    dimensions.x = half_dimensions.x * 2.0;
    dimensions.y = half_dimensions.y * 2.0;
    dimensions.z = half_dimensions.z * 2.0;

    cloud.uniforms["uCloudDimensions"] = create_uniform("uCloudDimensions", dimensions);
    cloud.uniforms["uNoiseTexture"] = create_uniform("uNoiseTexture", cloud.noise);
    // cloud.uniforms["uNoise"] = create_uniform("uNoise", cloud.noise[0]);

    return cloud;
}
