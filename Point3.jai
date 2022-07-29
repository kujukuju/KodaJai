Point3 :: struct {
    x, y, z: int;
}

point :: (x: int, y: int, z: int) -> Point3 {
    p: Point3 = ---;
    p.x = x;
    p.y = y;
    p.z = z;
    return p;
}
