import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/photo_crop.dart';
import '../models/widget_config.dart';

/// The same crop is used for preview, touch adjustment and native widgets.
class WidgetSurface extends StatefulWidget {
  const WidgetSurface({
    super.key,
    required this.config,
    required this.background,
    required this.foreground,
    required this.child,
    this.photo,
    this.onPhotoChanged,
  });
  final WidgetConfig config;
  final Color background, foreground;
  final String? photo;
  final Widget child;
  final ValueChanged<WidgetConfig>? onPhotoChanged;

  @override
  State<WidgetSurface> createState() => _WidgetSurfaceState();
}

class _WidgetSurfaceState extends State<WidgetSurface> {
  ImageStream? _stream;
  ImageInfo? _image;
  String? _source;
  ImageProvider? _provider;
  late final ImageStreamListener _listener;
  Offset _startFocal = Offset.zero;
  double _startScale = 1, _startX = 0, _startY = 0;

  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener(
      (image, _) {
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = image;
        });
      },
      onError: (Object error, StackTrace? stack) {
        if (mounted) {
          setState(() {
            _image?.dispose();
            _image = null;
          });
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(WidgetSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo) _resolve();
  }

  void _resolve() {
    if (_source != widget.photo) {
      _source = widget.photo;
      try {
        _provider = _source == null
            ? null
            : MemoryImage(base64Decode(_source!));
      } catch (_) {
        _provider = null;
      }
    }
    final next = _provider?.resolve(createLocalImageConfiguration(context));
    if (next?.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _image?.dispose();
    _image = null;
    _stream = next;
    _stream?.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  void _updateCrop(ScaleUpdateDetails details, Size viewport) {
    final image = _image?.image;
    if (image == null) return;
    final scale = (_startScale * details.scale).clamp(1.0, 3.0);
    final alignment = PhotoCrop.transformAlignment(
      Size(image.width.toDouble(), image.height.toDouble()),
      viewport,
      _startScale,
      Offset(_startX, _startY),
      scale,
      _startFocal,
      details.localFocalPoint,
    );
    widget.onPhotoChanged?.call(
      widget.config.copyWith(
        photoScale: scale,
        photoX: alignment.dx,
        photoY: alignment.dy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final config = widget.config;
      final viewport = constraints.biggest;
      final editing = widget.onPhotoChanged != null && _image != null;
      final content = ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              key: const ValueKey('widget-background-opacity'),
              opacity: config.backgroundOpacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.background,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: widget.foreground.withValues(alpha: .12),
                  ),
                ),
                child: _image == null
                    ? null
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _PhotoPainter(_image!.image, config),
                          ),
                          DecoratedBox(
                            key: const ValueKey('widget-photo-shade'),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (config.textTone == 'dark'
                                          ? Colors.white
                                          : Colors.black)
                                      .withValues(alpha: config.photoDim),
                                  (config.textTone == 'dark'
                                          ? Colors.white
                                          : Colors.black)
                                      .withValues(
                                        alpha: math.min(
                                          .9,
                                          config.photoDim + .15,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            widget.child,
            if (editing)
              const IgnorePointer(child: CustomPaint(painter: _CropGrid())),
          ],
        ),
      );
      if (!editing) return content;
      return MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              GestureBinding.instance.pointerSignalResolver.register(event, (
                _,
              ) {
                final nextScale =
                    (config.photoScale - event.scrollDelta.dy * .002).clamp(
                      1.0,
                      3.0,
                    );
                final image = _image!.image;
                final alignment = PhotoCrop.transformAlignment(
                  Size(image.width.toDouble(), image.height.toDouble()),
                  viewport,
                  config.photoScale,
                  Offset(config.photoX, config.photoY),
                  nextScale,
                  event.localPosition,
                  event.localPosition,
                );
                widget.onPhotoChanged?.call(
                  config.copyWith(
                    photoScale: nextScale,
                    photoX: alignment.dx,
                    photoY: alignment.dy,
                  ),
                );
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _startFocal = details.localFocalPoint;
              _startScale = config.photoScale;
              _startX = config.photoX;
              _startY = config.photoY;
            },
            onScaleUpdate: (details) => _updateCrop(details, viewport),
            child: content,
          ),
        ),
      );
    },
  );
}

class _PhotoPainter extends CustomPainter {
  const _PhotoPainter(this.image, this.config);
  final ui.Image image;
  final WidgetConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final source = PhotoCrop.sourceRect(
      Size(image.width.toDouble(), image.height.toDouble()),
      size,
      config.photoScale,
      config.photoX,
      config.photoY,
    );
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PhotoPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.config != config;
}

class _CropGrid extends CustomPainter {
  const _CropGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CropGrid oldDelegate) => false;
}

class AppearanceSlider extends StatelessWidget {
  const AppearanceSlider({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions = 100,
  });
  final String label, valueLabel;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(valueLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      Semantics(
        label: label,
        child: Slider(
          key: ValueKey('slider-$label'),
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          semanticFormatterCallback: (_) => valueLabel,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}
