module pixeld.graphics.framebuf;

import dlangui.graphics.drawbuf;
import dlangui.core.logger;

import std.algorithm : min, max;
import std.math : abs, pow, sin, cos, PI, sqrt;


import pixeld.graphics.types;
import pixeld.graphics.texture;

__gshared Pixel[1024] textureStripeBuffer;

/// ZRGB buffer
class FrameBuffer : ColorDrawBuf {
    int mx0;
    int my0;
    int mscale;
    uint fogcolor;

    int translationX = 0;
    int translationY = 0;
    private int _rotationAngle = 0;
    @property int rotationAngle() { return _rotationAngle; }
    @property void rotationAngle(int v) { 
        _rotationAngle = v; 
        while (_rotationAngle < 0)
            _rotationAngle += 360;
        while (_rotationAngle >= 360)
            _rotationAngle -= 360;
    }

    this(int x, int y) {
        super(x, y);
        mx0 = x / 2;
        my0 = y / 3 - 1;
        mscale = x + 1;
        //point3d pt;
        //rotationAngle = 1;
        //pt = point3d(0, 100, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 200, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 300, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 400, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //rotationAngle = 30;
        //pt = point3d(0, 100, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 200, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 300, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 400, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //rotationAngle = 45;
        //pt = point3d(0, 100, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 200, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 300, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 400, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //rotationAngle = 0;
        //pt = point3d(0, 100, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 200, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 300, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //pt = point3d(0, 400, 0); Log.d("rotation ", rotationAngle, " ", pt, " => ", normalize(translateCoords2(pt), 1000));
        //rotationAngle = 45;
    }

    // returns direction vector of length 1, for 0/90/180/270 degrees angles
    @property point2d directionVector() {
        if (_rotationAngle == 0)
            return point2d(0, 1);
        else if (_rotationAngle == 90)
            return point2d(1, 0);
        else if (_rotationAngle == 180)
            return point2d(0, -1);
        else if (_rotationAngle == 270)
            return point2d(-1, 0);
        return point2d(0, 0);
    }

    void clearBackground(uint cl) {
        for(int i = cast(int)_buf.length - 1; i >= 0; i--)
            _buf.ptr[i] = cl;
    }

    void clearBackground(uint clTop, uint clBottom) {
        for (int y = 0; y < _dy; y++) {
            uint cl = y < my0 ? clTop : clBottom;
            int index = y * _dx;
            for (int x = 0; x < _dx; x++) {
                _buf.ptr[index + x] = cl;
            }
        }
    }

    /// apply translation and rotation
    point3d translateCoords2(point3d pt) {
        translateCoords(pt);
        return pt;
    }

    /// apply translation and rotation
    void translateCoords(ref point3d pt) {
        pt.x -= translationX;
        pt.y -= translationY;
        if (_rotationAngle) {
            int x = pt.x;
            int y = pt.y;
            if (_rotationAngle == 90) {
                // fast: 90 degrees
                pt.x = -y;
                pt.y = x;
            } else if (_rotationAngle == 180) {
                // fast: 180 degrees
                pt.x = -x;
                pt.y = -y;
            } else if (_rotationAngle == 270) {
                // fast: 270 degrees
                pt.x = y;
                pt.y = -x;
            } else {
                /// TODO: arbitrary angle rotation working a bit strange
                // arbitrary
                int sa = sinTable.ptr[_rotationAngle];
                int ca = cosTable.ptr[_rotationAngle];
                // | m00 m10 |    |  cos(a)   -sin(a) |
                // | m01 m11 |    |  sin(a)    cos(a) |
                int m00 = ca;
                int m10 = -sa;
                int m01 = sa;
                int m11 = ca;
                pt.x = (x * m00 + y * m10) / 256;
                pt.y = (x * m01 + y * m11) / 256;
            }
        }
    }

