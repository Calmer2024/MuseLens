import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Mode for the paint brush tool.
enum PaintBrushMode { brush, eraser }

/// Data class that holds all the painted strokes.
class PaintBrushData {
  PaintBrushData();

  final List<_PaintStroke> _strokes = [];
  _PaintStroke? _currentStroke;

  bool get isEmpty => _strokes.isEmpty && _currentStroke == null;
  bool get isNotEmpty => !isEmpty;

  void clear() {
    _strokes.clear();
    _currentStroke = null;
  }

  /// Removes the last completed stroke (undo).
  void undoLast() {
    if (_strokes.isNotEmpty) {
      _strokes.removeLast();
    }
  }

  /// Renders the mask to an image (white on black) at the given pixel size.
  Future<Uint8List?> renderMask(Size pixelSize) async {
    if (isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, pixelSize.width, pixelSize.height),
      Paint()..color = const Color(0xFF000000),
    );

    // Draw strokes in white (brush) or black (eraser)
    for (final stroke in _strokes) {
      _drawStroke(canvas, stroke, pixelSize);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      pixelSize.width.round(),
      pixelSize.height.round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _drawStroke(Canvas canvas, _PaintStroke stroke, Size targetSize) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser ? const Color(0xFF000000) : const Color(0xFFFFFFFF)
      ..strokeWidth = stroke.strokeWidth * targetSize.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      canvas.drawCircle(
        Offset(point.dx * targetSize.width, point.dy * targetSize.height),
        stroke.strokeWidth * targetSize.width / 2,
        Paint()
          ..color = stroke.isEraser ? const Color(0xFF000000) : const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    final first = stroke.points.first;
    path.moveTo(first.dx * targetSize.width, first.dy * targetSize.height);
    for (int i = 1; i < stroke.points.length; i++) {
      final p = stroke.points[i];
      path.lineTo(p.dx * targetSize.width, p.dy * targetSize.height);
    }
    canvas.drawPath(path, paint);
  }
}

class _PaintStroke {
  _PaintStroke({
    required this.isEraser,
    required this.strokeWidth,
  });

  final bool isEraser;
  final double strokeWidth;
  final List<Offset> points = [];
}

/// The overlay widget that shows on top of the canvas for painting.
class PaintBrushOverlay extends StatefulWidget {
  const PaintBrushOverlay({
    super.key,
    required this.paintData,
    required this.mode,
    required this.brushSize,
    required this.onChanged,
  });

  final PaintBrushData paintData;
  final PaintBrushMode mode;
  final double brushSize;
  final VoidCallback onChanged;

