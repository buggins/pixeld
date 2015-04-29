module pixeld.graphics.texture;

import pixeld.graphics.types;

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

    void fillWith(uint color) {
        for(int i = 0; i < _buf.length; i++)
            _buf.ptr[i].pixel = color;
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

    /// if value < 0, set it to 9, if > 255 set to 255
    void clampSize(ref int n) {
        if (n < 0)
            n = 0;
        else if (n >= _size)
            n = _size - 1;
    }

    Pixel peekGaussAvg(int x, int y) {
        Pixel px00 = getPixelRepeat(x-1, y-1);
        Pixel px01 = getPixelRepeat(x+0, y-1);
        Pixel px02 = getPixelRepeat(x+1, y-1);
        Pixel px10 = getPixelRepeat(x-1, y+0);
        Pixel px11 = getPixelRepeat(x+0, y+0);
        Pixel px12 = getPixelRepeat(x+1, y+0);
        Pixel px20 = getPixelRepeat(x-1, y+1);
        Pixel px21 = getPixelRepeat(x+0, y+1);
        Pixel px22 = getPixelRepeat(x+1, y+1);
        int sr0 = cast(int)px00.r + px02.r + px20.r + px22.r;
        int sg0 = cast(int)px00.g + px02.g + px20.g + px22.g;
        int sb0 = cast(int)px00.b + px02.b + px20.b + px22.b;
        int sa0 = cast(int)px00.a + px02.a + px20.a + px22.a;
        int sr1 = cast(int)px01.r + px10.r + px12.r + px21.r;
        int sg1 = cast(int)px01.g + px10.g + px12.g + px21.g;
        int sb1 = cast(int)px01.b + px10.b + px12.b + px21.b;
        int sa1 = cast(int)px01.a + px10.a + px12.a + px21.a;
        Pixel res;
        res.r = cast(ubyte)((sr0 + sr1 * 2 + 4 * px11.r) >> 4);
        res.g = cast(ubyte)((sg0 + sg1 * 2 + 4 * px11.g) >> 4);
        res.b = cast(ubyte)((sb0 + sb1 * 2 + 4 * px11.b) >> 4);
        res.a = cast(ubyte)((sa0 + sa1 * 2 + 4 * px11.a) >> 4);
        return res;
    }

    private static __gshared Pixel[0x10000] _filterBuffer;
    /// gaussian filter
    void filter() {
        for (int y = 0; y < _size; y++) {
            for (int x = 0; x < _size; x++) {
                _filterBuffer[(y << _sizeLog2) + x] = peekGaussAvg(x, y);
            }
        }
        for (int i = _size * _size - 1; i >= 0; i--)
            _buf[i] = _filterBuffer[i];
    }

    void fillRect(int x0, int y0, int x1, int y1, Pixel color) {
        clampSize(x0);
        clampSize(y0);
        clampSize(x1);
        clampSize(y1);
        if (x0 >= x1 || y0 >= y1)
            return;
        for(int y = y0; y < y1; y++) {
            Pixel * row = _buf.ptr + (y << _sizeLog2);
            for (int x = x0; x < x1; x++)
                row[x] = color;
        }
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
        assert(length < 1024);
        x = x << 8;
        y = y << 8;
        for (int i = 0; i < length; i++) {
            buf[i] = getRepeatedInterpolated((x >> 8), (y >> 8));
            x += dx;
            y += dy;
        }
    }
    void getStripeRepeated(Pixel * buf, int x, int y, int dx, int dy, int length) {
        assert(length < 1024);
        x = x << 8;
        y = y << 8;
        for (int i = 0; i < length; i++) {
            buf[i] = getRepeated((x >> 8), (y >> 8));
            x += dx;
            y += dy;
        }
    }
    void getStripeClamped(Pixel * buf, int x, int y, int dx, int dy, int length) {
        assert(length < 1024);
        x = x << 8;
        y = y << 8;
        for (int i = 0; i < length; i++) {
            buf[i] = getClamped((x >> 8), (y >> 8));
            x += dx;
            y += dy;
        }
    }
    void getStripeClampedInterpolated(Pixel * buf, int x, int y, int dx, int dy, int length) {
        assert(length < 1024);
        x = x << 8;
        y = y << 8;
        for (int i = 0; i < length; i++) {
            buf[i] = getClampedInterpolated((x >> 8), (y >> 8));
            x += dx;
            y += dy;
        }
    }
}



class Texture : TextureLayer {
    /// wrapping: when true - clamped, false - repeated
    bool clamp = false;
    /// interpolation: when true - linear interpolation, false - take nearest
    bool interpolation = true;

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

