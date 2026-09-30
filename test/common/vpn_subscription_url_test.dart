import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:fl_clash/common/vpn_intake.dart';
import 'package:fl_clash/common/vpn_subscription_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  late RSAPublicKey publicKey;
  late RSAPrivateKey privateKey;
  late String encodedPrivateKey;

  String encrypt(String url) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final ciphertext = cipher.process(Uint8List.fromList(utf8.encode(url)));
    final payload = base64Url.encode(ciphertext).replaceAll('=', '');
    return '$encryptedVpnUrlPrefix$payload';
  }

  setUpAll(() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    publicKey = pair.publicKey as RSAPublicKey;
    privateKey = pair.privateKey as RSAPrivateKey;
    encodedPrivateKey = base64Encode(
      utf8.encode(CryptoUtils.encodeRSAPrivateKeyToPem(privateKey)),
    );
  });

  test('decrypts RSA-OAEP/SHA-256 links and leaves plain URLs intact', () {
    const url = 'https://example.test/sub?token=a%2Fb';
    final token = encrypt(url);
    expect((VpnUrlIntake.parse(token) as VpnUrlAccepted).url, token);
    expect(
      VpnSubscriptionUrl.resolve(token, privateKeyBase64: encodedPrivateKey),
      url,
    );
    expect(VpnSubscriptionUrl.resolve(url), url);
  });

  test('accepts PKCS#1 and PKCS#8 private PEM formats', () {
    final token = encrypt('https://example.test/sub');
    final pkcs1 = base64Encode(
      utf8.encode(CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey)),
    );
    expect(
      VpnSubscriptionUrl.resolve(token, privateKeyBase64: pkcs1),
      'https://example.test/sub',
    );
    expect(
      VpnSubscriptionUrl.resolve(token, privateKeyBase64: encodedPrivateKey),
      'https://example.test/sub',
    );
  });

  test('rejects missing and invalid build keys without revealing the link', () {
    final token = encrypt('https://example.test/private');
    expect(
      () => VpnSubscriptionUrl.resolve(token, privateKeyBase64: ''),
      throwsA(
        isA<VpnEncryptedUrlException>().having(
          (error) => error.reason,
          'reason',
          VpnEncryptedUrlError.missingKey,
        ),
      ),
    );
    expect(
      () => VpnSubscriptionUrl.resolve(token, privateKeyBase64: 'not-base64'),
      throwsA(
        isA<VpnEncryptedUrlException>().having(
          (error) => error.reason,
          'reason',
          VpnEncryptedUrlError.invalidKey,
        ),
      ),
    );
  });

  test('rejects damaged tokens and decrypted non-HTTP URLs', () {
    final badToken =
        '$encryptedVpnUrlPrefix${base64Url.encode(Uint8List(256)).replaceAll('=', '')}';
    for (final token in [badToken, encrypt('file:///private/config.yaml')]) {
      expect(
        () => VpnSubscriptionUrl.resolve(
          token,
          privateKeyBase64: encodedPrivateKey,
        ),
        throwsA(
          isA<VpnEncryptedUrlException>().having(
            (error) => error.reason,
            'reason',
            VpnEncryptedUrlError.invalidToken,
          ),
        ),
      );
    }
  });
}
