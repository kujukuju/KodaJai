tileable_fbm :: (uv: Vector3, tile_length: float) -> float {
    p := uv;
    persistence :: 0.5;
    lacunarity :: 2.0;
    octaves :: 8;

    amplitude := 0.5;
    total := 0.0;
    normalization := 0.0;

    for i: 0..octaves - 1 {
        noise_value := gradient_noise(p, tile_length * lacunarity * 0.5) * 0.5 + 0.5;
        total += noise_value * amplitude;
        normalization += amplitude;
        amplitude *= persistence;
        p = p * lacunarity;
    }

    total /= normalization;
    total = smootherstep(0.0, 1.0, total);

    return total;
}

gradient_noise :: (p: Vector3, tile_length: float) -> float {
    i := floor(p);
    f := fract(p);

    u := smootherstep3(Vector3.{0, 0, 0}, Vector3.{1, 1, 1}, f);

    /*
    * For 1D, the gradient of slope g at vertex u has the form h(x) = g * (x - u), where u 
    * is an integer and g is in [-1, 1]. This is the equation for a line with slope g which 
    * intersects the x-axis at u.
    * For N dimensional noise, use dot product instead of multiplication, and do 
    * component-wise interpolation (for 3D, trilinear)
    */
    return lerp(lerp(lerp(dot(hash3_new(i + Vector3.{0.0, 0.0, 0.0}, tile_length), f - Vector3.{0.0, 0.0, 0.0}), 
                        dot(hash3_new(i + Vector3.{1.0, 0.0, 0.0}, tile_length), f - Vector3.{1.0, 0.0, 0.0}), u.x),
                    lerp(dot(hash3_new(i + Vector3.{0.0, 1.0, 0.0}, tile_length), f - Vector3.{0.0, 1.0, 0.0}), 
                        dot(hash3_new(i + Vector3.{1.0, 1.0, 0.0}, tile_length), f - Vector3.{1.0, 1.0, 0.0}), u.x), u.y),
                lerp(lerp(dot(hash3_new(i + Vector3.{0.0, 0.0, 1.0}, tile_length), f - Vector3.{0.0, 0.0, 1.0}), 
                        dot(hash3_new(i + Vector3.{1.0, 0.0, 1.0}, tile_length), f - Vector3.{1.0, 0.0, 1.0}), u.x),
                    lerp(dot(hash3_new(i + Vector3.{0.0, 1.0, 1.0}, tile_length), f - Vector3.{0.0, 1.0, 1.0}), 
                        dot(hash3_new(i + Vector3.{1.0, 1.0, 1.0}, tile_length), f - Vector3.{1.0, 1.0, 1.0}), u.x), u.y), u.z);
}