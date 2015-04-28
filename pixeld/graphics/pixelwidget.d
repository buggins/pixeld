module pixeld.graphics.pixelwidget;

import dlangui.graphics.drawbuf;
import dlangui.widgets.widget;
import dlangui.core.logger;
import std.algorithm : min, max;
import std.math : abs, pow;

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

class FrameBuffer : ColorDrawBuf {
    int mx0;
    int my0;
    int mscale;
    uint fogcolor;
    this(int x, int y) {
        super(x, y);
        mx0 = x / 2;
        my0 = y / 3;
        mscale = x;
    }

    void clearBackground(uint cl) {
        for(int i = cast(int)_buf.length - 1; i >= 0; i--)
            _buf.ptr[i] = cl;
    }

    void line3d(point3d pt1, point3d pt2, uint color) {
        if (pt1.y < 0 && pt2.y < 0)
            return;
        if (pt1.y > DEEP_TABLE_LEN && pt2.y > DEEP_TABLE_LEN)
            return;
        if (pt1.x < -DEEP_TABLE_LEN && pt2.x < -DEEP_TABLE_LEN)
            return;
        if (pt1.x > DEEP_TABLE_LEN && pt2.x > DEEP_TABLE_LEN)
            return;
        if (pt1.z < -DEEP_TABLE_LEN && pt2.z < -DEEP_TABLE_LEN)
            return;
        if (pt1.z > DEEP_TABLE_LEN && pt2.z > DEEP_TABLE_LEN)
            return;
        int miny = min(pt1.y, pt2.y);
        if (miny < 0)
            miny = 0;
        else if (miny >= DEEP_TABLE_LEN)
            miny = DEEP_TABLE_LEN - 1;
        int ydeepFactor = deepFuncTable.ptr[miny];
        int dx = pt2.x - pt1.x;
        int dy = pt2.y - pt1.y;
        int dz = pt2.z - pt1.z;
        int maxdist = max(abs(dx), abs(dy), abs(dz));
        int step = 0xFFF / ydeepFactor;
        if (step < 0)
            step = 1;
        for (int i = 0; i < maxdist; i += step) {
            point3d p;
            p.x = pt1.x + dx * i / maxdist;
            p.y = pt1.y + dy * i / maxdist;
            p.z = pt1.z + dz * i / maxdist;
            pixel3d(p, color);
        }
    }

    void pixel3d(point3d pt, uint color) {
        if (pt.y < 0 || pt.y >= DEEP_TABLE_LEN) // Z plane clipping
            return;
        point3d p2 = mapCoordsNoCheck(pt);
        //Log.d("map coords for pixel: ", pt, " > ", p2);
        if (p2.x < 0 || p2.y >= _dx || p2.y < 0 || p2.y >= _dy) // view clipping
            return;
        pixel2d(p2, color);
    }

    void pixel2d(point3d pt, uint color) {
        Pixel px = Pixel(color);
        px.a = cast(ubyte)pt.z;
        Pixel * dst = cast(Pixel*)(_buf.ptr + _dx * pt.y + pt.x);
        if (dst.a > px.a) // check Z
            *dst = px;
    }

    point3d mapCoordsNoCheck(point3d p) {
        p.z -= HALF_CELL_SIZE;
        point3d res;
        int deepFactor = deepFuncTable.ptr[p.y];
        res.z = zFuncTable.ptr[p.y];
        res.x = mx0 + deepScale(p.x * deepFactor * mscale);
        res.y = my0 - deepScale(p.z * deepFactor * mscale);
        return res;
    }

    point3d mapCoords(point3d p) {
        p.z -= HALF_CELL_SIZE;
        point3d res;
        int deepFactor = fastDeepFunc(p.y);
        res.z = fastZFunc(p.y);
        res.x = mx0 + deepScale(p.x * deepFactor * mscale);
        res.y = my0 - deepScale(p.z * deepFactor * mscale);
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
}

int fastDeepFunc(int x) {
    return x >= 0 ? (x < DEEP_TABLE_LEN ? deepFuncTable.ptr[x] : 0) : MAX_DEEP_FACTOR;
}

ubyte fastZFunc(int x) {
    return x >= 0 ? (x < DEEP_TABLE_LEN ? zFuncTable.ptr[x] : Z_BACKGROUND) : Z_NONE;
}

int deepScale(int x) {
    return x / 0x100000;
}

class PixelWidget : Widget {

    private FrameBuffer _framebuf;
    private ColorDrawBuf _buf;

    this() {
        super("pixelbuf");

        import std.math : pow;

        initFramebuffer(256, 192, 2);
        _framebuf.clearBackground(0xFF000000);
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
        int n = 256 / 6;
        _framebuf.line3d(point3d(-128, 0, 0), point3d(128, 0, 0), 0x808080);
        _framebuf.line3d(point3d(-128, 0, 0), point3d(-128, 256, 0), 0x808080);
        _framebuf.line3d(point3d(128, 0, 0), point3d(128, 256, 0), 0x808080);
        _framebuf.line3d(point3d(-128, 256, 0), point3d(128, 256, 0), 0x808080);

        _framebuf.line3d(point3d(-128, n*2, 0), point3d(128, n*2, 0), 0x808080);
        _framebuf.line3d(point3d(-n, 0, 0), point3d(-n, 256, 0), 0x808080);
        _framebuf.line3d(point3d(n, 0, 0), point3d(n, 256, 0), 0x808080);
        _framebuf.line3d(point3d(-128, n*4, 0), point3d(128, n*4, 0), 0x808080);

        _framebuf.line3d(point3d(-128, 0, 192), point3d(128, 0, 192), 0x8080FF);
        _framebuf.line3d(point3d(-128, 0, 192), point3d(-128, 256, 192), 0x8080FF);
        _framebuf.line3d(point3d(128, 0, 192), point3d(128, 256, 192), 0x8080FF);
        _framebuf.line3d(point3d(-128, 256, 192), point3d(128, 256, 192), 0x8080FF);

        _framebuf.line3d(point3d(-128, 512, 0), point3d(128, 512, 0), 0xE08080);
        _framebuf.line3d(point3d(-128, 512, 192), point3d(128, 512, 192), 0xE08080);
        _framebuf.line3d(point3d(-128, 768, 0), point3d(128, 768, 0), 0xE08080);
        _framebuf.line3d(point3d(-128, 768, 192), point3d(128, 768, 192), 0xE08080);

        _framebuf.line3d(point3d(-128, 512, 0), point3d(-128, 768, 0), 0xE08080);
        _framebuf.line3d(point3d(128, 512, 0), point3d(128, 768, 0), 0xE08080);

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

        // convert from framebuffer to colors
        _framebuf.drawToBuffer(_buf);
        // put to destination
        buf.drawImage(rc.left, rc.top, _buf);

        _needDraw = false;
    }


}
