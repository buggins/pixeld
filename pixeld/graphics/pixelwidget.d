module pixeld.graphics.pixelwidget;

import dlangui.graphics.drawbuf;
import dlangui.graphics.fonts;
import dlangui.widgets.widget;
import dlangui.core.logger;
import std.algorithm : min, max;
import std.math : abs, pow, sin, cos, PI, sqrt;
import std.conv : to;

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

class TextureLayer {
    int _size;
    int _sizeLog2;
    uint _mask;
    uint _shift;
    uint _shift256;

    Pixel[] _buf;

    /// empty layer
    this(int sizeLog2) {
        init(sizeLog2);
    }

    /// create layer with next mipmap level (size = upperLayer.size / 2)
    this(TextureLayer upperLayer) {
        init(upperLayer._size / 2);
        for (int y = 0; y < _size; y++) {
            for (int x = 0; x < _size; x++) {
                Pixel px00 = upperLayer.getPixelClamp(x*2, y*2);
                Pixel px01 = upperLayer.getPixelClamp(x*2 + 1, y*2);
                Pixel px10 = upperLayer.getPixelClamp(x*2, y*2 + 1);
                Pixel px11 = upperLayer.getPixelClamp(x*2 + 1, y*2 + 1);
                int r = cast(int)px00.r + px01.r + px10.r + px11.r;
                int g = cast(int)px00.g + px01.g + px10.g + px11.g;
                int b = cast(int)px00.b + px01.b + px10.b + px11.b;
                int a = cast(int)px00.a + px01.a + px10.a + px11.a;
                putPixel(x, y, Pixel(r, g, b, a));
            }
        }
    }

    ~this() {
        destroy(_buf);
        _buf = null;
    }

    /// size is 8 for 256x256, 7 for 128x128, 6 for 64x64
    void init(int sizeLog2) {
        assert(sizeLog2 <= 9 && sizeLog2 >= 2);
        _sizeLog2 = sizeLog2;
        _size = 1 << sizeLog2;
        _mask = _size - 1;
        _shift = 16 - sizeLog2;
        _shift256 = 8 - sizeLog2;
        _buf = new Pixel[_size * _size];
    }

    /// set pixel with coords _size * _size (coords outside bounds are ignored)
    void putPixel(int x, int y, Pixel px) {
        if (x < 0 || y < 0 || x >= _size || y >= _size)
            return;
        _buf.ptr[(y << _sizeLog2) + x] = px;        
    }

    /// set pixel with coords _size * _size (coords outside bounds are clamped)
    void putPixelClamp(int x, int y, Pixel px) {
        if (x < 0)
            x = 0;
        else if (x >= _size)
            x = _size - 1;
        if (y < 0)
            y = 0;
        else if (y >= _size)
            y = _size - 1;
        _buf.ptr[(y << _sizeLog2) + x] = px;
    }

    /// set pixel with coords _size * _size (coords outside bounds are repeated)
    void putPixelRepeat(int x, int y, Pixel px) {
        _buf.ptr[((y & _mask) << _sizeLog2) + (x & _mask)] = px;
    }

    /// set pixel with coords _size * _size (coords outside bounds are repeated)
    Pixel getPixelRepeat(int x, int y) {
        return _buf.ptr[((y & _mask) << _sizeLog2) + (x & _mask)];
    }

    /// set pixel with coords _size * _size (coords outside bounds are clamped)
    Pixel getPixelClamp(int x, int y) {
        if (x < 0)
            x = 0;
        else if (x >= _size)
            x = _size - 1;
        if (y < 0)
            y = 0;
        else if (y >= _size)
            y = _size - 1;
        return _buf[(y << _sizeLog2) + x];
    }

    /// get pixel in tex coords are in 0..0x10000, no interpolation, repeat
    Pixel getRepeated(int x, int y) {
        // xx, yy: integer part, 0.._size-1
        int xx = (x >> _shift) & _mask;
        int yy = (y >> _shift) & _mask;
        return _buf[(yy << _sizeLog2) + ((xx + 1) & _mask)];
    }

    /// get pixel in tex coords are in 0..0x10000, no interpolation, clamp
    Pixel getClamped(int x, int y) {
        // xx, yy: integer part, 0.._size-1
        int xx = (x >> _shift) & _mask;
        int yy = (y >> _shift) & _mask;
        return _buf[(yy << _sizeLog2) + ((xx + 1) & _mask)];
    }

