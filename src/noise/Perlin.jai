//---------------------------------------------------------------------
/** 1D float Perlin noise, SL "noise()"
 */
noise1 :: (x: float) -> float {
    ix0: int;
    ix1: int;
    fx0: float;
    fx1: float;
    s: float;
    n0: float;
    n1: float;

    ix0 = fastfloor(x); // Integer part of x
    fx0 = x - ix0;       // Fractional part of x
    fx1 = fx0 - 1.0;
    ix1 = (ix0 + 1) & 0xff;
    ix0 = ix0 & 0xff;    // Wrap to 0..255

    s = fade(fx0);

    n0 = grad1(PERM[ix0], fx0);
    n1 = grad1(PERM[ix1], fx1);
    return 0.188 * lerp(s, n0, n1);
}

//---------------------------------------------------------------------
/** 1D float Perlin periodic noise, SL "pnoise()"
 */
pnoise1 :: (x: float, px: int) -> float {
    ix0: int;
    ix1: int;
    fx0: float;
    fx1: float;
    s: float;
    n0: float;
    n1: float;

    ix0 = fastfloor(x); // Integer part of x
    fx0 = x - ix0;       // Fractional part of x
    fx1 = fx0 - 1.0;
    ix1 = ((ix0 + 1) % px) & 0xff; // Wrap to 0..px-1 *and* wrap to 0..255
    ix0 = (ix0 % px) & 0xff;      // (because px might be greater than 256)

    s = fade(fx0);

    n0 = grad1(PERM[ix0], fx0);
    n1 = grad1(PERM[ix1], fx1);
    return 0.188 * lerp(s, n0, n1);
}


//---------------------------------------------------------------------
/** 2D float Perlin noise.
 */
noise2 :: (x: float, y: float) -> float {
    ix0: int;
    iy0: int;
    ix1: int;
    iy1: int;

    fx0: float;
    fy0: float;
    fx1: float;
    fy1: float;

    s: float;
    t: float;
    nx0: float;
    nx1: float;
    n0: float;
    n1: float;

    ix0 = fastfloor(x); // Integer part of x
    iy0 = fastfloor(y); // Integer part of y
    fx0 = x - ix0;        // Fractional part of x
    fy0 = y - iy0;        // Fractional part of y
    fx1 = fx0 - 1.0;
    fy1 = fy0 - 1.0;
    ix1 = (ix0 + 1) & 0xff;  // Wrap to 0..255
    iy1 = (iy0 + 1) & 0xff;
    ix0 = ix0 & 0xff;
    iy0 = iy0 & 0xff;
    
    t = fade(fy0);
    s = fade(fx0);

    nx0 = grad2(PERM[ix0 + PERM[iy0]], fx0, fy0);
    nx1 = grad2(PERM[ix0 + PERM[iy1]], fx0, fy1);
    n0 = lerp(t, nx0, nx1);

    nx0 = grad2(PERM[ix1 + PERM[iy0]], fx1, fy0);
    nx1 = grad2(PERM[ix1 + PERM[iy1]], fx1, fy1);
    n1 = lerp(t, nx0, nx1);

    return 0.507 * lerp(s, n0, n1);
}

//---------------------------------------------------------------------
/** 2D float Perlin periodic noise.
 */
pnoise2 :: (x: float, y: float, px: int, py: int) -> float {
    ix0: int;
    iy0: int;
    ix1: int;
    iy1: int;

    fx0: float;
    fy0: float;
    fx1: float;
    fy1: float;

    s: float;
    t: float;
    nx0: float;
    nx1: float;
    n0: float;
    n1: float;
    
    ix0 = fastfloor(x); // Integer part of x
    iy0 = fastfloor(y); // Integer part of y
    fx0 = x - ix0;        // Fractional part of x
    fy0 = y - iy0;        // Fractional part of y
    fx1 = fx0 - 1.0;
    fy1 = fy0 - 1.0;
    ix1 = ((ix0 + 1) % px) & 0xff;  // Wrap to 0..px-1 and wrap to 0..255
    iy1 = ((iy0 + 1) % py) & 0xff;  // Wrap to 0..py-1 and wrap to 0..255
    ix0 = (ix0 % px) & 0xff;
    iy0 = (iy0 % py) & 0xff;
    
    t = fade(fy0);
    s = fade(fx0);

    nx0 = grad2(PERM[ix0 + PERM[iy0]], fx0, fy0);
    nx1 = grad2(PERM[ix0 + PERM[iy1]], fx0, fy1);
    n0 = lerp(t, nx0, nx1);

    nx0 = grad2(PERM[ix1 + PERM[iy0]], fx1, fy0);
    nx1 = grad2(PERM[ix1 + PERM[iy1]], fx1, fy1);
    n1 = lerp(t, nx0, nx1);

    return 0.507 * lerp(s, n0, n1);
}

