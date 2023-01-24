perlin_worley :: (uv: Vector3, num_cells: float, mult: float) -> Vector2 {
    perlin_worley := 0.0;
    {
        worley0 := worley(uv, num_cells * 2.0 * mult, 1.0);
        worley1 := worley(uv, num_cells * 8.0 * mult, 2.0);
        worley2 := worley(uv, num_cells * 16.0 * mult, 3.0);
        worley_fbm := worley0 * 0.625 + worley1 * 0.25 + worley2 * 0.125;

        tile_length := 8.0;
        fbm0 := tileable_fbm(uv * mult, tile_length);

        perlin_worley = remap(fbm0, 0.0, 1.0, worley_fbm, 1.0);
    }

    worley0 := worley(uv, num_cells * 1.0 * mult, 4.0);
    worley1 := worley(uv, num_cells * 2.0 * mult, 5.0);
    worley2 := worley(uv, num_cells * 4.0 * mult, 6.0);
    worley3 := worley(uv, num_cells * 8.0 * mult, 7.0);
    worley4 := worley(uv, num_cells * 16.0 * mult, 8.0);
    worley5 := worley(uv, num_cells * 32.0 * mult, 9.0);

    worley_fbm0 := worley1 * 0.625 + worley2 * 0.25 + worley3 * 0.125;
    worley_fbm1 := worley2 * 0.625 + worley3 * 0.25 + worley4 * 0.125;
    worley_fbm2 := worley3 * 0.625 + worley4 * 0.25 + worley5 * 0.125;

    low_freq_fbm := worley_fbm0 * 0.625 + worley_fbm1 * 0.25 + worley_fbm2 * 0.125;

    tile_length := 8.0;
    perlin_worley_detail := remap(perlin_worley, low_freq_fbm, 1.0, 0.0, 1.0);

    return clamp(Vector2.{perlin_worley, perlin_worley_detail}, Vector2.{0, 0}, Vector2.{1, 1});
}