    /// draw, points are in clockwise order, pt1 is usually bottom left, pt2 top left, pt3 top right, pt4 bottom right
    void drawTexture(Texture tex, point3d pt1, point3d pt2, point3d pt3, point3d pt4, point2d tx1, point2d tx2, point2d tx3, point2d tx4) {
        translateCoords(pt1);
        translateCoords(pt2);
        translateCoords(pt3);
        translateCoords(pt4);

        if (pt1.y + HALF_CELL_SIZE < 0 && pt2.y + HALF_CELL_SIZE < 0 && pt3.y + HALF_CELL_SIZE < 0 && pt4.y + HALF_CELL_SIZE < 0) {
            return;
        }
        if (pt1.y + HALF_CELL_SIZE > DEEP_TABLE_LEN && pt2.y + HALF_CELL_SIZE > DEEP_TABLE_LEN && pt3.y + HALF_CELL_SIZE > DEEP_TABLE_LEN && pt4.y + HALF_CELL_SIZE > DEEP_TABLE_LEN) {
            return;
        }
        if (pt1.x < -DEEP_TABLE_LEN && pt2.x < -DEEP_TABLE_LEN && pt3.x < -DEEP_TABLE_LEN && pt4.x < -DEEP_TABLE_LEN) {
            return;
        }
        if (pt1.x > DEEP_TABLE_LEN && pt2.x > DEEP_TABLE_LEN && pt3.x > DEEP_TABLE_LEN && pt4.x > DEEP_TABLE_LEN) {
            return;
        }
        if (pt1.z < -DEEP_TABLE_LEN && pt2.z < -DEEP_TABLE_LEN && pt3.z < -DEEP_TABLE_LEN && pt4.z < -DEEP_TABLE_LEN) {
            return;
        }
        if (pt1.z > DEEP_TABLE_LEN && pt2.z > DEEP_TABLE_LEN && pt3.z > DEEP_TABLE_LEN && pt4.z > DEEP_TABLE_LEN) {
            return;
        }

        int miny = min(pt1.y, pt2.y, pt3.y, pt4.y) + HALF_CELL_SIZE;
        if (miny < 0)
            miny = 0;
        else if (miny >= DEEP_TABLE_LEN)
            miny = DEEP_TABLE_LEN - 1;
        int ydeepFactor = deepFuncTable.ptr[miny];
        int step = 0xFFF * 255 / ydeepFactor / _dx;
        if (step <= 0)
            step = 1;

        int stripeLen = 1;

        if (pt1.x == pt2.x && pt1.y == pt2.y && pt3.x == pt4.x && pt3.y == pt4.y) {
            // vertical (wall)

            // pt1 must be near
            if (pt1.y > pt4.y) {
                // swap
                swap(pt1, pt4);
                swap(pt2, pt3);
                swap(tx1, tx4);
                swap(tx2, tx3);
            }


            /*
                 2---
                 |   `---
                 |       `--3
                 |          |
                 |          4
                 |         /
                 |        /
                 |       /
                 |      /
                 |     /
                 |    /
                 |   /
                 |  /
                 | /
                 |/
                 1
            */


            int dx1 = pt4.x - pt1.x;
            int dy1 = pt4.y - pt1.y;
            int dz1 = pt4.z - pt1.z;
            int dx2 = pt3.x - pt2.x;
            int dy2 = pt3.y - pt2.y;
            int dz2 = pt3.z - pt2.z;

            int dtx1 = tx4.x - tx1.x;
            int dty1 = tx4.y - tx1.y;
            int dtx2 = tx3.x - tx2.x;
            int dty2 = tx3.y - tx2.y;

            int maxdist = max(abs(dx1), abs(dy1), abs(dz1), abs(dx2), abs(dy2), abs(dz2));

            int lastx = -1;
            for (int i = 0; i < maxdist; i += step) {
                point3d p1; // bottom
                p1.x = cast(int)(pt1.x + cast(long)dx1 * i / maxdist);
                p1.y = cast(int)(pt1.y + cast(long)dy1 * i / maxdist);
                p1.z = cast(int)(pt1.z + cast(long)dz1 * i / maxdist);

                if (p1.y < -HALF_CELL_SIZE || p1.y >= DEEP_TABLE_LEN) // Z plane clipping
                    continue; // y out of range

                point3d p2; // top
                p2.x = cast(int)(pt2.x + cast(long)dx2 * i / maxdist);
                p2.y = cast(int)(pt2.y + cast(long)dy2 * i / maxdist);
                p2.z = cast(int)(pt2.z + cast(long)dz2 * i / maxdist);

                point3d pp1 = mapCoordsNoCheck(p1);
                point3d pp2 = mapCoordsNoCheck(p2);

                if (pp1.x < 0 || pp1.x >= _dx) // left or right
                    continue;
                if (pp1.x == lastx)
                    continue;
                if (pp1.y < 0 && pp2.y < 0) // below
                    continue;
                if (pp1.y >= _dy && pp2.y >= _dy) // above
                    continue;
                if (lastx != -1 && (pp1.x > lastx + 1 || pp1.x < lastx - 1)) {
                    int x0 = lastx;
                    int x1 = pp1.x;
                    if (x0 > x1)
                        swap(x0, x1);

                    // fill hole: draw with the same stripe
                    int dy = pp1.y < pp2.y ? 1 : -1;
                    for (int x = x0 + 1; x < x1; x++) {
                        int idx = 0;
                        point3d p = pp1;
                        p.x = x;
                        for (int y = pp1.y; idx < stripeLen; idx++, y += dy) {
                            p.y = y;
                            if (y >= 0 && y < _dy)
                                pixel2d(p, textureStripeBuffer.ptr[idx].pixel);
                        }
                    }
                }
                lastx = pp1.x;

                point2d t1; // bottom texture coord
                t1.x = cast(int)(tx1.x + cast(long)dtx1 * i / maxdist);
                t1.y = cast(int)(tx1.y + cast(long)dty1 * i / maxdist);
                point2d t2; // top texture coord
                t2.x = cast(int)(tx2.x + cast(long)dtx2 * i / maxdist);
                t2.y = cast(int)(tx2.y + cast(long)dty2 * i / maxdist);

                stripeLen = abs(pp1.y - pp2.y);
                if (stripeLen < 1)
                    stripeLen = 1;

                tex.getStripe(textureStripeBuffer.ptr, t1.x, t1.y, 256 * (t2.x - t1.x) / stripeLen, 256 * (t2.y - t1.y) / stripeLen, stripeLen);
                int dy = pp1.y < pp2.y ? 1 : -1;
                int x = pp1.x;
                int idx = 0;
                point3d p = pp1;
                for (int y = pp1.y; idx < stripeLen; idx++, y += dy) {
                    p.y = y;
                    if (y >= 0 && y < _dy)
                        pixel2d(p, textureStripeBuffer.ptr[idx].pixel);
                }
            }
            return;
        } else if (pt1.z == pt2.z && pt2.z == pt3.z && pt3.z == pt4.z) {
            // horizontal surface (floor or ceil)

            if (pt1.y == pt4.y && pt2.y == pt3.y) {
                // pt1 must be near
                if (pt1.y > pt4.y) {
                    // swap - rotate 180 degrees
                    swap(pt1, pt3);
                    swap(pt2, pt4);
                    swap(tx1, tx3);
                    swap(tx2, tx4);
                }
            } else if (pt1.y == pt2.y && pt3.y == pt4.y) {
                if (pt1.y < pt2.y) {
                    rotateLeft(pt1, pt2, pt3, pt4);
                    rotateLeft(tx1, tx2, tx3, tx4);
                } else {
                    rotateRight(pt1, pt2, pt3, pt4);
                    rotateRight(tx1, tx2, tx3, tx4);
                }
            } else {
                Log.d("Drawing of non-rectangular horizontal plane is not supported");
                return;
            }

            /*
                    2 ------ 3
                   /          \
                  /            \
                 1--------------4
            */

            int dx1 = pt2.x - pt1.x;
            int dy1 = pt2.y - pt1.y;
            int dz1 = pt2.z - pt1.z;
            int dx2 = pt3.x - pt4.x;
            int dy2 = pt3.y - pt4.y;
            int dz2 = pt3.z - pt4.z;

            int dtx1 = tx2.x - tx1.x;
            int dty1 = tx2.y - tx1.y;
            int dtx2 = tx3.x - tx4.x;
            int dty2 = tx3.y - tx4.y;

            int maxdist = max(abs(dx1), abs(dy1), abs(dz1), abs(dx2), abs(dy2), abs(dz2));

            int lasty = -1;
            for (int i = 0; i < maxdist; i += step) {
                point3d p1; // left
                p1.x = cast(int)(pt1.x + cast(long)dx1 * i / maxdist);
                p1.y = cast(int)(pt1.y + cast(long)dy1 * i / maxdist);
                p1.z = cast(int)(pt1.z + cast(long)dz1 * i / maxdist);

                if (p1.y < -HALF_CELL_SIZE || p1.y >= DEEP_TABLE_LEN) // Z plane clipping
                    continue; // y out of range

                point3d p2; // right
                p2.x = cast(int)(pt4.x + cast(long)dx2 * i / maxdist);
                p2.y = cast(int)(pt4.y + cast(long)dy2 * i / maxdist);
                p2.z = cast(int)(pt4.z + cast(long)dz2 * i / maxdist);

                point3d pp1 = mapCoordsNoCheck(p1);
                point3d pp2 = mapCoordsNoCheck(p2);

                if ((pp1.x < 0 && pp2.x < 0) || (pp2.x >= _dx && pp2.x >= _dx)) // left or right
                    continue;
                if (pp1.y == lasty)
                    continue;
                lasty = pp1.y;
                if (pp1.y < 0 && pp2.y < 0) // below
                    continue;
                if (pp1.y >= _dy && pp2.y >= _dy) // above
                    continue;

                point2d t1; // left texture coord
                t1.x = cast(int)(tx1.x + cast(long)dtx1 * i / maxdist);
                t1.y = cast(int)(tx1.y + cast(long)dty1 * i / maxdist);
                point2d t2; // right texture coord
                t2.x = cast(int)(tx4.x + cast(long)dtx2 * i / maxdist);
                t2.y = cast(int)(tx4.y + cast(long)dty2 * i / maxdist);

                stripeLen = abs(pp1.x - pp2.x);
                if (stripeLen < 1)
                    stripeLen = 1;

                tex.getStripe(textureStripeBuffer.ptr, t1.x, t1.y, 256 * (t2.x - t1.x) / stripeLen, 256 * (t2.y - t1.y) / stripeLen, stripeLen);

                int dx = pp1.x < pp2.x ? 1 : -1;
                int y = pp1.y;
                int idx = 0;
                point3d p = pp1;
                for (int x = pp1.x; idx < stripeLen; idx++, x += dx) {
                    p.x = x;
                    if (x >= 0 && x < _dx)
                        pixel2d(p, textureStripeBuffer.ptr[idx].pixel);
                }
            }
            return;
        } else {
            Log.d("Only drawing of vertical and horizontal surfaces supported now");
        }
    }

