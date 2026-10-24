import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQr),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.cameraError,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          CustomPaint(
            size: const Size(260, 260),
            painter: _ScanFramePainter(scheme),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final ColorScheme scheme;

  _ScanFramePainter(this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    const len = 36.0;
    const radius = 28.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = scheme.primary;

    final path = Path()
      ..moveTo(0, len)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(len, 0);

    void corner(Offset c, double rotation) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rotation);
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    corner(Offset(0, 0), 0);
    corner(Offset(size.width, 0), 3.14159 / 2);
    corner(Offset(size.width, size.height), 3.14159);
    corner(Offset(0, size.height), -3.14159 / 2);
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) => false;
}
