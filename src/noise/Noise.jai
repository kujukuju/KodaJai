hash3_new :: (p: Vector3, tile_length: float) -> Vector3 {
    new := fmod_cycling(p, Vector3.{tile_length, tile_length, tile_length});
	new = Vector3.{
        dot(new, Vector3.{127.1, 311.7, 74.7}),
        dot(new, Vector3.{269.5, 183.3, 246.1}),
        dot(new, Vector3.{113.5, 271.9, 124.6}),
    };

	return -1.0 + 2.0 * fract(sin(new) * 43758.5453123);
}

hash3 :: (n: float) -> float {
    return fract(cast(float) (sin(n + 1.951) * 43758.5453));
}

noise3 :: (x: Vector3) -> float {
    p := floor(x);
	f := fract(x);

	f = f * f * (Vector3.{3.0, 3.0, 3.0} - Vector3.{2.0, 2.0, 2.0} * f);
	n := p.x + p.y * 57.0 + 113.0 * p.z;
	return lerp(
		lerp(
			lerp(hash3(n + 0.0), hash3(n + 1.0), f.x),
			lerp(hash3(n + 57.0), hash3(n + 58.0), f.x),
			f.y),
		lerp(
			lerp(hash3(n + 113.0), hash3(n + 114.0), f.x),
			lerp(hash3(n + 170.0), hash3(n + 171.0), f.x),
			f.y),
		f.z);
}

remap :: (v: float, in_min: float, in_max: float, out_min: float, out_max: float) -> float {
    t := inverse_lerp(in_min, in_max, v);
    return lerp(out_min, out_max, t);
}

inverse_lerp :: inline (a: float, b: float, t: float) -> float {
    return (t - a) / (b - a);
}

smootherstep :: (edge0: float, edge1: float, x: float) -> float {
    new := clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return new * new * new * (new * (new * 6.0 - 15.0) + 10.0);
}

smootherstep2 :: (edge0: Vector2, edge1: Vector2, x: Vector2) -> Vector2 {
    new := clamp((x - edge0) / (edge1 - edge0), Vector2.{0, 0}, Vector2.{1, 1});
    return new * new * new * (new * (new * 6.0 - 15.0) + 10.0);
}

smootherstep3 :: (edge0: Vector3, edge1: Vector3, x: Vector3) -> Vector3 {
    new := clamp((x - edge0) / (edge1 - edge0), Vector3.{0, 0, 0}, Vector3.{1, 1, 1});
    return new * new * new * (new * (new * 6.0 - 15.0) + 10.0);
}

fmod_cycling :: inline (v: Vector3, length: Vector3) -> Vector3 {
    return Vector3.{fmod_cycling(v.x, length.x), fmod_cycling(v.y, length.y), fmod_cycling(v.z, length.z)};
}

fmod_cycling :: inline (v: Vector2, length: Vector2) -> Vector2 {
    return Vector2.{fmod_cycling(v.x, length.x), fmod_cycling(v.y, length.y)};
}

fract :: inline (v: float) -> float {
    return v - floor(v);
}

fract :: inline (v: Vector3) -> Vector3 {
    return Vector3.{v.x - floor(v.x), v.y - floor(v.y), v.z - floor(v.z)};
}

sin :: inline (v: Vector3) -> Vector3 {
    return Vector3.{sin(v.x), sin(v.y), sin(v.z)};
}

floor :: inline (v: Vector3) -> Vector3 {
    return Vector3.{floor(v.x), floor(v.y), floor(v.z)};
}

clamp :: (v: Vector2, a: Vector2, b: Vector2) -> Vector2 {
    return Vector2.{clamp(v.x, a.x, b.x), clamp(v.y, a.y, b.y)};
}

clamp :: (v: Vector3, a: Vector3, b: Vector3) -> Vector3 {
    return Vector3.{clamp(v.x, a.x, b.x), clamp(v.y, a.y, b.y), clamp(v.z, a.z, b.z)};
}
