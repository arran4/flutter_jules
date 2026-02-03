import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pasteboard/pasteboard.dart';
import '../../models/media.dart';

class ActivityImage extends StatelessWidget {
  final Media media;

  const ActivityImage({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.data.isEmpty) {
      return _buildMissingMediaDataRow(media.mimeType);
    }

    Uint8List bytes;
    try {
      bytes = base64Decode(media.data);
    } catch (e) {
      return _buildError(context, "Failed to decode image data");
    }

    return GestureDetector(
      onTap: () => _showImageDialog(context, bytes),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildError(context, "Failed to load image");
              },
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingMediaDataRow(String mimeType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.image, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            "Image ($mimeType) - No Data",
            style: const TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.broken_image, color: Colors.grey),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) =>
          _ActivityImageDialog(bytes: bytes, mimeType: media.mimeType),
    );
  }
}

class _ActivityImageDialog extends StatefulWidget {
  final Uint8List bytes;
  final String mimeType;

  const _ActivityImageDialog({required this.bytes, required this.mimeType});

  @override
  State<_ActivityImageDialog> createState() => _ActivityImageDialogState();
}

class _ActivityImageDialogState extends State<_ActivityImageDialog> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _saveImage() async {
    // Determine extension from mimeType or default to png
    String extension = 'png';
    if (widget.mimeType.contains('jpeg') || widget.mimeType.contains('jpg')) {
      extension = 'jpg';
    } else if (widget.mimeType.contains('gif')) {
      extension = 'gif';
    } else if (widget.mimeType.contains('webp')) {
      extension = 'webp';
    }

    final String fileName =
        'image_${DateTime.now().millisecondsSinceEpoch}.$extension';

    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saving not fully supported on Web yet.'),
          ),
        );
        return;
      }

      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'Images',
            extensions: [extension],
            mimeTypes: [widget.mimeType],
          ),
        ],
      );

      if (result != null) {
        final XFile file = XFile.fromData(
          widget.bytes,
          mimeType: widget.mimeType,
          name: fileName,
        );
        await file.saveTo(result.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image saved to ${result.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
      }
    }
  }

  Future<void> _copyImage() async {
    try {
      await Pasteboard.writeImage(widget.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to copy image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // The Image Viewer
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 5.0,
              child: Image.memory(widget.bytes, fit: BoxFit.contain),
            ),
          ),

          // Toolbar
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in, color: Colors.white),
                    tooltip: 'Zoom In',
                    onPressed: () {
                      final Matrix4 matrix =
                          _transformationController.value.clone();
                      // ignore: deprecated_member_use
                      matrix.scale(1.2);
                      _transformationController.value = matrix;
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, color: Colors.white),
                    tooltip: 'Zoom Out',
                    onPressed: () {
                      final Matrix4 matrix =
                          _transformationController.value.clone();
                      // ignore: deprecated_member_use
                      matrix.scale(1 / 1.2);
                      _transformationController.value = matrix;
                    },
                  ),
                  if (!kIsWeb)
                    IconButton(
                      icon: const Icon(Icons.save_alt, color: Colors.white),
                      tooltip: 'Save Image',
                      onPressed: _saveImage,
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    tooltip: 'Copy to Clipboard',
                    onPressed: _copyImage,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
