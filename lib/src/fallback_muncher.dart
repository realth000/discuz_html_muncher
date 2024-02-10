import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as uh;
// ignore_for_file:prefer_function_declarations_over_variables

/// Default function to grep the image url from html [element].
///
/// Return null means no image url found.
final String? Function(BuildContext context, uh.Element element)
    defaultImageUrlGrepper = (context, element) {
  return element.attributes['src'] ?? element.attributes['file'];
};

/// Default function to build an image widget for the given image [url].
final InlineSpan Function(BuildContext context, String url)
    defaultImageBuilder = (context, url) {
  return WidgetSpan(child: Image.network(url));
};
