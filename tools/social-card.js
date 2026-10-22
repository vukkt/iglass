// Composes the GitHub social preview card (1280×640) with AppKit, using the system font.
// Usage: osascript -l JavaScript tools/social-card.js BACKDROP.png SCREENSHOT.png OUT.png
// Upload OUT.png in GitHub › Settings › General › Social preview.
ObjC.import("AppKit");

function run(argv) {
  const [backdropPath, shotPath, outPath] = argv;
  const W = 1280, H = 640;
  const rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
    null, W, H, 8, 4, true, false, $.NSDeviceRGBColorSpace, 0, 0);
  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.setCurrentContext($.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep));

  const draw = (path, rect) => {
    const img = $.NSImage.alloc.initWithContentsOfFile(path);
    img.drawInRectFromRectOperationFraction(rect, $.NSZeroRect, $.NSCompositingOperationSourceOver, 1.0);
  };
  const color = (r, g, b, a) => $.NSColor.colorWithSRGBRedGreenBlueAlpha(r, g, b, a);
  const text = (str, x, y, font, col) => {
    const attrs = $.NSDictionary.dictionaryWithObjectsForKeys(
      $([font, col]), $([$.NSFontAttributeName, $.NSForegroundColorAttributeName]));
    $(str).drawAtPointWithAttributes($.NSMakePoint(x, y), attrs);
  };
  const shadow = (blur, alpha) => {
    const s = $.NSShadow.alloc.init;
    s.shadowBlurRadius = blur;
    s.shadowOffset = $.NSMakeSize(0, -8);
    s.shadowColor = color(0, 0, 0, alpha);
    s.set;
  };

  // Backdrop, darkened toward the left (a soft fade, no edge) so the title reads well.
  draw(backdropPath, $.NSMakeRect(0, 0, W, H));
  const fade = $.NSGradient.alloc.initWithStartingColorEndingColor(
    color(0.04, 0.05, 0.12, 0.45), color(0.04, 0.05, 0.12, 0));
  fade.drawInRectAngle($.NSMakeRect(0, 0, 820, H), 0);

  // The terminal screenshot, as a floating window on the right.
  const shot = $.NSImage.alloc.initWithContentsOfFile(shotPath);
  const sw = 600, sh = Math.round(sw * shot.size.height / shot.size.width);
  const sx = W - sw - 48, sy = Math.round((H - sh) / 2);
  $.NSGraphicsContext.saveGraphicsState;
  shadow(40, 0.45);
  color(0, 0, 0, 1).setFill;
  $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(sx, sy, sw, sh), 14, 14).fill;
  $.NSGraphicsContext.restoreGraphicsState;
  $.NSGraphicsContext.saveGraphicsState;
  $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(sx, sy, sw, sh), 14, 14).addClip;
  shot.drawInRectFromRectOperationFraction($.NSMakeRect(sx, sy, sw, sh), $.NSZeroRect, $.NSCompositingOperationSourceOver, 1.0);
  $.NSGraphicsContext.restoreGraphicsState;

  // Title block.
  $.NSGraphicsContext.saveGraphicsState;
  shadow(16, 0.35);
  const white = color(1, 1, 1, 1), soft = color(1, 1, 1, 0.82);
  text("iglass", 64, 380, $.NSFont.systemFontOfSizeWeight(112, $.NSFontWeightBold), white);
  text("A Liquid Glass theme for", 68, 316, $.NSFont.systemFontOfSizeWeight(36, $.NSFontWeightSemibold), white);
  text("iTerm2, Ghostty, kitty & Warp", 68, 272, $.NSFont.systemFontOfSizeWeight(36, $.NSFontWeightSemibold), white);
  text("Real Liquid Glass in Ghostty · Apple system colors", 68, 214, $.NSFont.systemFontOfSizeWeight(21, $.NSFontWeightRegular), soft);
  text("Contrast-checked · light & dark · macOS & Linux", 68, 184, $.NSFont.systemFontOfSizeWeight(21, $.NSFontWeightRegular), soft);
  $.NSGraphicsContext.restoreGraphicsState;

  // Install command in a glass pill.
  const cmd = "brew install vukkt/tap/iglass";
  const mono = $.NSFont.monospacedSystemFontOfSizeWeight(21, $.NSFontWeightMedium);
  const cmdWidth = $(cmd).sizeWithAttributes($.NSDictionary.dictionaryWithObjectForKey(mono, $.NSFontAttributeName)).width;
  const pw = Math.ceil(cmdWidth) + 48; // 24 pt padding each side, sized to the text
  color(1, 1, 1, 0.16).setFill;
  $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(64, 96, pw, 50), 25, 25).fill;
  color(1, 1, 1, 0.35).setStroke;
  const pill = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(64.5, 96.5, pw - 1, 49), 24.5, 24.5);
  pill.lineWidth = 1;
  pill.stroke;
  text(cmd, 88, 108, mono, white);

  $.NSGraphicsContext.restoreGraphicsState;
  const png = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $({}));
  png.writeToFileAtomically(outPath, true);
  return "wrote " + outPath;
}
