Color :: struct {
    r, g, b, a: float;

#place r;
    rg: Vector2 = ---;
#place r;
    rgb: Vector3 = ---;
#place r;
    component: [4] float = ---;

#place g;
    gb: Vector2 = ---;
#place g;
    gba: Vector3 = ---;

#place b;
    ba: Vector2 = ---;
}

operator == :: (a: Color, b: Color) -> bool {
    return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

operator + :: (a: Color, b: Color) -> Color {
    out: Color = ---;
    out.r = a.r + b.r;
    out.g = a.g + b.g;
    out.b = a.b + b.b;
    out.a = a.a + b.a;
    return out;
}

operator * :: (color: Color, value: float) -> Color #symmetric {
    out: Color = ---;
    out.r = color.r * value;
    out.g = color.g * value;
    out.b = color.b * value;
    out.a = color.a * value;
    return out;
}

operator + :: (color: Color, value: float) -> Color #symmetric {
    out: Color = ---;
    out.r = color.r + value;
    out.g = color.g + value;
    out.b = color.b + value;
    out.a = color.a + value;
    return out;
}

operator - :: (value: float, color: Color) -> Color {
    out: Color = ---;
    out.r = value - color.r;
    out.g = value - color.g;
    out.b = value - color.b;
    out.a = value - color.a;
    return out;
}

operator - :: (color: Color, value: float) -> Color {
    out: Color = ---;
    out.r = color.r - value;
    out.g = color.g - value;
    out.b = color.b - value;
    out.a = color.a - value;
    return out;
}

color :: (r: u8, g: u8, b: u8, a: u8) -> Color {
    c: Color = ---;
    c.r = r / 255.0;
    c.g = g / 255.0;
    c.b = b / 255.0;
    c.a = a / 255.0;
    return c;
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

get_bytes :: (c: Color) -> [4] u8 {
    bytes: [4] u8;
    bytes[0] = cast(u8) (c.r * 255);
    bytes[1] = cast(u8) (c.g * 255);
    bytes[2] = cast(u8) (c.b * 255);
    bytes[3] = cast(u8) (c.a * 255);
    return bytes;
}