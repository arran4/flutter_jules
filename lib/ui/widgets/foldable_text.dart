import 'package:flutter/material.dart';

class FoldableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  const FoldableText(this.text, {super.key, this.maxLines = 1, this.style});

  @override
  State<FoldableText> createState() => _FoldableTextState();
}

class _FoldableTextState extends State<FoldableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = widget.style ?? DefaultTextStyle.of(context).style;
        final span = TextSpan(text: widget.text, style: style);
        final tp = TextPainter(
          text: span,
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
        );
        tp.layout(maxWidth: constraints.maxWidth);

        if (tp.didExceedMaxLines) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              widget.text,
              style: style,
              maxLines: _isExpanded ? null : widget.maxLines,
              overflow: _isExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          );
        } else {
          return Text(widget.text, style: style);
        }
      },
    );
  }
}
