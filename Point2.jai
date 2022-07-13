Point2 :: struct {
    x, y: int;
}

point :: (x: int, y: int) -> Point2 {
    p: Point2 = ---;
    p.x = x;
    p.y = y;
    return p;
}
