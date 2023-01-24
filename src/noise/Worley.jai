worley :: (uv: Vector3, cell_count: float, seed: float = 0.0) -> float {
    return worley(uv, Vector3.{cell_count, cell_count, cell_count}, seed);
}

worley :: (uv: Vector3, cell_count: Vector3, seed: float = 0.0) -> float {
    seed_offset := fmod_cycling(Vector3.{seed, seed * seed * 3.14159, seed * 1.17421}, Vector3.{1.0, 1.0, 1.0});
    p_cell := (uv + seed_offset) * cell_count;

    closest := 1.0;
    for z: -1..1 {
        for y: -1..1 {
            for x: -1..1 {
                tp := floor(p_cell) + Vector3.{cast(float) x, cast(float) y, cast(float) z};
                tp = p_cell - tp - noise3(fmod_cycling(tp, cell_count));

                closest = min(closest, dot(tp, tp));
            }
        }
    }

    return 1.0 - saturate(closest);
}