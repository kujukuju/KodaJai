Point2 :: struct {
    x, y: int;

#overlay (x) component: [2] int = ---;
}

operator == :: (a: Point2, b: Point2) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator + :: (a: Point2, b: Point2) -> Point2 {
    return point2(a.x + b.x, a.y + b.y);
}

operator - :: (a: Point2, b: Point2) -> Point2 {
    return point2(a.x - b.x, a.y - b.y);
}

operator - :: (a: Point2) -> Point2 {
    return point2(-a.x, -a.y);
}

operator * :: (a: Point2, b: int) -> Point2 #symmetric {
    return point2(a.x * b, a.y * b);
}

operator / :: (a: Point2, b: int) -> Point2 {
    return point2(a.x / b, a.y / b);
}

point2 :: (x: int, y: int) -> Point2 {
    p: Point2 = ---;
    p.x = x;
    p.y = y;
    return p;
}

point2 :: (a: Vector2) -> Point2 {
    p: Point2 = ---;
    p.x = cast(int) a.x;
    p.y = cast(int) a.y;
    return p;
}

vector2 :: (a: Point2) -> Vector2 {
    v: Vector2 = ---;
    v.x = cast(float) a.x;
    v.y = cast(float) a.y;
    return v;
}

min :: (a: Point2, b: Point2) -> Point2 {
    return point2(min(a.x, b.x), min(a.y, b.y));
}

max :: (a: Point2, b: Point2) -> Point2 {
    return point2(max(a.x, b.x), max(a.y, b.y));
}
