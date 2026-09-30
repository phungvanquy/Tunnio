import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';

import 'vpn_intake.dart';

enum VpnEncryptedUrlError { missingKey, invalidKey, invalidToken }

class VpnEncryptedUrlException implements Exception {
  const VpnEncryptedUrlException(this.reason);

  final VpnEncryptedUrlError reason;
}

abstract final class VpnSubscriptionUrl {
  static String resolve(
    String savedUrl, {
    String privateKeyBase64 = const String.fromEnvironment(
      'VPN_RSA_PRIVATE_KEY_B64',
    ),
  }) {
    if (!savedUrl.startsWith(encryptedVpnUrlPrefix)) return savedUrl;
    if (privateKeyBase64.isEmpty) {
      throw const VpnEncryptedUrlException(VpnEncryptedUrlError.missingKey);
    }

    final RSAPrivateKey key;
    try {
      final pem = utf8.decode(base64Decode(privateKeyBase64));
      key = pem.startsWith('-----BEGIN RSA PRIVATE KEY-----')
          ? CryptoUtils.rsaPrivateKeyFromPemPkcs1(pem)
          : CryptoUtils.rsaPrivateKeyFromPem(pem);
      if (key.modulus == null || key.modulus!.bitLength < 2048) {
        throw const FormatException('RSA key is too small');
      }
    } catch (_) {
      throw const VpnEncryptedUrlException(VpnEncryptedUrlError.invalidKey);
    }

    try {
      final payload = savedUrl.substring(encryptedVpnUrlPrefix.length);
      if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(payload)) {
        throw const FormatException('Invalid encrypted link');
      }
      final ciphertext = Uint8List.fromList(
        base64Url.decode(base64Url.normalize(payload)),
      );
      if (ciphertext.length != (key.modulus!.bitLength + 7) ~/ 8) {
        throw const FormatException('Invalid ciphertext length');
      }
      final cipher = OAEPEncoding.withSHA256(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(key));
      final url = utf8.decode(cipher.process(ciphertext));
      final intake = VpnUrlIntake.parse(url);
      if (intake is! VpnUrlAccepted ||
          intake.url != url ||
          !const {'http', 'https'}.contains(Uri.parse(url).scheme)) {
        throw const FormatException('Invalid decrypted URL');
      }
      return url;
    } catch (_) {
      throw const VpnEncryptedUrlException(VpnEncryptedUrlError.invalidToken);
    }
  }
}
