module pixeld.graphics.pixelwidget;

import dlangui.graphics.drawbuf;
import dlangui.graphics.fonts;
import dlangui.widgets.widget;
import dlangui.core.logger;
import std.algorithm : min, max;
import std.math : abs, pow, sin, cos, PI, sqrt;
import std.conv : to;

import pixeld.graphics.types;
import pixeld.graphics.texture;
import pixeld.graphics.framebuf;


Texture createWallTexture() {
    Texture t = new Texture(8, 8);
    t.fillWith(0x802020);
    Pixel cl2 = Pixel(0x706020);
    int off = 16;
    for (int y = 0; y < 256; y += 32) {
        for (int x = 0; x < 256; x++) {
            t.putPixel(x, y, cl2);
            t.putPixel(x, y + 1, cl2);
            t.putPixel(x, y + 2, cl2);
        }
        off = off == 16 ? 48 : 16;
    }
    t.filter();
    return t;
}

Texture createFloorTexture() {
    Texture t = new Texture(8, 8);
    t.fillWith(0x504020);
    Pixel cl2 = Pixel(0x706020);
    int c3 = 256 / 3;
    for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 3; x++) {
            t.fillRect(x*c3 + 4, y*c3 + 4, (x+1)*c3 - 4, (y+1)*c3 - 4, Pixel(0x400020));
        }
    }
    t.filter();
    return t;
}

class PixelWidget : Widget {

    private FrameBuffer _framebuf;
    private ColorDrawBuf _buf;

    private Texture _wallTexture;
    private Texture _floorTexture;

    this() {
        super("pixelbuf");

        import std.math : pow;

        //initFramebuffer(256, 192, 2);

        focusable = true;

        _wallTexture = new Texture("stone_wall_4", 4); // createWallTexture();
        _floorTexture = new Texture("stone_wall_1", 4); // createFloorTexture();


        static if (false)
            initFramebuffer(256, 192, 2);
        else
            initFramebuffer(256 * 2, 192 * 2, 1);


        //_framebuf.rotationAngle = 270;
        //_framebuf.translationY = -64;
        //_framebuf.translationX = 64;

        drawScene();

    }

    ~this() {
        destroyFrameBuffer();
        destroy(_wallTexture);
        destroy(_floorTexture);
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
        version (Wireframe) {
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
        }
        version (Wireframe) {
            // ceil bounds
            _framebuf.line3d(point3d(x-128, y - 128, 192), point3d(x+128, y - 128, 192), cl);
            _framebuf.line3d(point3d(x-128, y - 128, 192), point3d(x-128, y + 128, 192), cl);
            _framebuf.line3d(point3d(x+128, y - 128, 192), point3d(x+128, y + 128, 192), cl);
            _framebuf.line3d(point3d(x-128, y + 128, 192), point3d(x+128, y + 128, 192), cl);
        }
        version (Wireframe) {
            // wall
            _framebuf.line3d(point3d(x-128, y + 128, 0), point3d(x-128, y + 128, 192), cl);
            _framebuf.line3d(point3d(x+128, y + 128, 0), point3d(x+128, y + 128, 192), cl);
        }

        _framebuf.drawTexture(_wallTexture, point3d(x-128, y - 128, 0), point3d(x-128, y - 128, 192), point3d(x-128, y + 128, 192), point3d(x-128, y + 128, 0),
                              point2d(0, 0), point2d(0, 0xC000), point2d(0x10000, 0xC000), point2d(0x10000, 0));
        _framebuf.drawTexture(_floorTexture, point3d(x-128, y - 128, 0), point3d(x-128, y + 128, 0), point3d(x+128, y + 128, 0), point3d(x+128, y - 128, 0),
                              point2d(0, 0), point2d(0, 0x10000), point2d(0x10000, 0x10000), point2d(0x10000, 0));
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
            //_framebuf.translationY += 1;
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
            auto dir = _framebuf.directionVector;
            if (event.keyCode == KeyCode.UP) {
                _framebuf.translationX += dir.x * 256;
                _framebuf.translationY += dir.y * 256;
                return true;
            }
            if (event.keyCode == KeyCode.DOWN) {
                _framebuf.translationX -= dir.x * 256;
                _framebuf.translationY -= dir.y * 256;
                return true;
            }
        }
        return super.onKeyEvent(event);
    }
}