    /// get pixel in tex coords are in 0..0x10000, linear interpolation, clamp
    Pixel getClampedInterpolated(int x, int y) {
        // xx, yy: integer part, 0.._size-1
        int xx = (x >> _shift);
        int yy = (y >> _shift);
        // dx, dy: fractional part, 0..255
        int dx = (x >> _shift256) & 0xFF;
        int dy = (y >> _shift256) & 0xFF;
        Pixel px00 = _buf[(yy << _sizeLog2) + ((xx + 1) & _mask)];
        Pixel px01 = _buf[(((yy + 1) & _mask) << _sizeLog2) + xx];
        Pixel px10 = _buf[(yy << _sizeLog2) + ((xx + 1) & _mask)];
        Pixel px11 = _buf[(((yy + 1) & _mask) << _sizeLog2) + xx];
        int r0, g0, b0, a0, r1, g1, b1, a1;
        if (dx < 16) {
            r0 = px00.r;
            g0 = px00.g;
            b0 = px00.b;
            a0 = px00.a;
            r1 = px10.r;
            g1 = px10.g;
            b1 = px10.b;
            a1 = px10.a;
        } else if (dx >= 256 - 16) {
            r0 = px01.r;
            g0 = px01.g;
            b0 = px01.b;
            a0 = px01.a;
            r1 = px11.r;
            g1 = px11.g;
            b1 = px11.b;
            a1 = px11.a;
        } else {
            int ddx = dx ^ 0xFF;
            r0 = ((px00.r * ddx + px01.r * dx) >> 8);
            g0 = ((px00.g * ddx + px01.g * dx) >> 8);
            b0 = ((px00.b * ddx + px01.b * dx) >> 8);
            a0 = ((px00.a * ddx + px01.a * dx) >> 8);
            r1 = ((px10.r * ddx + px11.r * dx) >> 8);
            g1 = ((px10.g * ddx + px11.g * dx) >> 8);
            b1 = ((px10.b * ddx + px11.b * dx) >> 8);
            a1 = ((px10.a * ddx + px11.a * dx) >> 8);
        }
        // result rgba must be in r0,g0,b0,a0
        if (dy < 16) {
            // do nothing, use r0,g0,b0,a0 as is
            return Pixel(r0, g0, b0, a0);
        }  else if (dy >= 256 - 16) {
            return Pixel(r1, g1, b1, a1);
        } else {
            int ddy = dy ^ 0xFF;
            return Pixel(((r0 * ddy + r1 * dy) >> 8), 
                         ((g0 * ddy + g1 * dy) >> 8), 
                         ((b0 * ddy + b1 * dy) >> 8), 
                         ((a0 * ddy + a1 * dy) >> 8));
        }
    }

