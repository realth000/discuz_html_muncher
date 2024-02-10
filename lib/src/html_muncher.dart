import 'dart:async';

import 'package:collection/collection.dart';
import 'package:discuz_html_muncher/src/fallback_muncher.dart';
import 'package:discuz_html_muncher/src/types.dart';
import 'package:discuz_html_muncher/src/web_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as uh;

/// Define a [callback] to munch a html node with given [tag] and [className]
/// into a flutter widget.
///
/// # Example
///
/// To munch node:
///
/// ```html
/// <div class="foo bar">...</div>
/// ```
///
/// into plain text, register:
///
/// ```dart
/// MunchTagCallback({
///   tag: "div",
///   className: "foo", // or className: "bar"
///   callback: (context, element) {
///     return TextSpan(text: element.innerHtml);
///   },
/// })
/// ```
class MunchTagCallback {
  /// Constructor.
  const MunchTagCallback({
    required this.tag,
    required this.callback,
    this.className,
  });

  /// Only html node has the [tag] will be called on this [callback].
  final String tag;

  /// Only html node has class name [className] will be called on this
  /// [callback].
  ///
  /// Optional, will only apply on [tag] nodes if [className] is null.
  final String? className;

  /// Describe how to munch html node into flutter widget.
  final Widget Function(BuildContext context, uh.Element element) callback;
}

/// State of [Muncher].
class _MunchState {
  /// State of munching html document.
  _MunchState();

  /// Use bold font.
  bool bold = false;

  /// User underline.
  bool underline = false;

  /// Add line strike.
  bool lineThrough = false;

  /// Align span in center.
  bool center = false;

  /// Flag indicating current node's parent is `<div>` or not.
  /// IF in a div, should make sure current item is in a new line.
  bool inDiv = false;

  /// If true, use [String.trim], if false, use [String.trimLeft].
  bool trimAll = false;

  /// Flag to indicate whether in state of repeated line wrapping.
  bool inRepeatWrapLine = false;

  /// Text alignment.
  TextAlign? textAlign;

  /// All colors currently used.
  ///
  /// Use as a stack because only the latest font works on font.
  final colorStack = <Color>[];

  /// All font sizes currently used.
  ///
  /// Use as a stack because only the latest size works on font.
  final fontSizeStack = <double>[];

  /// Url to open when tap on the text.
  String? tapUrl;

  /// An internal field to save field current values.
  _MunchState? _reservedState;

  /// Save current state [_reservedState].
  void save() {
    _reservedState = this;
  }

  /// Restore state from [_reservedState].
  void restore() {
    if (_reservedState != null) {
      return;
    }
    bold = _reservedState!.bold;
    underline = _reservedState!.underline;
    lineThrough = _reservedState!.lineThrough;
    center = _reservedState!.center;
    textAlign = _reservedState!.textAlign;
    colorStack
      ..clear()
      ..addAll(_reservedState!.colorStack);
    fontSizeStack
      ..clear()
      ..addAll(_reservedState!.fontSizeStack);
    tapUrl = _reservedState!.tapUrl;

    _reservedState = null;
  }

  @override
  String toString() {
    return 'MunchState {bold=$bold, underline=$underline, '
        'lineThrough=$lineThrough, color=$colorStack}';
  }
}

/// Munch html nodes into flutter widgets.
class Muncher {
  /// Constructor.
  Muncher({
    required BuildContext context,
    this.munchTagCallbackList = const [],
  }) : _context = context;

  /// A list of callback to munch node into flutter widgets.
  List<MunchTagCallback> munchTagCallbackList;

  /// Context to build widget when munching.
  final BuildContext _context;

  /// Munch state to use when munching.
  final _MunchState _state = _MunchState();

  /// Map to store div classes and corresponding munch functions.
  Map<String, InlineSpan Function(BuildContext, uh.Element)>? _divMap;

  FutureOr<void> Function(BuildContext context, String url)? _urlLauncher;

  late String? Function(BuildContext context, uh.Element element)
      _imageUrlGrepper = defaultImageUrlGrepper;

  late InlineSpan Function(BuildContext context, String url) _imageBuilder =
      defaultImageBuilder;

