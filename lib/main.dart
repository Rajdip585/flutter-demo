/// Flutter QR Code Scanner App for Event Check-in /// Features: /// - Fullscreen QR scanner /// - Local validation of security key /// - API request only after valid QR /// - Red/green border feedback /// - Vibrations & popup alerts

// Required packages in pubspec.yaml: //   qr_code_scanner: ^1.0.1 //   http: ^0.13.6 //   crypto: ^3.0.3 //   flutter_vibrate: ^1.3.0

// File: lib/main.dart import 'dart:convert'; import 'package:flutter/material.dart'; import 'package:qr_code_scanner/qr_code_scanner.dart'; import 'package:http/http.dart' as http; import 'package:crypto/crypto.dart'; import 'package:flutter_vibrate/flutter_vibrate.dart';

void main() => runApp(const MyApp());

const SECRET_PHRASE = "YourSecretPhraseHere";

class MyApp extends StatelessWidget { const MyApp({super.key});

@override Widget build(BuildContext context) { return const MaterialApp( home: QRCheckInPage(), debugShowCheckedModeBanner: false, ); } }

class QRCheckInPage extends StatefulWidget { const QRCheckInPage({super.key});

@override State<QRCheckInPage> createState() => _QRCheckInPageState(); }

class _QRCheckInPageState extends State<QRCheckInPage> { final GlobalKey qrKey = GlobalKey(debugLabel: 'QR'); QRViewController? controller; bool isProcessing = false; Color borderColor = Colors.transparent;

@override void dispose() { controller?.dispose(); super.dispose(); }

void _onQRViewCreated(QRViewController controller) { this.controller = controller; controller.scannedDataStream.listen((scanData) async { if (isProcessing) return; isProcessing = true; await _processQR(scanData.code); await Future.delayed(const Duration(seconds: 2)); isProcessing = false; }); }

Future<void> _processQR(String? raw) async { if (raw == null || !raw.contains('||')) return; final parts = raw.split('||'); if (parts.length != 2) return;

final id = parts[0];
final securityKey = parts[1];
final expected = sha256.convert(utf8.encode(id + base64.encode(utf8.encode(SECRET_PHRASE)))).toString();

if (expected != securityKey) {
  Vibrate.feedback(FeedbackType.error);
  setState(() => borderColor = Colors.red);
  _showAlert("Tempered QR Code", false);
  return;
}

// Validated → API call
try {
  final response = await http.post(
    Uri.parse("https://yourdomain.com/api/check-in"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"participation_id": id}),
  );

  final data = jsonDecode(response.body);
  final success = data['status_code'] == 200;
  setState(() => borderColor = success ? Colors.green : Colors.orange);
  if (success) Vibrate.feedback(FeedbackType.success);
  _showAlert(data['message'], success);
} catch (e) {
  setState(() => borderColor = Colors.red);
  _showAlert("API Error: $e", false);
}

}

void _showAlert(String message, bool success) { showDialog( context: context, builder: (ctx) => AlertDialog( backgroundColor: success ? Colors.green[50] : Colors.red[50], title: Text(success ? "Success" : "Warning"), content: Text(message), actions: [ TextButton( onPressed: () => Navigator.of(ctx).pop(), child: const Text("OK"), ) ], ), ); }

@override Widget build(BuildContext context) { return Scaffold( body: AnimatedContainer( duration: const Duration(milliseconds: 300), decoration: BoxDecoration( border: Border.all(color: borderColor, width: 8), ), child: QRView( key: qrKey, onQRViewCreated: _onQRViewCreated, overlay: QrScannerOverlayShape( borderWidth: 0, // full screen scanner borderColor: Colors.transparent, cutOutSize: MediaQuery.of(context).size.width * 0.9, ), ), ), ); } }