//---------------------------------------------------------------------
/** 3D float Perlin noise.
 */
noise3 :: (x: float, y: float, z: float) -> float {
    ix0: int;
    iy0: int;
    ix1: int;
    iy1: int;
    iz0: int;
    iz1: int;

    fx0: float;
    fy0: float;
    fz0: float;
    fx1: float;
    fy1: float;
    fz1: float;

    s: float;
    t: float;
    r: float;

    nxy0: float;
    nxy1: float;
    nx0: float;
    nx1: float;
    n0: float;
    n1: float;

    ix0 = fastfloor(x); // Integer part of x
    iy0 = fastfloor(y); // Integer part of y
    iz0 = fastfloor(z); // Integer part of z
    fx0 = x - ix0;        // Fractional part of x
    fy0 = y - iy0;        // Fractional part of y
    fz0 = z - iz0;        // Fractional part of z
    fx1 = fx0 - 1.0;
    fy1 = fy0 - 1.0;
    fz1 = fz0 - 1.0;
    ix1 = (ix0 + 1) & 0xff; // Wrap to 0..255
    iy1 = (iy0 + 1) & 0xff;
    iz1 = (iz0 + 1) & 0xff;
    ix0 = ix0 & 0xff;
    iy0 = iy0 & 0xff;
    iz0 = iz0 & 0xff;
    
    r = fade(fz0);
    t = fade(fy0);
    s = fade(fx0);

    nxy0 = grad3(PERM[ix0 + PERM[iy0 + PERM[iz0]]], fx0, fy0, fz0);
    nxy1 = grad3(PERM[ix0 + PERM[iy0 + PERM[iz1]]], fx0, fy0, fz1);
    nx0 = lerp(r, nxy0, nxy1);

    nxy0 = grad3(PERM[ix0 + PERM[iy1 + PERM[iz0]]], fx0, fy1, fz0);
    nxy1 = grad3(PERM[ix0 + PERM[iy1 + PERM[iz1]]], fx0, fy1, fz1);
    nx1 = lerp(r, nxy0, nxy1);

    n0 = lerp(t, nx0, nx1);

    nxy0 = grad3(PERM[ix1 + PERM[iy0 + PERM[iz0]]], fx1, fy0, fz0);
    nxy1 = grad3(PERM[ix1 + PERM[iy0 + PERM[iz1]]], fx1, fy0, fz1);
    nx0 = lerp(r, nxy0, nxy1);

    nxy0 = grad3(PERM[ix1 + PERM[iy1 + PERM[iz0]]], fx1, fy1, fz0);
    nxy1 = grad3(PERM[ix1 + PERM[iy1 + PERM[iz1]]], fx1, fy1, fz1);
    nx1 = lerp(r, nxy0, nxy1);

    n1 = lerp(t, nx0, nx1);
    
    return 0.936 * lerp(s, n0, n1);
}

//---------------------------------------------------------------------
/** 3D float Perlin periodic noise.
 */