    void line3d(point3d pt1, point3d pt2, uint color) {
        translateCoords(pt1);
        translateCoords(pt2);
        if (pt1.y + HALF_CELL_SIZE < 0 && pt2.y + HALF_CELL_SIZE < 0)
            return;
        if (pt1.y + HALF_CELL_SIZE > DEEP_TABLE_LEN && pt2.y + HALF_CELL_SIZE > DEEP_TABLE_LEN)
            return;
        if (pt1.x < -DEEP_TABLE_LEN && pt2.x < -DEEP_TABLE_LEN)
            return;
        if (pt1.x > DEEP_TABLE_LEN && pt2.x > DEEP_TABLE_LEN)
            return;
        if (pt1.z < -DEEP_TABLE_LEN && pt2.z < -DEEP_TABLE_LEN)
            return;
        if (pt1.z > DEEP_TABLE_LEN && pt2.z > DEEP_TABLE_LEN)
            return;
        int miny = min(pt1.y, pt2.y) + HALF_CELL_SIZE;
        if (miny < 0)
            miny = 0;
        else if (miny >= DEEP_TABLE_LEN)
            miny = DEEP_TABLE_LEN - 1;
        int ydeepFactor = deepFuncTable.ptr[miny];
        int dx = pt2.x - pt1.x;
        int dy = pt2.y - pt1.y;
        int dz = pt2.z - pt1.z;
        int maxdist = max(abs(dx), abs(dy), abs(dz));
        int step = 0xFFF * 255 / ydeepFactor / _dx;
        if (step <= 0)
            step = 1;
        for (int i = 0; i < maxdist; i += step) {
            point3d p;
            p.x = cast(int)(pt1.x + cast(long)dx * i / maxdist);
            p.y = cast(int)(pt1.y + cast(long)dy * i / maxdist);
            p.z = cast(int)(pt1.z + cast(long)dz * i / maxdist);
            pixel3d(p, color);
        }
    }

