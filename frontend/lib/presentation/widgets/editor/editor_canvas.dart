import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../screens/editor/editor_screen.dart';
import '../shared/adaptive_media.dart';

class EditorCanvas extends StatelessWidget {
  const EditorCanvas({
    super.key,
    this.originalImage,
    this.currentImagePath,
    this.resultImage,
    this.imagePixelSize,
    required this.isGenerating,
    required this.activeTool,
    required this.onFlipHorizontal,
    required this.onMirror,
    required this.cropAspectRatio,
    required this.cropRect,
    required this.onCropRectChanged,
    required this.onConfirmCrop,
  });

  final File? originalImage;
  final String? currentImagePath;
  final Uint8List? resultImage;
  final Size? imagePixelSize;
  final bool isGenerating;
  final ToolType activeTool;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onMirror;
  final double cropAspectRatio;
  final Rect cropRect;
  final ValueChanged<Rect> onCropRectChanged;
  final VoidCallback onConfirmCrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final mediaRect = _resolveMediaRect(canvasSize);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF060609),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF14141A), Color(0xFF050507)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: _buildImageContent(),
                  ),
                ),
                const _CanvasShading(),
                if (activeTool == ToolType.crop && imagePixelSize != null)
                  Positioned.fromRect(
                    rect: mediaRect,
                    child: _CropOverlay(
                      cropRect: cropRect,
                      aspectRatio: cropAspectRatio,
                      onChanged: onCropRectChanged,
                    ),
                  ),
                if (activeTool == ToolType.crop)
                  Positioned(
                    right: 14,
                    bottom: 16,
                    child: Row(
                      children: [
                        _CanvasActionButton(
                          icon: Icons.swap_vert_rounded,
                          onTap: onFlipHorizontal,
                        ),
                        const SizedBox(width: 8),
                        _CanvasActionButton(
                          icon: Icons.swap_horiz_rounded,
                          onTap: onMirror,
                        ),
                        const SizedBox(width: 8),
                        _CanvasActionButton(
                          icon: Icons.check_rounded,
                          onTap: onConfirmCrop,
                          filled: true,
                        ),
                      ],
                    ),
                  ),
                if (isGenerating)
                  Container(
                    color: Colors.black.withValues(alpha: 0.28),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppTheme.electricIndigo,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              '正在记录本次编辑',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

  Rect _resolveMediaRect(Size canvasSize) {
    final imageSize = imagePixelSize;
    if (imageSize == null ||
        imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      return Rect.fromLTWH(16, 20, canvasSize.width - 32, canvasSize.height - 44);
    }

    final availableWidth = canvasSize.width - 32;
    final availableHeight = canvasSize.height - 44;
    final fittedScale = [
      availableWidth / imageSize.width,
      availableHeight / imageSize.height,
    ].reduce((a, b) => a < b ? a : b);
    final fittedWidth = imageSize.width * fittedScale;
    final fittedHeight = imageSize.height * fittedScale;
    final left = 16 + (availableWidth - fittedWidth) / 2;
    final top = 20 + (availableHeight - fittedHeight) / 2;
    return Rect.fromLTWH(left, top, fittedWidth, fittedHeight);
  }

  Widget _buildImageContent() {
    if (resultImage != null) {
      return Image.memory(resultImage!, fit: BoxFit.contain);
    }
    if (currentImagePath != null && currentImagePath!.trim().isNotEmpty) {
      return buildAdaptiveImage(
        currentImagePath,
        fit: BoxFit.contain,
        placeholder: const _CanvasFallback(),
        errorWidget: const _CanvasFallback(),
      );
    }
    if (originalImage != null) {
      return Image.file(originalImage!, fit: BoxFit.contain);
    }
    return const _CanvasFallback();
  }
}