pnoise3 :: (x: float, y: float, z: float, px: int, py: int, pz: int) -> float {
    ix0: int;
    iy0: int;
    ix1: int;
    iy1: int;
    iz0: int;
    iz1: int;

    fx0: float;
    fy0: float;
    fz0: float;
    fx1: float;
    fy1: float;
    fz1: float;

    s: float;
    t: float;
    r: float;

    nxy0: float;
    nxy1: float;
    nx0: float;
    nx1: float;
    n0: float;
    n1: float;

    ix0 = fastfloor(x); // Integer part of x
    iy0 = fastfloor(y); // Integer part of y
    iz0 = fastfloor(z); // Integer part of z
    fx0 = x - ix0;        // Fractional part of x
    fy0 = y - iy0;        // Fractional part of y
    fz0 = z - iz0;        // Fractional part of z
    fx1 = fx0 - 1.0;
    fy1 = fy0 - 1.0;
    fz1 = fz0 - 1.0;
    ix1 = ((ix0 + 1) % px) & 0xff; // Wrap to 0..px-1 and wrap to 0..255
    iy1 = ((iy0 + 1) % py) & 0xff; // Wrap to 0..py-1 and wrap to 0..255
    iz1 = ((iz0 + 1) % pz) & 0xff; // Wrap to 0..pz-1 and wrap to 0..255
    ix0 = (ix0 % px) & 0xff;
    iy0 = (iy0 % py) & 0xff;
    iz0 = (iz0 % pz) & 0xff;
    
    r = fade(fz0);
    t = fade(fy0);
    s = fade(fx0);

    nxy0 = grad3(PERM[ix0 + PERM[iy0 + PERM[iz0]]], fx0, fy0, fz0);
    nxy1 = grad3(PERM[ix0 + PERM[iy0 + PERM[iz1]]], fx0, fy0, fz1);
    nx0 = lerp(r, nxy0, nxy1);

    nxy0 = grad3(PERM[ix0 + PERM[iy1 + PERM[iz0]]], fx0, fy1, fz0);
    nxy1 = grad3(PERM[ix0 + PERM[iy1 + PERM[iz1]]], fx0, fy1, fz1);
    nx1 = lerp(r, nxy0, nxy1);

    n0 = lerp(t, nx0, nx1);

    nxy0 = grad3(PERM[ix1 + PERM[iy0 + PERM[iz0]]], fx1, fy0, fz0);
    nxy1 = grad3(PERM[ix1 + PERM[iy0 + PERM[iz1]]], fx1, fy0, fz1);
    nx0 = lerp(r, nxy0, nxy1);

    nxy0 = grad3(PERM[ix1 + PERM[iy1 + PERM[iz0]]], fx1, fy1, fz0);
    nxy1 = grad3(PERM[ix1 + PERM[iy1 + PERM[iz1]]], fx1, fy1, fz1);
    nx1 = lerp(r, nxy0, nxy1);

    n1 = lerp(t, nx0, nx1);
    
    return 0.936 * lerp(s, n0, n1);
}


//---------------------------------------------------------------------
/** 4D float Perlin noise.
 */
noise4 :: (x: float, y: float, z: float, w: float) -> float {
    ix0: int;
    iy0: int;
    iz0: int;
    iw0: int;
    ix1: int;
    iy1: int;
    iz1: int;
    iw1: int;

    fx0: float;
    fy0: float;
    fz0: float;
    fw0: float;
    fx1: float;
    fy1: float;
    fz1: float;
    fw1: float;
    
    s: float;
    t: float;
    r: float;
    q: float;
    
    nxyz0: float;
    nxyz1: float;
    nxy0: float;
    nxy1: float;
    nx0: float;
    nx1: float;
    n0: float;
    n1: float;
    
    ix0 = fastfloor(x); // Integer part of x
    iy0 = fastfloor(y); // Integer part of y
    iz0 = fastfloor(z); // Integer part of y
    iw0 = fastfloor(w); // Integer part of w
    fx0 = x - ix0;        // Fractional part of x
    fy0 = y - iy0;        // Fractional part of y
    fz0 = z - iz0;        // Fractional part of z
    fw0 = w - iw0;        // Fractional part of w
    fx1 = fx0 - 1.0;
    fy1 = fy0 - 1.0;
    fz1 = fz0 - 1.0;
    fw1 = fw0 - 1.0;
    ix1 = (ix0 + 1) & 0xff;  // Wrap to 0..255
    iy1 = (iy0 + 1) & 0xff;
    iz1 = (iz0 + 1) & 0xff;
    iw1 = (iw0 + 1) & 0xff;
    ix0 = ix0 & 0xff;
    iy0 = iy0 & 0xff;
    iz0 = iz0 & 0xff;
    iw0 = iw0 & 0xff;

    q = fade(fw0);
    r = fade(fz0);
    t = fade(fy0);
    s = fade(fx0);

    nxyz0 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz0 + PERM[iw0]]]], fx0, fy0, fz0, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz0 + PERM[iw1]]]], fx0, fy0, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz1 + PERM[iw0]]]], fx0, fy0, fz1, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz1 + PERM[iw1]]]], fx0, fy0, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);
        
    nx0 = lerp(r, nxy0, nxy1);

    nxyz0 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz0 + PERM[iw0]]]], fx0, fy1, fz0, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz0 + PERM[iw1]]]], fx0, fy1, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz1 + PERM[iw0]]]], fx0, fy1, fz1, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz1 + PERM[iw1]]]], fx0, fy1, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);

    nx1 = lerp(r, nxy0, nxy1);

    n0 = lerp(t, nx0, nx1);

    nxyz0 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz0 + PERM[iw0]]]], fx1, fy0, fz0, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz0 + PERM[iw1]]]], fx1, fy0, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz1 + PERM[iw0]]]], fx1, fy0, fz1, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz1 + PERM[iw1]]]], fx1, fy0, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);

    nx0 = lerp(r, nxy0, nxy1);

    nxyz0 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz0 + PERM[iw0]]]], fx1, fy1, fz0, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz0 + PERM[iw1]]]], fx1, fy1, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz1 + PERM[iw0]]]], fx1, fy1, fz1, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz1 + PERM[iw1]]]], fx1, fy1, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);

    nx1 = lerp(r, nxy0, nxy1);

    n1 = lerp(t, nx0, nx1);

    return 0.87 * lerp(s, n0, n1);
}

