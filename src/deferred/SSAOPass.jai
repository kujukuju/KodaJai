
SsaoPass :: struct {
    using #as pass: FramebufferPass(1, false, true);

    pass.initializer = (pass: *FramebufferPass(count, depth, drawable)) {
        MAX_KERNEL_SIZE :: 64;
        kernel: [MAX_KERNEL_SIZE] Vector3;
        
        for i: 0..kernel.count - 1 {  
            sample: Vector3;
            sample.x = 2.0 * random_get_zero_to_one() - 1.0;
            sample.y = 2.0 * random_get_zero_to_one() - 1.0;
            sample.z = random_get_zero_to_one();
            sample = normalize(sample);

            sample *= random_get_zero_to_one();

            // acceleration function so more points are located closer to the origin
            scale := cast(float) i / MAX_KERNEL_SIZE;      
            sample *= (0.1 + 0.9 * scale * scale);
            
            kernel[i] = sample;
        }
        pass.uniforms[xx "uKernel"] = create_uniform("uKernel", kernel);

        noise_width :: 4;
        noise_height :: 4;
        noise_image := create_image(4, 4, .RGB32F);
        for y: 0..noise_height - 1 {
            for x: 0..noise_width - 1 {
                // we rotate around the color in tangent space (z axis)
                // TODO so just use RG32F...
                color: Color;
                color.r = random_get_zero_to_one() * 2.0 - 1.0;
                color.g = random_get_zero_to_one() * 2.0 - 1.0;
                color.b = 0;
                draw_pixel(*noise_image, .{x, y}, color);
            }
        }
        noise_texture := create_texture(noise_image, .Repeat, .Nearest);
        pass.uniforms[xx "uNoise"] = create_uniform("uNoise", noise_texture);
    };
}