    /// get pixel in tex coords are in 0..0x10000, linear interpolation, repeat
    Pixel getRepeatedInterpolated(int x, int y) {
        // xx, yy: integer part, 0.._size-1
        int xx = (x >> _shift) & _mask;
        int yy = (y >> _shift) & _mask;
        // dx, dy: fractional part, 0..255
        int dx = (x >> _shift256) & 0xFF;
        int dy = (y >> _shift256) & 0xFF;
        Pixel px00 = getPixelClamp(xx, yy);
        Pixel px01 = getPixelClamp(xx + 1, yy);
        Pixel px10 = getPixelClamp(xx, yy + 1);
        Pixel px11 = getPixelClamp(xx + 1, yy + 1);
        int r0, g0, b0, a0, r1, g1, b1, a1;
        if (dx < 16) {
            r0 = px00.r;
            g0 = px00.g;
            b0 = px00.b;
            a0 = px00.a;
            r1 = px10.r;
            g1 = px10.g;
            b1 = px10.b;
            a1 = px10.a;
        } else if (dx >= 256 - 16) {
            r0 = px01.r;
            g0 = px01.g;
            b0 = px01.b;
            a0 = px01.a;
            r1 = px11.r;
            g1 = px11.g;
            b1 = px11.b;
            a1 = px11.a;
        } else {
            int ddx = dx ^ 0xFF;
            r0 = ((px00.r * ddx + px01.r * dx) >> 8);
            g0 = ((px00.g * ddx + px01.g * dx) >> 8);
            b0 = ((px00.b * ddx + px01.b * dx) >> 8);
            a0 = ((px00.a * ddx + px01.a * dx) >> 8);
            r1 = ((px10.r * ddx + px11.r * dx) >> 8);
            g1 = ((px10.g * ddx + px11.g * dx) >> 8);
            b1 = ((px10.b * ddx + px11.b * dx) >> 8);
            a1 = ((px10.a * ddx + px11.a * dx) >> 8);
        }
        // result rgba must be in r0,g0,b0,a0
        if (dy < 16) {
            // do nothing, use r0,g0,b0,a0 as is
            return Pixel(r0, g0, b0, a0);
        }  else if (dy >= 256 - 16) {
            return Pixel(r1, g1, b1, a1);
        } else {
            int ddy = dy ^ 0xFF;
            return Pixel(((r0 * ddy + r1 * dy) >> 8), 
                         ((g0 * ddy + g1 * dy) >> 8), 
                         ((b0 * ddy + b1 * dy) >> 8), 
                         ((a0 * ddy + a1 * dy) >> 8));
        }
    }
    void getStripeRepeatedInterpolated(Pixel * buf, int x, int y, int dx, int dy, int length) {
        assert(length <= textureStripeBuffer.length);
        for (int i = 0; i < length; i++) {
            buf[i] = getRepeatedInterpolated(x, y);
            x += dx;
            y += dy;
        }
    }
    void getStripeRepeated(Pixel * buf, int x, int y, int dx, int dy, int length) {
        assert(length <= textureStripeBuffer.length);
        for (int i = 0; i < length; i++) {
            buf[i] = getRepeated(x, y);
            x += dx;
            y += dy;
        }
    }
    void getStripeClamped(Pixel * buf, int x, int y, int dx, int dy, int length) {
        assert(length <= textureStripeBuffer.length);
        for (int i = 0; i < length; i++) {
            buf[i] = getClamped(x, y);
            x += dx;
            y += dy;
        }
    }
    void getStripeClampedInterpolated(Pixel * buf, int x, int y, int dx, int dy, int length) {
        assert(length <= textureStripeBuffer.length);
        for (int i = 0; i < length; i++) {
            buf[i] = getClampedInterpolated(x, y);
            x += dx;
            y += dy;
        }
    }
}

__gshared Pixel[1024] textureStripeBuffer;

/// swap two values
void swap(T)(ref T pt1, ref T pt2) {
    T tmp = pt1;
    pt1 = pt2;
    pt2 = tmp;
}

class Texture : TextureLayer {
    /// wrapping: when true - clamped, false - repeated
    bool clamp;
    /// interpolation: when true - linear interpolation, false - take nearest
    bool interpolation;

    this(int sizeLog2) {
        super(sizeLog2);
    }
    ~this() {
        clearMipMaps();
    }
    void clearMipMaps() {
        for (int i = 0; i < _mipMap.length; i++) {
            destroy(_mipMap[i]);
            _mipMap[i] = null;
        }
        _mipMap.length = 0;
    }
    void generateMipMaps(int count) {
        clearMipMaps();
        TextureLayer currentLayer = this;
        for (int i = 0; i < count; i++) {
            if (currentLayer._sizeLog2 <= 3)
                break; // too dip
            TextureLayer nextLayer = new TextureLayer(currentLayer);
            _mipMap ~= nextLayer;
            currentLayer = nextLayer;
        }
    }
    private TextureLayer[] _mipMap;

    /// get stripe of texture pixels, starting point is (x, y), step to next pixel is (dx, dy)
    void getStripe(Pixel * buf, int x, int y, int dx, int dy, int length) {
        TextureLayer layer = this;
        if (_mipMap.length > 0) {
            // TODO: mipmap support
            // select suitable mipmap layer
        }
        if (interpolation) {
            if (clamp) {
                layer.getStripeClampedInterpolated(buf, x, y, dx, dy, length);
            } else {
                layer.getStripeRepeatedInterpolated(buf, x, y, dx, dy, length);
            }
        } else {
            if (clamp) {
                layer.getStripeClamped(buf, x, y, dx, dy, length);
            } else {
                layer.getStripeRepeated(buf, x, y, dx, dy, length);
            }
        }
    }

