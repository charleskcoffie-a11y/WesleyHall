import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

void setBrowserFavicon(Uint8List bytes) {
  final href = 'data:image/png;base64,${base64Encode(bytes)}';
  final existing = html.document.querySelector("link[rel*='icon']")
      as html.LinkElement?;
  final link = existing ?? html.LinkElement();
  link.rel = 'icon';
  link.href = href;
  link.type = 'image/png';
  if (existing == null) {
    html.document.head?.append(link);
  }
}