  InlineSpan Function(BuildContext context, uh.Element element)?
      _blockCodeBuilder;
  InlineSpan Function(BuildContext context, uh.Element element)?
      _spoilerBuilder;
  InlineSpan Function(BuildContext context, uh.Element element)? _lockedBuilder;
  InlineSpan Function(BuildContext context, uh.Element element)? _reviewBuilder;

  /*                Register Functions                      */

  /// Register how to launch an url when user tap on an url.
  ///
  /// When not registered, muncher will do nothing.
  ///
  /// ignore: use_setters_to_change_properties
  void registerUrlLauncher(
    FutureOr<void> Function(BuildContext context, String url) callback,
  ) {
    _urlLauncher = callback;
  }

  /// Register how to grep the image url from an <img> type node.
  ///
  /// Return null to represent no image url found on the node.
  ///
  /// When not registered, muncher will only check the "src"
  /// and "file" attribute.
  ///
  /// ignore: use_setters_to_change_properties
  void registerImageUrlGrepper(
    String? Function(BuildContext context, uh.Element element) callback,
  ) {
    _imageUrlGrepper = callback;
  }

  /// Register how to build a image widget for the given image url.
  ///
  /// When not registered, use [Image.network].
  ///
  /// ignore: use_setters_to_change_properties
  void registerImageBuilder(
    InlineSpan Function(BuildContext context, String url) callback,
  ) {
    _imageBuilder = callback;
  }

  /// Register how to build a widget from a node <div class="blockcode">.
  ///
  /// When not registered, do nothing.
  ///
  /// ignore: use_setters_to_change_properties
  void registerBlockCodeBuilder(
    InlineSpan Function(BuildContext context, uh.Element element) callback,
  ) {
    _blockCodeBuilder = callback;
  }

  /// Register how to build a widget from a node <div class="spoiler">.
  ///
  /// When not registered, do nothing.
  ///
  /// ignore: use_setters_to_change_properties
  void registerSpoilerBuilder(
    InlineSpan Function(BuildContext context, uh.Element element) callback,
  ) {
    _spoilerBuilder = callback;
  }

  /// Register how to build a widget from a node <div class="spoiler">.
  ///
  /// When not registered, do nothing.
  ///
  /// ignore: use_setters_to_change_properties
  void registerLockedBuilder(
    InlineSpan Function(BuildContext context, uh.Element element) callback,
  ) {
    _lockedBuilder = callback;
  }

  /// Register how to build a widget from a node <div class="cm">.
  ///
  /// When not registered, do nothing.
  ///
  /// ignore: use_setters_to_change_properties
  void registerReviewBuilder(
    InlineSpan Function(BuildContext context, uh.Element element) callback,
  ) {
    _reviewBuilder = callback;
  }

  /*                Munch Functions                      */