    Pixel getTexel(int x, int y, int depth) {
        TextureLayer layer = this;
        if (_mipMap.length > 0) {
            // TODO: mipmap support
            // select suitable mipmap layer
        }
        if (interpolation) {
            if (clamp) {
                return layer.getClampedInterpolated(x, y);
            } else {
                return layer.getRepeatedInterpolated(x, y);
            }
        } else {
            if (clamp) {
                return layer.getClamped(x, y);
            } else {
                return layer.getRepeated(x, y);
            }
        }
    }

}

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

        if (pt1.y + HALF_CELL_SIZE < 0 && pt2.y + HALF_CELL_SIZE < 0 && pt3.y + HALF_CELL_SIZE < 0 && pt4.y + HALF_CELL_SIZE < 0)
            return;
        if (pt1.y + HALF_CELL_SIZE > DEEP_TABLE_LEN && pt2.y + HALF_CELL_SIZE > DEEP_TABLE_LEN && pt3.y + HALF_CELL_SIZE > DEEP_TABLE_LEN && pt4.y + HALF_CELL_SIZE > DEEP_TABLE_LEN)
            return;
        if (pt1.x < -DEEP_TABLE_LEN && pt2.x < -DEEP_TABLE_LEN && pt3.x < -DEEP_TABLE_LEN && pt4.x < -DEEP_TABLE_LEN)
            return;
        if (pt1.x > DEEP_TABLE_LEN && pt2.x > DEEP_TABLE_LEN && pt3.x > DEEP_TABLE_LEN && pt4.x > DEEP_TABLE_LEN)
            return;
        if (pt1.z < -DEEP_TABLE_LEN && pt2.z < -DEEP_TABLE_LEN && pt3.z < -DEEP_TABLE_LEN && pt4.z < -DEEP_TABLE_LEN)
            return;
        if (pt1.z > DEEP_TABLE_LEN && pt2.z > DEEP_TABLE_LEN && pt3.z > DEEP_TABLE_LEN && pt4.z > DEEP_TABLE_LEN)
            return;

        int miny = min(pt1.y, pt2.y, pt3.y, pt4.y) + HALF_CELL_SIZE;
        if (miny < 0)
            miny = 0;
        else if (miny >= DEEP_TABLE_LEN)
            miny = DEEP_TABLE_LEN - 1;
        int ydeepFactor = deepFuncTable.ptr[miny];
        int step = 0xFFF * 255 / ydeepFactor / _dx;
        if (step <= 0)
            step = 1;

        if (pt1.x == pt2.x && pt1.y == pt2.y && pt3.x == pt4.x && pt3.y == pt4.y) {

            if (pt1.y > pt4.y) {
                // swap
                swap(pt1, pt4);
                swap(pt2, pt3);
                swap(tx1, tx4);
                swap(tx2, tx3);
            }

            // vertical (wall)
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

                if (pt1.y < -HALF_CELL_SIZE || pt1.y >= DEEP_TABLE_LEN) // Z plane clipping
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
                lastx = pp1.x;
                if (pp1.y < 0 && pp2.y < 0) // below
                    continue;
                if (pp1.y >= _dy && pp2.y >= _dy) // above
                    continue;

                point2d t1; // bottom texture coord
                t1.x = cast(int)(tx1.x + cast(long)dtx1 * i / maxdist);
                t1.y = cast(int)(tx1.y + cast(long)dty1 * i / maxdist);
                point2d t2; // top texture coord
                t2.x = cast(int)(tx2.x + cast(long)dtx2 * i / maxdist);
                t2.y = cast(int)(tx2.y + cast(long)dty2 * i / maxdist);

                int stripeLen = abs(pp1.y - pp2.y);
                if (stripeLen < 1)
                    stripeLen = 1;

                tex.getStripe(textureStripeBuffer.ptr, t1.x, t1.y, (t2.x - t1.x) / stripeLen, (t2.y - t1.y) / stripeLen, stripeLen);
                int dy = pp1.y < pp2.y ? 1 : -1;
                int x = pp1.x;
                int idx = 0;
                point3d p = pp1;
                for (int y = pp1.y; idx < stripeLen; idx++, y += dy) {
                    p.y = y;
                    if (y >= 0 && y < dy)
                        pixel2d(p, textureStripeBuffer.ptr[idx].pixel);
                }
            }
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

class PixelWidget : Widget {

    private FrameBuffer _framebuf;
    private ColorDrawBuf _buf;

    this() {
        super("pixelbuf");

        import std.math : pow;

        //initFramebuffer(256, 192, 2);

        focusable = true;

        initFramebuffer(256 * 2, 192 * 2, 1);
        drawScene();

    }