    private void pixel3d(point3d pt, uint color) {
        if (pt.y < -HALF_CELL_SIZE || pt.y >= DEEP_TABLE_LEN) // Z plane clipping
            return;
        point3d p2 = mapCoordsNoCheck(pt);
        //Log.d("map coords for pixel: ", pt, " > ", p2);
        if (p2.x < 0 || p2.x >= _dx || p2.y < 0 || p2.y >= _dy) // view clipping
            return;
        pixel2d(p2, color);
    }

    private void pixel2d(point3d pt, uint color) {
        Pixel px = Pixel(color);
        px.a = cast(ubyte)pt.z;
        Pixel * dst = cast(Pixel*)(_buf.ptr + _dx * pt.y + pt.x);
        if (dst.a > px.a) // check Z
            *dst = px;
    }

    private point3d mapCoordsNoCheck(point3d p) {
        p.y += HALF_CELL_SIZE;
        p.z -= HALF_CELL_SIZE;
        point3d res;
        int deepFactor = deepFuncTable.ptr[p.y];
        res.z = zFuncTable.ptr[p.y];
        res.x = mx0 + deepScale(p.x * deepFactor * cast(long)mscale);
        res.y = my0 - deepScale(p.z * deepFactor * cast(long)mscale);
        return res;
    }

