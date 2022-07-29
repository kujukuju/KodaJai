Point4 :: struct {
    x, y, z, w: int;
}

point :: (x: int, y: int, z: int, w: int) -> Point4 {
    p: Point4 = ---;
    p.x = x;
    p.y = y;
    p.z = z;
    p.w = w;
    return p;
}