class _CanvasActionButton extends StatelessWidget {
  const _CanvasActionButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: filled
                ? AppTheme.electricIndigo
                : Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _CanvasFallback extends StatelessWidget {
  const _CanvasFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 44,
            color: AppTheme.electricIndigo,
          ),
          SizedBox(height: 10),
          Text(
            '等待画面载入',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasShading extends StatelessWidget {
  const _CanvasShading();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.18),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.24, 1],
          ),
        ),
      ),
    );
  }
}

enum _CropDragMode { none, move, resize }

class _CropOverlay extends StatefulWidget {
  const _CropOverlay({
    required this.cropRect,
    required this.aspectRatio,
    required this.onChanged,
  });

  final Rect cropRect;
  final double aspectRatio;
  final ValueChanged<Rect> onChanged;

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  _CropDragMode _dragMode = _CropDragMode.none;
  Offset? _dragStart;
  Rect? _startRect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final crop = Rect.fromLTWH(
          widget.cropRect.left * width,
          widget.cropRect.top * height,
          widget.cropRect.width * width,
          widget.cropRect.height * height,
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            _dragStart = details.localPosition;
            _startRect = widget.cropRect;
            final local = details.localPosition;
            final handleZone = Rect.fromCircle(
              center: crop.bottomRight,
              radius: 28,
            );
            if (handleZone.contains(local)) {
              _dragMode = _CropDragMode.resize;
            } else if (crop.contains(local)) {
              _dragMode = _CropDragMode.move;
            } else {
              _dragMode = _CropDragMode.none;
            }
          },
          onPanUpdate: (details) {
            if (_dragMode == _CropDragMode.none ||
                _dragStart == null ||
                _startRect == null) {
              return;
            }
            final dx = details.localPosition.dx - _dragStart!.dx;
            final dy = details.localPosition.dy - _dragStart!.dy;
            if (_dragMode == _CropDragMode.move) {
              widget.onChanged(
                _clampCropRect(
                  _startRect!.shift(Offset(dx / width, dy / height)),
                  widget.aspectRatio,
                ),
              );
            } else {
              final start = _startRect!;
              var nextWidth = (start.width * width + dx) / width;
              var nextHeight = (start.height * height + dy) / height;
              if (widget.aspectRatio > 0) {
                nextHeight = nextWidth / widget.aspectRatio;
                if (start.top + nextHeight > 1) {
                  nextHeight = 1 - start.top;
                  nextWidth = nextHeight * widget.aspectRatio;
                }
              }
              widget.onChanged(
                _clampCropRect(
                  Rect.fromLTWH(
                    start.left,
                    start.top,
                    nextWidth,
                    widget.aspectRatio > 0 ? nextHeight : nextHeight,
                  ),
                  widget.aspectRatio,
                ),
              );
            }
          },
          onPanEnd: (_) {
            _dragMode = _CropDragMode.none;
            _dragStart = null;
            _startRect = null;
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _CropMaskPainter(cropRect: crop),
              ),
              Positioned(
                left: crop.left,
                top: crop.top,
                width: crop.width,
                height: crop.height,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.electricIndigo,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(
                            Icons.open_in_full_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Rect _clampCropRect(Rect rect, double aspectRatio) {
    var left = rect.left.clamp(0.0, 0.92);
    var top = rect.top.clamp(0.0, 0.92);
    var width = rect.width.clamp(0.18, 1.0 - left);
    var height = rect.height.clamp(0.18, 1.0 - top);

    if (aspectRatio > 0) {
      height = width / aspectRatio;
      if (top + height > 1) {
        height = 1 - top;
        width = height * aspectRatio;
      }
      if (left + width > 1) {
        width = 1 - left;
        height = width / aspectRatio;
      }
    }

    if (left + width > 1) {
      left = 1 - width;
    }
    if (top + height > 1) {
      top = 1 - height;
    }

    return Rect.fromLTWH(left, top, width, height);
  }
}

class _CropMaskPainter extends CustomPainter {
  const _CropMaskPainter({required this.cropRect});

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()..addRect(Offset.zero & size);
    final clearPath = Path()..addRect(cropRect);
    final path = Path.combine(PathOperation.difference, overlayPath, clearPath);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.46),
    );
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
