import 'package:flutter/material.dart';

class PopupText extends StatelessWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextOverflow overflow;

  const PopupText(
    this.text, {
    super.key,
    this.maxLines = 1,
    this.style,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = this.style ?? DefaultTextStyle.of(context).style;
        final span = TextSpan(text: text, style: style);
        final tp = TextPainter(
          text: span,
          maxLines: maxLines,
          textDirection: Directionality.of(context),
        );
        tp.layout(maxWidth: constraints.maxWidth);

        if (tp.didExceedMaxLines) {
          return Tooltip(
            message: text,
            child: Text(
              text,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
            ),
          );
        } else {
          return Text(text, style: style);
        }
      },
    );
  }
}
