Point2 :: struct {
    x, y: int;

#place x;
    component: [2] int = ---;
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

point2 :: (x: int, y: int) -> Point2 {
    p: Point2 = ---;
    p.x = x;
    p.y = y;
    return p;
}

min :: (a: Point2, b: Point2) -> Point2 {
    return point2(min(a.x, b.x), min(a.y, b.y));
}

max :: (a: Point2, b: Point2) -> Point2 {
    return point2(max(a.x, b.x), max(a.y, b.y));
}
