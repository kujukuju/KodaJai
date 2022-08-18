Color :: struct {
    r, g, b, a: float;
}

color :: (r: float, g: float, b: float, a: float) -> Color {
    c: Color = ---;
    c.r = r;
    c.g = g;
    c.b = b;
    c.a = a;
    return c;
}

color :: (v: Vector4) -> Color {
    c: Color = ---;
    c.r = v.x;
    c.g = v.y;
    c.b = v.z;
    c.a = v.w;
    return c;
}

vector :: (c: Color) -> Vector4 {
    v: Vector4 = ---;
    v.x = c.r;
    v.y = c.g;
    v.z = c.b;
    v.w = c.a;
    return v;
}

operator * :: (color: Color, value: float) -> Color {
    out: Color = ---;
    out.r = color.r * value;
    out.g = color.g * value;
    out.b = color.b * value;
    out.a = color.a * value;
    return out;
}