    void drawScene() {
        _framebuf.clearBackground(0xFF000060, 0xFF000000);
        //for (int i = -128; i < 128; i++) {
        //    drawPoint(point3d(i, 0, 192), 0xFFFF00);
        //    drawPoint(point3d(i, 0, 0), 0xFFFF00);
        //    drawPoint(point3d(i, 256, 192), 0xFF0000);
        //    drawPoint(point3d(i, 256, 0), 0xFF0000);
        //    drawPoint(point3d(i, 512, 192), 0x00FFFF);
        //    drawPoint(point3d(i, 512, 0), 0x00FFFF);
        //    drawPoint(point3d(i, 768, 192), 0x00FF00);
        //    drawPoint(point3d(i, 768, 0), 0x00FF00);
        //}
        //int n = 256 / 6;
        //_framebuf.line3d(point3d(-128, 0, 0), point3d(128, 0, 0), 0x808080);
        //_framebuf.line3d(point3d(-128, 0, 0), point3d(-128, 256, 0), 0x808080);
        //_framebuf.line3d(point3d(128, 0, 0), point3d(128, 256, 0), 0x808080);
        //_framebuf.line3d(point3d(-128, 256, 0), point3d(128, 256, 0), 0x808080);
        //
        //_framebuf.line3d(point3d(-128, n*2, 0), point3d(128, n*2, 0), 0x808080);
        //_framebuf.line3d(point3d(-n, 0, 0), point3d(-n, 256, 0), 0x808080);
        //_framebuf.line3d(point3d(n, 0, 0), point3d(n, 256, 0), 0x808080);
        //_framebuf.line3d(point3d(-128, n*4, 0), point3d(128, n*4, 0), 0x808080);
        //
        //_framebuf.line3d(point3d(-128, 0, 192), point3d(128, 0, 192), 0x8080FF);
        //_framebuf.line3d(point3d(-128, 0, 192), point3d(-128, 256, 192), 0x8080FF);
        //_framebuf.line3d(point3d(128, 0, 192), point3d(128, 256, 192), 0x8080FF);
        //_framebuf.line3d(point3d(-128, 256, 192), point3d(128, 256, 192), 0x8080FF);
        //
        //_framebuf.line3d(point3d(-128, 512, 0), point3d(128, 512, 0), 0xE08080);
        //_framebuf.line3d(point3d(-128, 512, 192), point3d(128, 512, 192), 0xE08080);
        //_framebuf.line3d(point3d(-128, 768, 0), point3d(128, 768, 0), 0xE08080);
        //_framebuf.line3d(point3d(-128, 768, 192), point3d(128, 768, 192), 0xE08080);
        //
        //_framebuf.line3d(point3d(-128, 512, 0), point3d(-128, 768, 0), 0xE08080);
        //_framebuf.line3d(point3d(128, 512, 0), point3d(128, 768, 0), 0xE08080);

        drawCell(0, 0, 0xFF0000);
        drawCell(0, 1, 0xFFFF00);
        drawCell(0, 2, 0x80FFFF);
        drawCell(-1, 2, 0x8080FF);
        drawCell(-2, 2, 0x8080FF);
        drawCell(+1, 2, 0x8080FF);
        drawCell(0, 3, 0x80FFFF);
        drawCell(-1, 3, 0xFF80FF);
        drawCell(+1, 3, 0xFFC0FF);
        drawCell(-2, 3, 0xFFC0FF);
        drawCell(+2, 3, 0xFFC0FF);
        drawCell(-3, 3, 0xFFC0FF);
        drawCell(+3, 3, 0xFFC0FF);
        drawCell(0, 4, 0x80FFFF);
        drawCell(0, 5, 0x80FFFF);
        drawCell(0, 6, 0x80FFFF);
        drawCell(0, 7, 0x80FFFF);
    }

