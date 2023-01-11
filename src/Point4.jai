Point4 :: struct {
    x, y, z, w: int;

#place x;
    xy: Point2 = ---;
#place y;
    yz: Point2 = ---;
#place z;
    zw: Point2 = ---;
#place x;
    xyz: Point3 = ---;
#place y;
    yzw: Point3 = ---;
#place x;
    component: [4] int = ---;
}

operator == :: (a: Point4, b: Point4) -> bool {
    return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;
}

operator + :: (a: Point4, b: Point4) -> Point4 {
    return point4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w);
}

operator - :: (a: Point4, b: Point4) -> Point4 {
    return point4(a.x - b.x, a.y - b.y, a.z + b.z, a.w + b.w);
}

point4 :: (x: int, y: int, z: int, w: int) -> Point4 {
    p: Point4 = ---;
    p.x = x;
    p.y = y;
    p.z = z;
    p.w = w;
    return p;
}

min :: (a: Point4, b: Point4) -> Point4 {
    return point4(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z), min(a.w, b.w));
}

max :: (a: Point4, b: Point4) -> Point4 {
    return point4(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z), max(a.w, b.w));
}
