module pixeld.graphics.types;

import std.math : sqrt;

struct Pixel {
    union {
        uint pixel;
        ubyte[4] components;
        struct {
            ubyte b;
            ubyte g;
            ubyte r;
            ubyte a;
        }
    }
    this(uint px) {
        pixel = px;
    }
    this(ubyte[4] comps) {
        components = comps;
    }
    this(ubyte r, ubyte g, ubyte b, ubyte a) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }
    this(int r, int g, int b, int a) {
        this.r = cast(ubyte)r;
        this.g = cast(ubyte)g;
        this.b = cast(ubyte)b;
        this.a = cast(ubyte)a;
    }
}

/// swap two values
void swap(T)(ref T pt1, ref T pt2) {
    T tmp = pt1;
    pt1 = pt2;
    pt2 = tmp;
}

/// rotate 4 values left  (pt1 <= pt2 <= pt3 <= pt4 <= pt1)
void rotateLeft(T)(ref T pt1, ref T pt2, ref T pt3, ref T pt4) {
    T tmp = pt1;
    pt1 = pt2;
    pt2 = pt3;
    pt3 = pt4;
    pt4 = tmp;
}

/// rotate 4 values left  (pt1 <= pt2 <= pt3 <= pt4 <= pt1)
void rotateRight(T)(ref T pt1, ref T pt2, ref T pt3, ref T pt4) {
    T tmp = pt4;
    pt4 = pt3;
    pt3 = pt2;
    pt2 = pt1;
    pt1 = tmp;
}


struct point2d {
    int x;
    int y;
}

/*

    One cell is 256 * 256

*/

struct point3d {
    int x;
    int y;
    int z;
}

point3d normalize(point3d pt, int scale) {
    double dist = sqrt(cast(float)(pt.x * pt.x + pt.y * pt.y + pt.z * pt.z));
    pt.x = cast(int)(pt.x / dist * scale);
    pt.y = cast(int)(pt.y / dist * scale);
    pt.z = cast(int)(pt.z / dist * scale);
    dist = sqrt(cast(float)(pt.x * pt.x + pt.y * pt.y + pt.z * pt.z));
    return pt;
}