    void drawCell(int x, int y, uint cl) {
        x *= 256;
        y *= 256;
        const int n = 256 / 6;
        // floor bounds
        _framebuf.line3d(point3d(x-128, y - 128, 0), point3d(x+128, y - 128, 0), cl);
        _framebuf.line3d(point3d(x-128, y - 128, 0), point3d(x-128, y + 128, 0), cl);
        _framebuf.line3d(point3d(x+128, y - 128, 0), point3d(x+128, y + 128, 0), cl);
        _framebuf.line3d(point3d(x-128, y + 128, 0), point3d(x+128, y + 128, 0), cl);
        // floor cells
        _framebuf.line3d(point3d(x-128, y - 128 + 2*n, 0), point3d(x+128, y - 128 + 2*n, 0), cl);
        _framebuf.line3d(point3d(x-128 + 2*n, y - 128, 0), point3d(x-128 + 2*n, y + 128, 0), cl);
        _framebuf.line3d(point3d(x+128 - 2*n, y - 128, 0), point3d(x+128 - 2*n, y + 128, 0), cl);
        _framebuf.line3d(point3d(x-128, y + 128 - 2*n, 0), point3d(x+128, y + 128 - 2*n, 0), cl);
        // ceil bounds
        _framebuf.line3d(point3d(x-128, y - 128, 192), point3d(x+128, y - 128, 192), cl);
        _framebuf.line3d(point3d(x-128, y - 128, 192), point3d(x-128, y + 128, 192), cl);
        _framebuf.line3d(point3d(x+128, y - 128, 192), point3d(x+128, y + 128, 192), cl);
        _framebuf.line3d(point3d(x-128, y + 128, 192), point3d(x+128, y + 128, 192), cl);
        // wall
        _framebuf.line3d(point3d(x-128, y + 128, 0), point3d(x-128, y + 128, 192), cl);
        _framebuf.line3d(point3d(x+128, y + 128, 0), point3d(x+128, y + 128, 192), cl);
    }

    void initFramebuffer(int dx, int dy, int scale) {
        assert(scale == 1 || scale == 2);
        destroyFrameBuffer();
        _framebuf = new FrameBuffer(dx, dy);
        _buf = new ColorDrawBuf(dx * scale, dy * scale);
    }

    void destroyFrameBuffer() {
        if (_framebuf)
            destroy(_framebuf);
        if (_buf)
            destroy(_buf);
        _buf = null;
        _framebuf = null;
    }

    void drawPoint(point3d p, uint color) {
        _framebuf.pixel3d(p, color);
    }

    ~this() {
        destroyFrameBuffer();
    }

    /** 
        Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 

    */
    override void measure(int parentWidth, int parentHeight) { 
        measuredContent(parentWidth, parentHeight, _buf.width, _buf.height);
    }

    /// Set widget rectangle to specified value and layout widget contents. (Step 2 of two phase layout).
    override void layout(Rect rc) {
        if (visibility == Visibility.Gone) {
            return;
        }
        _pos = rc;
        _needLayout = false;
    }

    int fps = 0;

    /// Draw widget at its position to buffer
    override void onDraw(DrawBuf buf) {
        if (visibility != Visibility.Visible)
            return;
        Rect rc = _pos;
        applyMargins(rc);
		auto saver = ClipRectSaver(buf, rc, alpha);
        DrawableRef bg = backgroundDrawable;
		if (!bg.isNull) {
	        bg.drawTo(buf, rc, state);
		}
	    applyPadding(rc);

        drawScene();
        // convert from framebuffer to colors
        _framebuf.drawToBuffer(_buf);

        if (enableAnimation) {
            auto fpsString = to!dstring(fps);
            FontRef fnt = font;
            fnt.drawText(_buf, 10, 10, fpsString, 0x80FFFFFF);
        }

        // put to destination
        buf.drawImage(rc.left, rc.top, _buf);


        _needDraw = false;
    }

    bool enableAnimation = true;

    long elapsed;

    /// returns true is widget is being animated - need to call animate() and redraw
    override @property bool animating() { return enableAnimation; }
    /// animates window; interval is time left from previous draw, in hnsecs (1/10000000 of second)
    override void animate(long interval) {
        elapsed += interval;
        fps = cast(int)(10000000 / interval);
        if (elapsed >= 1000000) {
            elapsed -= 1000000;
            //_framebuf.rotationAngle += 2;
            _framebuf.translationY += 1;
        }
        //_framebuf.translationY += 1;
        //_framebuf.translationX += 1;
    }

    /// process key event, return true if event is processed.
    override bool onKeyEvent(KeyEvent event) {
		if (event.action == KeyAction.KeyDown) {
            if (event.keyCode == KeyCode.LEFT) {
                _framebuf.rotationAngle = _framebuf.rotationAngle - 90;
                return true;
            }
            if (event.keyCode == KeyCode.RIGHT) {
                _framebuf.rotationAngle = _framebuf.rotationAngle + 90;
                return true;
            }
            if (event.keyCode == KeyCode.UP) {
                _framebuf.translationY += 256;
                return true;
            }
            if (event.keyCode == KeyCode.DOWN) {
                _framebuf.translationY -= 256;
                return true;
            }
        }
        return super.onKeyEvent(event);
    }
}
