import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'dart:math' as math;

class EditableProcessBar extends StatefulWidget {
  final double position;
  final ValueChanged<RangeValues> onChanged;
  final ValueChanged<double> onVideoChanged;
  final RangeValues values;
  final double max;
  final Size thumbSize;
  final List<String> frames;

  const EditableProcessBar({
    Key key,
    @required this.values,
    @required this.max,
    @required this.thumbSize,
    this.position,
    this.onChanged,
    this.onVideoChanged,
    this.frames,
  }) : super(key: key);
  @override
  _EditableProcessBarState createState() => _EditableProcessBarState();
}

class _EditableProcessBarState extends State<EditableProcessBar> {
  GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      widget.onVideoChanged(_contentKey.currentContext.size.width);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      height: widget.thumbSize.height,
      child: Stack(
        children: [
          ListView.builder(
              key: _contentKey,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: widget.thumbSize.width / 2),
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int index) {
                return Image.file(File(widget.frames[index]),
                    height: widget.thumbSize.height, fit: BoxFit.fitHeight);
              },
              itemCount: widget.frames.length),
          SliderTheme(
            data: SliderThemeData(
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: SliderComponentShape.noThumb,
                rangeThumbShape:
                    _MySliderThumbShape(thumbSize: widget.thumbSize),
                rangeTrackShape: _MyRangeSliderTrackShape()),
            child: RangeSlider(
              values: widget.values,
              onChanged: widget.onChanged,
              max: widget.max,
            ),
          ),
        ],
      ),
    );
  }
}

class _MySliderThumbShape extends RangeSliderThumbShape {
  _MySliderThumbShape({this.arrowColor = Colors.white, this.thumbSize});

  final Size thumbSize;
  final Color arrowColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return thumbSize;
  }

  @override
  void paint(PaintingContext context, Offset center,
      {Animation<double> activationAnimation,
      Animation<double> enableAnimation,
      bool isDiscrete,
      bool isEnabled,
      bool isOnTop,
      TextDirection textDirection,
      SliderThemeData sliderTheme,
      Thumb thumb,
      bool isPressed}) {
    final Canvas canvas = context.canvas;
    final ColorTween colorTween = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    );
    final Color color = colorTween.evaluate(enableAnimation);
    Paint rrectPaint = Paint()..color = color;
    Paint arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Rect rect = Rect.fromCenter(
        center: center, width: thumbSize.width, height: thumbSize.height);
    RRect rrect;
    Path arrowPath = Path();
    Radius radius = Radius.circular(2);

    if (thumb == Thumb.start) {
      rrect =
          RRect.fromRectAndCorners(rect, topLeft: radius, bottomLeft: radius);
      arrowPath = _leftArrowPath(center);
      canvas.drawRRect(rrect, rrectPaint);
      canvas.save();
      canvas.translate(-3, 0);
    } else {
      rrect =
          RRect.fromRectAndCorners(rect, topRight: radius, bottomRight: radius);
      arrowPath = _rightArrowPath(center);
      canvas.drawRRect(rrect, rrectPaint);
      canvas.save();
      canvas.translate(3, 0);
    }
    canvas.drawPath(arrowPath, arrowPaint);
    canvas.restore();
  }

  Path _leftArrowPath(Offset center) {
    return Path()
      ..moveTo(center.dx, center.dy)
      ..relativeLineTo(6, -6)
      ..moveTo(center.dx, center.dy)
      ..relativeLineTo(6, 6);
  }

  Path _rightArrowPath(Offset center) {
    return Path()
      ..moveTo(center.dx, center.dy)
      ..relativeLineTo(-6, -6)
      ..moveTo(center.dx, center.dy)
      ..relativeLineTo(-6, 6);
  }
}

class _MyRangeSliderTrackShape extends RangeSliderTrackShape {
  _MyRangeSliderTrackShape({this.strokeWidth = 2});

  final double strokeWidth;

  @override
  Rect getPreferredRect(
      {RenderBox parentBox,
      Offset offset = Offset.zero,
      SliderThemeData sliderTheme,
      bool isEnabled,
      bool isDiscrete}) {
    final double overlayWidth =
        sliderTheme.overlayShape.getPreferredSize(isEnabled, isDiscrete).width;
    final double trackHeight = sliderTheme.trackHeight;
    final double trackLeft = offset.dx + overlayWidth / 2;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackRight = trackLeft + parentBox.size.width - overlayWidth;
    final double trackBottom = trackTop + trackHeight;
    // If the parentBox'size less than slider's size the trackRight will be less than trackLeft, so switch them.
    return Rect.fromLTRB(math.min(trackLeft, trackRight), trackTop,
        math.max(trackLeft, trackRight), trackBottom);
  }

  @override
  void paint(PaintingContext context, Offset offset,
      {RenderBox parentBox,
      SliderThemeData sliderTheme,
      Animation<double> enableAnimation,
      Offset startThumbCenter,
      Offset endThumbCenter,
      bool isEnabled,
      bool isDiscrete,
      TextDirection textDirection}) {
    final Canvas canvas = context.canvas;
    final ColorTween colorTween = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    );
    final Color color = colorTween.evaluate(enableAnimation);
    final Paint paint = Paint()
      ..strokeWidth = strokeWidth
      ..color = color;
    final Offset topLeftPoint = Offset(startThumbCenter.dx, strokeWidth / 2);
    final Offset bottomLeftPoint =
        Offset(startThumbCenter.dx, startThumbCenter.dy * 2 - strokeWidth / 2);
    final Offset topRightPoint = Offset(endThumbCenter.dx, strokeWidth / 2);
    final Offset bottomRightPoint =
        Offset(endThumbCenter.dx, endThumbCenter.dy * 2 - strokeWidth / 2);
    canvas.drawLine(topLeftPoint, topRightPoint, paint);
    canvas.drawLine(bottomLeftPoint, bottomRightPoint, paint);
    //print('offset---$offset');
    //print('parentBox$parentBox');
  }
}