  @override
  State<PaintBrushOverlay> createState() => _PaintBrushOverlayState();
}

class _PaintBrushOverlayState extends State<PaintBrushOverlay> {
  Offset? _cursorPosition;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: (event) {
            setState(() => _cursorPosition = event.localPosition);
          },
          onExit: (_) {
            setState(() => _cursorPosition = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              final normalizedPoint = Offset(
                details.localPosition.dx / size.width,
                details.localPosition.dy / size.height,
              );
              final stroke = _PaintStroke(
                isEraser: widget.mode == PaintBrushMode.eraser,
                strokeWidth: widget.brushSize / size.width,
              );
              stroke.points.add(normalizedPoint);
              widget.paintData._currentStroke = stroke;
              widget.onChanged();
              setState(() => _cursorPosition = details.localPosition);
            },
            onPanUpdate: (details) {
              final normalizedPoint = Offset(
                (details.localPosition.dx / size.width).clamp(0.0, 1.0),
                (details.localPosition.dy / size.height).clamp(0.0, 1.0),
              );
              widget.paintData._currentStroke?.points.add(normalizedPoint);
              widget.onChanged();
              setState(() => _cursorPosition = details.localPosition);
            },
            onPanEnd: (_) {
              final current = widget.paintData._currentStroke;
              if (current != null && current.points.isNotEmpty) {
                widget.paintData._strokes.add(current);
              }
              widget.paintData._currentStroke = null;
              widget.onChanged();
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _PaintBrushPainter(
                    paintData: widget.paintData,
                    viewSize: size,
                  ),
                ),
                if (_cursorPosition != null)
                  Positioned(
                    left: _cursorPosition!.dx - widget.brushSize / 2,
                    top: _cursorPosition!.dy - widget.brushSize / 2,
                    child: IgnorePointer(
                      child: Container(
                        width: widget.brushSize,
                        height: widget.brushSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.mode == PaintBrushMode.eraser
                                ? Colors.white.withValues(alpha: 0.8)
                                : const Color(0xFFAB7CFF),
                            width: 1.5,
                          ),
                          color: widget.mode == PaintBrushMode.eraser
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFAB7CFF).withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaintBrushPainter extends CustomPainter {
  _PaintBrushPainter({
    required this.paintData,
    required this.viewSize,
  });

  final PaintBrushData paintData;
  final Size viewSize;

  @override
  void paint(Canvas canvas, Size size) {
    final allStrokes = [
      ...paintData._strokes,
      if (paintData._currentStroke != null) paintData._currentStroke!,
    ];

    for (final stroke in allStrokes) {
      _drawViewStroke(canvas, stroke);
    }
  }

  void _drawViewStroke(Canvas canvas, _PaintStroke stroke) {
    if (stroke.points.isEmpty) return;

    final brushColor = stroke.isEraser
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFAB7CFF).withValues(alpha: 0.35);
    final strokeWidthPx = stroke.strokeWidth * viewSize.width;

    final paint = Paint()
      ..color = brushColor
      ..strokeWidth = strokeWidthPx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      canvas.drawCircle(
        Offset(p.dx * viewSize.width, p.dy * viewSize.height),
        strokeWidthPx / 2,
        Paint()
          ..color = brushColor
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    final first = stroke.points.first;
    path.moveTo(first.dx * viewSize.width, first.dy * viewSize.height);
    for (int i = 1; i < stroke.points.length; i++) {
      final p = stroke.points[i];
      path.lineTo(p.dx * viewSize.width, p.dy * viewSize.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PaintBrushPainter oldDelegate) => true;
}

/// The floating toolbar that shows when paint mode is active.
class PaintBrushToolbar extends StatelessWidget {
  const PaintBrushToolbar({
    super.key,
    required this.mode,
    required this.brushSize,
    required this.onModeChanged,
    required this.onBrushSizeChanged,
    required this.onUndo,
    required this.onClear,
    required this.onClose,
    required this.canUndo,
  });

  final PaintBrushMode mode;
  final double brushSize;
  final ValueChanged<PaintBrushMode> onModeChanged;
  final ValueChanged<double> onBrushSizeChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE6101018),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode buttons row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.brush_rounded,
                label: '画笔',
                isActive: mode == PaintBrushMode.brush,
                activeColor: const Color(0xFFAB7CFF),
                onTap: () => onModeChanged(PaintBrushMode.brush),
              ),
              const SizedBox(width: 4),
              _ToolbarButton(
                icon: Icons.auto_fix_high_rounded,
                label: '橡皮',
                isActive: mode == PaintBrushMode.eraser,
                activeColor: Colors.white,
                onTap: () => onModeChanged(PaintBrushMode.eraser),
              ),
              const SizedBox(width: 4),
              _ToolbarButton(
                icon: Icons.undo_rounded,
                label: '撤销',
                isActive: false,
                enabled: canUndo,
                onTap: onUndo,
              ),
              const SizedBox(width: 4),
              _ToolbarButton(
                icon: Icons.delete_outline_rounded,
                label: '清除',
                isActive: false,
                onTap: onClear,
              ),
              const SizedBox(width: 4),
              _ToolbarButton(
                icon: Icons.close_rounded,
                label: '关闭',
                isActive: false,
                onTap: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Brush size slider
          SizedBox(
            width: 200,
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFFAB7CFF),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 3,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: brushSize,
                      min: 8,
                      max: 60,
                      onChanged: onBrushSizeChanged,
                    ),
                  ),
                ),
                Icon(
                  Icons.circle,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = !enabled
        ? Colors.white.withValues(alpha: 0.2)
        : isActive
            ? (activeColor ?? Colors.white)
            : Colors.white.withValues(alpha: 0.65);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? (activeColor ?? Colors.white).withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: effectiveColor, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
