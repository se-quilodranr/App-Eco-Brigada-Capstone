import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Comparte un enlace lógico a un punto del mapa. No es verificación de asistencia.
class CodigoQrPuntoPage extends StatelessWidget {
  final String puntoId;
  final String nombre;
  const CodigoQrPuntoPage({super.key, required this.puntoId, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código QR del punto')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(nombre, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              QrImageView(
                data: 'ecobrigada:punto:$puntoId',
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text('Escanéalo desde EcoBrigada para abrir este punto.'),
            ],
          ),
        ),
      ),
    );
  }
}

class EscanearPuntoPage extends StatefulWidget {
  const EscanearPuntoPage({super.key});
  @override
  State<EscanearPuntoPage> createState() => _EscanearPuntoPageState();
}

class _EscanearPuntoPageState extends State<EscanearPuntoPage> {
  bool _resuelto = false;
  late final MobileScannerController _camera;

  @override
  void initState() {
    super.initState();
    _camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _leer(BarcodeCapture capture) {
    if (_resuelto) return;
    for (final item in capture.barcodes) {
      final raw = item.rawValue ?? '';
      const prefix = 'ecobrigada:punto:';
      if (raw.startsWith(prefix) && raw.length > prefix.length) {
        final id = raw.substring(prefix.length);
        if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id)) continue;
        _resuelto = true;
        Navigator.of(context).pop(id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Escanear QR EcoBrigada')),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Apunta la cámara a un código de punto EcoBrigada.'),
            ),
            Expanded(child: MobileScanner(controller: _camera, onDetect: _leer)),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('El QR comparte un punto; no acredita asistencia a una jornada.'),
            ),
          ],
        ),
      );
}
