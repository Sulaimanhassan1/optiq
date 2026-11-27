import 'package:image/image.dart' as img;

img.Image normalizeGeometry(img.Image image, {int maxEdge = 2400}) {
  final oriented = img.bakeOrientation(image);
  if (oriented.width <= maxEdge && oriented.height <= maxEdge) return oriented;
  return img.copyResize(
    oriented,
    width: oriented.width >= oriented.height ? maxEdge : null,
    height: oriented.width < oriented.height ? maxEdge : null,
    interpolation: img.Interpolation.average,
  );
}
