operator + :: (a: Vector2, b: float) -> Vector2 #symmetric {
    r: Vector2 = ---;
    r.x = a.x + b;
    r.y = a.y + b;

    return r;
}

operator - :: (a: Vector2, b: float) -> Vector2 #symmetric {
    r: Vector2 = ---;
    r.x = a.x - b;
    r.y = a.y - b;

    return r;
}

operator * :: (a: Vector2, b: float) -> Vector2 #symmetric {
    r: Vector2 = ---;
    r.x = a.x * b;
    r.y = a.y * b;

    return r;
}

normalize :: (v: Vector2) -> Vector2 {
    d := length(v);

    r: Vector2 = ---;
    r.x = v.x / d;
    r.y = v.y / d;

    return r;
}