  /// Munch the html node [rootElement] and its children nodes into a flutter
  /// widget.
  ///
  /// Main entry of this package.
  Widget munchElement(uh.Element rootElement) {
    // Alignment in this page requires a fixed max width that equals to website
    // page width.
    // Currently is 712.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 712,
      ),
      child: RichText(text: _munch(_context, rootElement)),
    );
  }

  InlineSpan _munch(BuildContext context, uh.Element rootElement) {
    final spanList = <InlineSpan>[];

    for (final node in rootElement.nodes) {
      final span = munchNode(node);
      if (span != null) {
        spanList.add(span);
      }
    }
    if (spanList.isEmpty) {
      // Not intend to happen.
      return const TextSpan();
    }
    // Do not wrap in another layout when there is only one span.
    if (spanList.length == 1) {
      return spanList.first;
    }
    return TextSpan(children: spanList);
  }

  /// Munch a [node] and its children.
  InlineSpan? munchNode(uh.Node? node) {
    if (node == null) {
      // Reach end.
      return null;
    }
    switch (node.nodeType) {
      // Text node does not have children.
      case uh.Node.TEXT_NODE:
        {
          final text =
              _state.trimAll ? node.text?.trim() : node.text?.trimLeft();
          // If text is trimmed to empty, maybe it is an '\n' before trimming.
          if (text?.isEmpty ?? true) {
            if (_state.trimAll) {
              return null;
            }
            if (_state.inRepeatWrapLine) {
              return null;
            }
            _state.inRepeatWrapLine = true;
            return const TextSpan(text: '\n');
          }

          // Base text style.
          var style = Theme.of(_context).textTheme.bodyMedium?.copyWith(
                color: _state.colorStack.lastOrNull,
                fontWeight: _state.bold ? FontWeight.w600 : null,
                fontSize: _state.fontSizeStack.lastOrNull,
                decoration: TextDecoration.combine([
                  if (_state.underline) TextDecoration.underline,
                  if (_state.lineThrough) TextDecoration.lineThrough,
                ]),
                decorationThickness: 1.5,
              );

          // Attach url to open when `onTap`.
          GestureRecognizer? recognizer;
          if (_state.tapUrl != null) {
            final u = _state.tapUrl!;
            recognizer = TapGestureRecognizer()
              ..onTap = () async {
                await _urlLauncher?.call(_context, u);
              };
            style = style?.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dashed,
            );
          }

          _state.inRepeatWrapLine = false;
          // TODO: Support text-shadow.
          return TextSpan(
            text: _state.inDiv ? '${text ?? ""}\n' : text,
            recognizer: recognizer,
            style: style,
          );
        }

      case uh.Node.ELEMENT_NODE:
        {
          final element = node as uh.Element;
          final localName = element.localName;

          // Skip invisible nodes.
          if (element.attributes['style']?.contains('display: none') ?? false) {
            return null;
          }

          // TODO: Handle <ul> and <li> marker
          // Parse according to element types.
          final span = switch (localName) {
            'img' when _imageUrlGrepper(_context, node) != null =>
              _imageBuilder(_context, _imageUrlGrepper(_context, node)!),
            'br' => const TextSpan(text: '\n'),
            'font' => _buildFont(node),
            'strong' => _buildStrong(node),
            'u' => _buildUnderline(node),
            'strike' => _buildLineThrough(node),
            'p' => _buildP(node),
            'span' => _buildSpan(node),
            'blockquote' => _buildBlockQuote(node),
            'div' => _munchDiv(node),
            'a' => _buildA(node),
            'tr' => _buildTr(node),
            'td' => _buildTd(node),
            'h1' => _buildH1(node),
            'h2' => _buildH2(node),
            'h3' => _buildH3(node),
            'h4' => _buildH4(node),
            'li' => _buildLi(node),
            'code' => _buildCode(node),
            'dl' => _buildDl(node),
            'b' => _buildB(node),
            'ignore_js_op' ||
            'table' ||
            'tbody' ||
            'ul' ||
            'dd' ||
            'pre' =>
              _munch(_context, node),
            String() => null,
          };
          return span;
        }
    }
    return null;
  }

  InlineSpan _buildFont(uh.Element element) {
    final oldInDiv = _state.inDiv;
    _state.inDiv = false;
    // Setup color
    final hasColor = _tryPushColor(element);
    // Setup font size.
    final hasFontSize = _tryPushFontSize(element);
    // Munch!
    final ret = _munch(_context, element);

    // Restore color
    if (hasColor) {
      _state.colorStack.removeLast();
    }
    if (hasFontSize) {
      _state.fontSizeStack.removeLast();
    }

    _state.inDiv = oldInDiv;
    // Restore color.
    return TextSpan(children: [ret, const TextSpan(text: '\n')]);
  }

  InlineSpan _buildStrong(uh.Element element) {
    _state.bold = true;
    final ret = _munch(_context, element);
    _state.bold = false;
    return ret;
  }

  InlineSpan _buildUnderline(uh.Element element) {
    _state.underline = true;
    final ret = _munch(_context, element);
    _state.underline = false;
    return ret;
  }

  InlineSpan _buildLineThrough(uh.Element element) {
    _state.lineThrough = true;
    final ret = _munch(_context, element);
    _state.lineThrough = false;
    return ret;
  }

  InlineSpan _buildP(uh.Element element) {
    final oldInDiv = _state.inDiv;
    _state.inDiv = false;
    // Alignment requires the whole rendered page to a fixed max width that
    // equals to website page, otherwise if is different if we have a "center"
    // or "right" alignment.
    final alignValue = element.attributes['align'];
    final align = switch (alignValue) {
      'left' => TextAlign.left,
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      String() => null,
      null => null,
    };

    // Setup text align.
    //
    // Text align only have effect on the [RichText]'s children, not its
    /// children's children. Remember every time we build a [RichText]
    /// with "children" we need to apply the current text alignment.
    if (align != null) {
      _state.textAlign = align;
    }

    final ret = _munch(_context, element);

    late final InlineSpan ret2;

    if (align != null) {
      ret2 = WidgetSpan(
        child: Row(
          children: [
            Expanded(
              child: RichText(
                text: ret,
                textAlign: align,
              ),
            ),
          ],
        ),
      );

      // Restore text align.
      _state.textAlign = null;
    } else {
      ret2 = ret;
    }

    _state.inDiv = oldInDiv;
    return ret2;
  }

  InlineSpan _buildSpan(uh.Element element) {
    final styleEntries = element.attributes['style']
        ?.split(';')
        .map((e) {
          final x = e.trim().split(':');
          return (x.firstOrNull?.trim(), x.lastOrNull?.trim());
        })
        .whereType<(String, String)>()
        .map((e) => MapEntry(e.$1, e.$2))
        .toList();
    if (styleEntries == null) {
      final ret = _munch(_context, element);
      return TextSpan(children: [ret, const TextSpan(text: '\n')]);
    }

    final styleMap = Map.fromEntries(styleEntries);
    final color = styleMap['color'];
    final hasColor = _tryPushColor(element, colorString: color);
    final fontSize = styleMap['font-size'];
    final hasFontSize = _tryPushFontSize(element, fontSizeString: fontSize);

    final ret = _munch(_context, element);

    if (hasColor) {
      _state.colorStack.removeLast();
    }
    if (hasFontSize) {
      _state.fontSizeStack.removeLast();
    }

    return TextSpan(children: [ret, const TextSpan(text: '\n')]);
  }

  InlineSpan _buildBlockQuote(uh.Element element) {
    // Try isolate the munch state inside quoted message.
    // Bug is that when the original quoted message "truncated" at unclosed
    // tags like "foo[s]bar...", the unclosed tag will affect all
    // following contents in current post, that is, all texts are marked with
    // line through.
    // This is unfixable after rendered into html because we do not know whether
    // a whole decoration tag (e.g. <strike>) contains the all following post
    // messages is user added or caused by the bug above. Here just try to save
    // and restore munch state to avoid potential issued about "styles inside
    // quoted blocks  affects outside main content".
    _state.save();
    final ret = _munch(_context, element);
    _state.restore();
    return TextSpan(
      children: [
        WidgetSpan(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: RichText(text: ret),
            ),
          ),
        ),
        const TextSpan(text: '\n'),
      ],
    );
  }

  InlineSpan _munchDiv(uh.Element element) {
    if (_divMap == null) {
      _divMap = {};
      if (_blockCodeBuilder != null) {
        _divMap!['blockcode'] = _blockCodeBuilder!;
      }
      if (_spoilerBuilder != null) {
        _divMap!['spoiler'] = _spoilerBuilder!;
      }
      if (_lockedBuilder != null) {
        _divMap!['locked'] = _lockedBuilder!;
      }
      if (_reviewBuilder != null) {
        _divMap!['cm'] = _reviewBuilder!;
      }
    }

    final alreadyInDiv = _state.inDiv;

    if (!alreadyInDiv) {
      _state.inDiv = true;
    }
    // Find the first munch executor, use `_munch` if none found.
    final executor = _divMap!.entries
            .firstWhereOrNull((e) => element.classes.contains(e.key))
            ?.value ??
        _munch;
    final ret = executor(_context, element);
    if (!alreadyInDiv) {
      _state.inDiv = false;
    }
    return ret;
  }

  InlineSpan _buildA(uh.Element element) {
    if (element.attributes.containsKey('href')) {
      _state.tapUrl = element.attributes['href'];
      final ret = _munch(_context, element);
      _state.tapUrl = null;
      return ret;
    }
    return _munch(_context, element);
  }

  InlineSpan _buildTr(uh.Element element) {
    _state.trimAll = true;
    final ret = _munch(_context, element);
    _state.trimAll = false;
    return TextSpan(children: [ret, const TextSpan(text: '\n')]);
  }

  InlineSpan _buildTd(uh.Element element) {
    _state.trimAll = true;
    final ret = _munch(_context, element);
    _state.trimAll = false;
    return TextSpan(children: [ret, const TextSpan(text: ' ')]);
  }

  InlineSpan _buildH1(uh.Element element) {
    _state.fontSizeStack.add(FontSize.size6.value());
    final ret = _munch(_context, element);
    _state.fontSizeStack.removeLast();
    return TextSpan(
      children: [
        const TextSpan(text: '\n'),
        ret,
        const TextSpan(text: '\n'),
      ],
    );
  }

  InlineSpan _buildH2(uh.Element element) {
    _state.fontSizeStack.add(FontSize.size5.value());
    final ret = _munch(_context, element);
    _state.fontSizeStack.removeLast();
    return TextSpan(
      children: [
        const TextSpan(text: '\n'),
        ret,
        const TextSpan(text: '\n'),
      ],
    );
  }

  InlineSpan _buildH3(uh.Element element) {
    _state.fontSizeStack.add(FontSize.size4.value());
    final ret = _munch(_context, element);
    _state.fontSizeStack.removeLast();
    return TextSpan(
      children: [
        const TextSpan(text: '\n'),
        ret,
        const TextSpan(text: '\n'),
      ],
    );
  }

  InlineSpan _buildH4(uh.Element element) {
    _state.fontSizeStack.add(FontSize.size3.value());
    final ret = _munch(_context, element);
    _state.fontSizeStack.removeLast();
    return TextSpan(
      children: [
        const TextSpan(text: '\n'),
        ret,
        const TextSpan(text: '\n'),
      ],
    );
  }

  InlineSpan _buildLi(uh.Element element) {
    final ret = _munch(_context, element);
    return TextSpan(
      children: [
        WidgetSpan(
          child: Icon(
            Icons.radio_button_unchecked,
            size: FontSize.size2.value(),
          ),
        ),
        const TextSpan(text: ' '),
        ret,
      ],
    );
  }

  /// <code>xxx</code> tags. Mainly for github.com
  InlineSpan _buildCode(uh.Element element) {
    _state.fontSizeStack.add(FontSize.size2.value());
    final ret = _munch(_context, element);
    _state.fontSizeStack.removeLast();
    return WidgetSpan(
      child: Card(
        color: Theme.of(_context).colorScheme.onSecondary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        margin: EdgeInsets.zero,
        child: RichText(text: ret),
      ),
    );
  }

  InlineSpan _buildDl(uh.Element element) {
    // Skip rate log area.
    if (element.id.startsWith('ratelog_')) {
      return const TextSpan();
    }
    return _munch(_context, element);
  }

  InlineSpan _buildB(uh.Element element) {
    final ret = _munch(_context, element);
    return TextSpan(children: [ret, const TextSpan(text: '\n')]);
  }

  /*                Setup Functions                      */

  /// Try parse color from [element].
  /// When provide [colorString], use that in advance.
  ///
  /// If has valid color, push to stack and return true.
  bool _tryPushColor(uh.Element element, {String? colorString}) {
    // Trim and add alpha value for "#ffafc7".
    // Set to an invalid color value if "color" attribute not found.
    final attr = colorString ?? element.attributes['color'];
    int? colorValue;
    if (attr != null && attr.startsWith('#')) {
      colorValue = int.tryParse(
        element.attributes['color']?.substring(1).padLeft(8, 'ff') ?? 'g',
        radix: 16,
      );
    }
    Color? color;
    if (colorValue != null) {
      color = Color(colorValue);
      _state.colorStack.add(color);
    } else {
      // If color not in format #aabcc, try parse as color name.
      final webColor = WebColors.fromString(attr);
      if (webColor.isValid) {
        color = webColor.color;
        _state.colorStack.add(color);
      }
    }
    return color != null;
  }

  /// Try parse font size from [element].
  /// When provide [fontSizeString], use that in advance.
  ///
  /// If has valid color, push to stack and return true.
  bool _tryPushFontSize(uh.Element element, {String? fontSizeString}) {
    final fontSize =
        FontSize.fromString(fontSizeString ?? element.attributes['size']);
    if (fontSize.isValid) {
      _state.fontSizeStack.add(fontSize.value());
    }
    return fontSize.isValid;
  }
}
