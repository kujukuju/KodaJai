Point3 :: struct {
    x, y, z: int;

#place x;
    xy: Point2 = ---;
#place y;
    yz: Point2 = ---;

#place x;
    component: [3] int = ---;
}

operator == :: (a: Point3, b: Point3) -> bool {
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

operator + :: (a: Point3, b: Point3) -> Point3 {
    return point3(a.x + b.x, a.y + b.y, a.z + b.z);
}

operator - :: (a: Point3, b: Point3) -> Point3 {
    return point3(a.x - b.x, a.y - b.y, a.z + b.z);
}

point3 :: (x: int, y: int, z: int) -> Point3 {
    p: Point3 = ---;
    p.x = x;
    p.y = y;
    p.z = z;
    return p;
}

min :: (a: Point3, b: Point3) -> Point3 {
    return point3(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z));
}

max :: (a: Point3, b: Point3) -> Point3 {
    return point3(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z));
}