//---------------------------------------------------------------------
/** 4D float Perlin periodic noise.
 */
pnoise4 :: (x: float, y: float, z: float, w: float, px: int, py: int, pz: int, pw: int) -> float {
    ix0: int;
    iy0: int;
    iz0: int;
    iw0: int;
    ix1: int;
    iy1: int;
    iz1: int;
    iw1: int;

    fx0: float;
    fy0: float;
    fz0: float;
    fw0: float;
    fx1: float;
    fy1: float;
    fz1: float;
    fw1: float;

    s: float;
    t: float;
    r: float;
    q: float;

    nxyz0: float;
    nxyz1: float;
    nxy0: float;
    nxy1: float;
    nx0: float;
    nx1: float;
    n0: float;
    n1: float;


    ix0 = fastfloor(x); // Integer part of x
    iy0 = fastfloor(y); // Integer part of y
    iz0 = fastfloor(z); // Integer part of y
    iw0 = fastfloor(w); // Integer part of w
    fx0 = x - ix0;        // Fractional part of x
    fy0 = y - iy0;        // Fractional part of y
    fz0 = z - iz0;        // Fractional part of z
    fw0 = w - iw0;        // Fractional part of w
    fx1 = fx0 - 1.0;
    fy1 = fy0 - 1.0;
    fz1 = fz0 - 1.0;
    fw1 = fw0 - 1.0;
    ix1 = ((ix0 + 1) % px) & 0xff;  // Wrap to 0..px-1 and wrap to 0..255
    iy1 = ((iy0 + 1) % py) & 0xff;  // Wrap to 0..py-1 and wrap to 0..255
    iz1 = ((iz0 + 1) % pz) & 0xff;  // Wrap to 0..pz-1 and wrap to 0..255
    iw1 = ((iw0 + 1) % pw) & 0xff;  // Wrap to 0..pw-1 and wrap to 0..255
    ix0 = (ix0 % px) & 0xff;
    iy0 = (iy0 % py) & 0xff;
    iz0 = (iz0 % pz) & 0xff;
    iw0 = (iw0 % pw) & 0xff;

    q = fade(fw0);
    r = fade(fz0);
    t = fade(fy0);
    s = fade(fx0);

    nxyz0 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz0 + PERM[iw0]]]], fx0, fy0, fz0, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz0 + PERM[iw1]]]], fx0, fy0, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz1 + PERM[iw0]]]], fx0, fy0, fz1, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy0 + PERM[iz1 + PERM[iw1]]]], fx0, fy0, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);
        
    nx0 = lerp(r, nxy0, nxy1);

    nxyz0 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz0 + PERM[iw0]]]], fx0, fy1, fz0, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz0 + PERM[iw1]]]], fx0, fy1, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz1 + PERM[iw0]]]], fx0, fy1, fz1, fw0);
    nxyz1 = grad4(PERM[ix0 + PERM[iy1 + PERM[iz1 + PERM[iw1]]]], fx0, fy1, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);

    nx1 = lerp(r, nxy0, nxy1);

    n0 = lerp(t, nx0, nx1);

    nxyz0 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz0 + PERM[iw0]]]], fx1, fy0, fz0, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz0 + PERM[iw1]]]], fx1, fy0, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz1 + PERM[iw0]]]], fx1, fy0, fz1, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy0 + PERM[iz1 + PERM[iw1]]]], fx1, fy0, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);

    nx0 = lerp(r, nxy0, nxy1);

    nxyz0 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz0 + PERM[iw0]]]], fx1, fy1, fz0, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz0 + PERM[iw1]]]], fx1, fy1, fz0, fw1);
    nxy0 = lerp(q, nxyz0, nxyz1);
        
    nxyz0 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz1 + PERM[iw0]]]], fx1, fy1, fz1, fw0);
    nxyz1 = grad4(PERM[ix1 + PERM[iy1 + PERM[iz1 + PERM[iw1]]]], fx1, fy1, fz1, fw1);
    nxy1 = lerp(q, nxyz0, nxyz1);

    nx1 = lerp(r, nxy0, nxy1);

    n1 = lerp(t, nx0, nx1);

    return 0.87 * lerp(s, n0, n1);
}

