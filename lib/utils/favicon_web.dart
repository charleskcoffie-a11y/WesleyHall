import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

void setBrowserFavicon(Uint8List bytes) {
  final href = 'data:image/png;base64,${base64Encode(bytes)}';

  // Remove Flutter/generated favicon references so the browser cannot keep
  // selecting the old icon from another <link> element.
  for (final element in html.document.querySelectorAll("link[rel*='icon']")) {
    element.remove();
  }

  final icon = html.LinkElement()
    ..rel = 'icon'
    ..type = 'image/png'
    ..href = href;

  final shortcut = html.LinkElement()
    ..rel = 'shortcut icon'
    ..type = 'image/png'
    ..href = href;

  final apple = html.LinkElement()
    ..rel = 'apple-touch-icon'
    ..href = href;

  html.document.head?.append(icon);
  html.document.head?.append(shortcut);
  html.document.head?.append(apple);
}