    point3d mapCoords(point3d p) {
        p.y += HALF_CELL_SIZE;
        p.z -= HALF_CELL_SIZE;
        point3d res;
        int deepFactor = fastDeepFunc(p.y);
        res.z = fastZFunc(p.y);
        res.x = mx0 + deepScale(p.x * deepFactor * cast(long)mscale);
        res.y = my0 - deepScale(p.z * deepFactor * cast(long)mscale);
        return res;
    }

    uint applyFog(Pixel px) {
        int a = px.a;
        if (a == 255 || a == 0)
            return px.pixel & 0xFFFFFF; // background: return as is
        uint na = 255 - a;
        // black fog
        // TODO: apply fog color
        uint r = (px.r * na) >> 8;
        uint g = (px.g * na) >> 8;
        uint b = (px.b * na) >> 8;
        return (r << 16) | (g << 8) | b;
    }

    void drawToBuffer(ColorDrawBuf dst) {
        if (dst.width == width && dst.height == height) {
            // same size
            for(int i = cast(int)_buf.length - 1; i >= 0; i--) {
                Pixel pixel = *(cast(Pixel*)(_buf.ptr + i));
                dst._buf.ptr[i] = applyFog(pixel);
            }
        } else if (dst.width == width * 2 && dst.height == height * 2) {
            // double size
            int srcindex = 0;
            int dstindex = 0;
            for (int y = 0; y < _dy; y++) {
                Pixel* srcrow = cast(Pixel*)(_buf.ptr + srcindex);
                uint* dstrow = dst._buf.ptr + dstindex;
                for (int x = 0; x < _dx; x++) {
                    Pixel pixel = srcrow[x];
                    // TODO: apply FOG
                    uint color = applyFog(pixel);
                    dstrow[x * 2] = color;
                    dstrow[x * 2 + 1] = color;
                    dstrow[x * 2 + _dx + _dx] = color;
                    dstrow[x * 2 + _dx + _dx + 1] = color;
                }
                srcindex += _dx;
                dstindex += (_dx << 2);
            }
        }
    }
}

const deepConst = 0.6363f;

int deepFunc(int delta) {
    //import std.math : pow;
    float f = delta / 256.0f;
    float n = pow(deepConst, delta / 256.0f);
    return cast(int)(n * 0xFFF + 0.5f);
}

const int CELL_SIZE = 256;
const int HALF_CELL_SIZE = CELL_SIZE / 2;
const int MAX_DEEP_CELLS = 8;
const int DEEP_TABLE_LEN = MAX_DEEP_CELLS * CELL_SIZE;
const ubyte Z_NONE = 0;
const ubyte Z_BACKGROUND = CELL_SIZE - 1;
const int MAX_DEEP_FACTOR = 0xFFF;

__gshared int[DEEP_TABLE_LEN] deepFuncTable;
__gshared ubyte[DEEP_TABLE_LEN] zFuncTable;
__gshared int[360] sinTable;
__gshared int[360] cosTable;

__gshared static this() {
    for (int i = 0; i < DEEP_TABLE_LEN; i++) {
        deepFuncTable[i] = deepFunc(i);
    }
    int startdeep = deepFuncTable[0];
    int enddeep = deepFuncTable[$ - 1];
    int dist = startdeep - enddeep;
    for (int i = 0; i < DEEP_TABLE_LEN; i++) {
        int delta = startdeep - deepFuncTable[i]; // 0 .. dist
        // 0->1, dist->254
        zFuncTable[i] = cast(ubyte)((253 * delta + 128) / dist + 1);
    }
    assert(zFuncTable[0] == 1);
    assert(zFuncTable[DEEP_TABLE_LEN - 1] == CELL_SIZE - 2);
    for (int i = 0; i < 360; i++) {
        double angle = i * PI * 2 / 360;
        sinTable[i] = cast(int)(sin(angle) * 256);
        cosTable[i] = cast(int)(cos(angle) * 256);
    }
}

int fastDeepFunc(int x) {
    return x >= 0 ? (x < DEEP_TABLE_LEN ? deepFuncTable.ptr[x] : 0) : MAX_DEEP_FACTOR;
}

ubyte fastZFunc(int x) {
    return x >= 0 ? (x < DEEP_TABLE_LEN ? zFuncTable.ptr[x] : Z_BACKGROUND) : Z_NONE;
}

int deepScale(int x) {
    return x >> 20;
}

int deepScale(long x) {
    return cast(int)(x >> 20);
}

