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
