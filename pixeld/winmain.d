module pixeld.main;


import dlangui;

mixin APP_ENTRY_POINT;

import pixeld.graphics.pixelwidget;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    // resource directory search paths
    string[] resourceDirs = [
        appendPath(exePath, "../../../views/textures/"),
        appendPath(exePath, "../../views/textures/"),
        appendPath(exePath, "../views/textures/"),
        appendPath(exePath, "views/textures/"),
        appendPath(exePath, "textures/"),
    ];
    // setup resource directories - will use only existing directories
    Platform.instance.resourceDirs = resourceDirs;

    // create window
    Window window = Platform.instance.createWindow("DlangUI example - HelloWorld", null, 700, 500);

    // create some widget to show in window
    //window.mainWidget = (new Button()).text("Hello, world!"d).margins(Rect(20,20,20,20));
    window.mainWidget = parseML(q{
        VerticalLayout {
            margins: 10
            padding: 10
            backgroundColor: "#C0E0E070" // semitransparent yellow background
            // red bold text with size = 150% of base style size and font face Arial
            TextWidget { text: "Hello World example for DlangUI"; textColor: "red"; fontSize: 150%; fontWeight: 800; fontFace: "Arial" }
            VerticalLayout { id: body }
        }
    });

    PixelWidget pw = new PixelWidget();
    window.mainWidget.childById("body").addChild(pw);

    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
