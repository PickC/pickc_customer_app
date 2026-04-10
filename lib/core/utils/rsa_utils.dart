import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';

/// RSA encryption utility — matches Android RSAUtility.java exactly.
/// Algorithm: RSA/ECB/PKCS1Padding
/// Input:  Base64-encoded X.509 public key from server
/// Output: Base64-encoded ciphertext
class RsaUtils {
  static String? encrypt(String plainText, String base64PublicKey) {
    try {
      final keyBytes = base64.decode(base64PublicKey.replaceAll('\n', ''));

      final asn1Parser = ASN1Parser(keyBytes);
      final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
      final publicKeyBitString = topLevelSeq.elements![1] as ASN1BitString;

      final publicKeyAsn = ASN1Parser(publicKeyBitString.stringValues as Uint8List);
      final publicKeySeq = publicKeyAsn.nextObject() as ASN1Sequence;

      final modulus = (publicKeySeq.elements![0] as ASN1Integer).integer!;
      final exponent = (publicKeySeq.elements![1] as ASN1Integer).integer!;

      final rsaPublicKey = RSAPublicKey(modulus, exponent);

      final cipher = PKCS1Encoding(RSAEngine());
      cipher.init(true, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));

      final input = Uint8List.fromList(plainText.codeUnits);
      final encrypted = cipher.process(input);
      return base64.encode(encrypted);
    } catch (e) {
      return null;
    }
  }
}
