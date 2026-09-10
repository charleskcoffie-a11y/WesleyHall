import 'dart:typed_data';

import 'favicon_stub.dart'
    if (dart.library.html) 'favicon_web.dart' as implementation;

void setBrowserFavicon(Uint8List bytes) {
  implementation.setBrowserFavicon(bytes);
}