#scope_file

PERM :: u8.[
    151, 160, 137, 91, 90, 15, 
    131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 
    190,  6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 
    88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168,  68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 
    77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 
    102, 143, 54,  65, 25, 63, 161,  1, 216, 80, 73, 209, 76, 132, 187, 208,  89, 18, 169, 200, 196, 
    135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186,  3, 64, 52, 217, 226, 250, 124, 123, 
    5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 
    223, 183, 170, 213, 119, 248, 152,  2, 44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172, 9, 
    129, 22, 39, 253,  19, 98, 108, 110, 79, 113, 224, 232, 178, 185,  112, 104, 218, 246, 97, 228, 
    251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,  81, 51, 145, 235, 249, 14, 239, 107, 
    49, 192, 214,  31, 181, 199, 106, 157, 184,  84, 204, 176, 115, 121, 50, 45, 127,  4, 150, 254, 
    138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180, 
    151, 160, 137, 91, 90, 15, 
    131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 
    190,  6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 
    88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168,  68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 
    77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 
    102, 143, 54,  65, 25, 63, 161,  1, 216, 80, 73, 209, 76, 132, 187, 208,  89, 18, 169, 200, 196, 
    135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186,  3, 64, 52, 217, 226, 250, 124, 123, 
    5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 
    223, 183, 170, 213, 119, 248, 152,  2, 44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172, 9, 
    129, 22, 39, 253,  19, 98, 108, 110, 79, 113, 224, 232, 178, 185,  112, 104, 218, 246, 97, 228, 
    251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,  81, 51, 145, 235, 249, 14, 239, 107, 
    49, 192, 214,  31, 181, 199, 106, 157, 184,  84, 204, 176, 115, 121, 50, 45, 127,  4, 150, 254, 
    138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180, 
];

fade :: (t: float) -> float {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

fastfloor :: (x: float) -> int {
    return ifx cast(float) cast(int) x < x then (cast(int) x) else (cast(int) x - 1);
}

lerp :: (t: float, a: float, b: float) -> float {
    return a + t * (b - a);
}

grad1 :: (hash: int, x: float) -> float {
    h: int = hash & 15;
    grad: float = 1.0 + (h & 7);  // Gradient value 1.0, 2.0, ..., 8.0
    if h & 8 {
        grad = -grad;         // and a random sign for the gradient
    }
    return grad * x;           // Multiply the gradient with the distance
}

grad2 :: (hash: int, x: float, y: float) -> float {
    h: int = hash & 7;      // Convert low 3 bits of hash code
    u: float = ifx h < 4 then x else y;  // into 8 simple gradient directions,
    v: float = ifx h < 4 then y else x;  // and compute the dot product with (x,y).
    return (ifx h & 1 then -u else u) + (ifx h & 2 then -2.0 * v else 2.0 * v);
}

grad3 :: (hash: int, x: float, y: float, z: float) -> float {
    h: int = hash & 15;     // Convert low 4 bits of hash code into 12 simple
    u: float = ifx h < 8 then x else y; // gradient directions, and compute dot product.
    v: float = ifx h < 4 then y else (ifx h == 12 || h == 14 then x else z); // Fix repeats at h = 12 to 15
    return (ifx h & 1 then -u else u) + (ifx h & 2 then -v else v);
}

grad4 :: (hash: int, x: float, y: float, z: float, t: float) -> float {
    h: int = hash & 31;      // Convert low 5 bits of hash code into 32 simple
    u: float = ifx h < 24 then x else y; // gradient directions, and compute dot product.
    v: float = ifx h < 16 then y else z;
    w: float = ifx h < 8 then z else t;
    return (ifx h & 1 then -u else u) + (ifx h & 2 then -v else v) + (ifx h & 4 then -w else w);
}

// https://github.com/stegu/perlin-noise/blob/master/src/noise1234.c