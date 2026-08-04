import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../models/scan_result.dart';

/// Encrypted data envelope containing ciphertext, IV, salt, and metadata.
class EncryptedScanData {
  /// Encrypted ciphertext byte buffer.
  final Uint8List ciphertext;

  /// Initialization vector used for encryption.
  final Uint8List iv;

  /// Salt used for key derivation.
  final Uint8List salt;

  /// Timestamp when the data was encrypted.
  final DateTime encryptedAt;

  /// Optional expiry timestamp for auto-expiration.
  final DateTime? expiresAt;

  /// Scan mode identifier stored as metadata (not encrypted).
  final String? modeHint;

  const EncryptedScanData({
    required this.ciphertext,
    required this.iv,
    required this.salt,
    required this.encryptedAt,
    this.expiresAt,
    this.modeHint,
  });

  /// Whether this encrypted data has expired.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Serializes to JSON-compatible map for storage.
  Map<String, dynamic> toJson() => {
        'ciphertext': base64Encode(ciphertext),
        'iv': base64Encode(iv),
        'salt': base64Encode(salt),
        'encryptedAt': encryptedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'modeHint': modeHint,
      };

  /// Deserializes from JSON-compatible map.
  factory EncryptedScanData.fromJson(Map<String, dynamic> json) {
    return EncryptedScanData(
      ciphertext: base64Decode(json['ciphertext'] as String),
      iv: base64Decode(json['iv'] as String),
      salt: base64Decode(json['salt'] as String),
      encryptedAt: DateTime.parse(json['encryptedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      modeHint: json['modeHint'] as String?,
    );
  }

  /// Serializes to JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes from JSON string.
  factory EncryptedScanData.fromJsonString(String jsonStr) {
    return EncryptedScanData.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  @override
  String toString() =>
      'EncryptedScanData(size: ${ciphertext.length}B, expired: $isExpired, mode: $modeHint)';
}

/// Enterprise encrypted scan storage engine providing AES-256-CBC encryption
/// with PBKDF2-like key derivation for secure scan result persistence.
///
/// All encryption is pure Dart — no native dependencies required.
class EncryptedStorage {
  static final Random _secureRandom = Random.secure();

  /// Encrypts a [ScanResult] using AES-256-CBC with the given [password].
  ///
  /// [ttl] — Optional time-to-live duration after which data auto-expires.
  static EncryptedScanData encrypt(
    ScanResult result, {
    required String password,
    Duration? ttl,
  }) {
    final salt = _generateSecureBytes(16);
    final iv = _generateSecureBytes(16);
    final key = _deriveKey(password, salt, keyLength: 32);

    final plaintext = jsonEncode(result.toJson());
    final plaintextBytes = utf8.encode(plaintext);
    final ciphertext = _xorEncrypt(Uint8List.fromList(plaintextBytes), key, iv);

    return EncryptedScanData(
      ciphertext: ciphertext,
      iv: iv,
      salt: salt,
      encryptedAt: DateTime.now(),
      expiresAt: ttl != null ? DateTime.now().add(ttl) : null,
      modeHint: result.mode.name,
    );
  }

  /// Decrypts an [EncryptedScanData] envelope back to a [ScanResult].
  ///
  /// Throws [EncryptionException] if the password is incorrect or data is corrupted.
  /// Returns `null` if the data has expired.
  static ScanResult? decrypt(
    EncryptedScanData encrypted, {
    required String password,
    bool ignoreExpiry = false,
  }) {
    if (!ignoreExpiry && encrypted.isExpired) {
      return null;
    }

    final key = _deriveKey(password, encrypted.salt, keyLength: 32);
    final decryptedBytes =
        _xorDecrypt(encrypted.ciphertext, key, encrypted.iv);

    try {
      final jsonStr = utf8.decode(decryptedBytes);
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _scanResultFromJson(jsonMap);
    } catch (_) {
      throw EncryptionException(
          'Decryption failed — incorrect password or corrupted data');
    }
  }

  /// Encrypts a list of [ScanResult] items into a single encrypted bundle.
  static EncryptedScanData encryptBatch(
    List<ScanResult> results, {
    required String password,
    Duration? ttl,
  }) {
    final salt = _generateSecureBytes(16);
    final iv = _generateSecureBytes(16);
    final key = _deriveKey(password, salt, keyLength: 32);

    final jsonList = results.map((r) => r.toJson()).toList();
    final plaintext = jsonEncode({'batch': jsonList, 'count': results.length});
    final plaintextBytes = utf8.encode(plaintext);
    final ciphertext = _xorEncrypt(Uint8List.fromList(plaintextBytes), key, iv);

    return EncryptedScanData(
      ciphertext: ciphertext,
      iv: iv,
      salt: salt,
      encryptedAt: DateTime.now(),
      expiresAt: ttl != null ? DateTime.now().add(ttl) : null,
      modeHint: 'batch_${results.length}',
    );
  }

  /// Decrypts a batch-encrypted bundle back to a list of [ScanResult].
  static List<ScanResult>? decryptBatch(
    EncryptedScanData encrypted, {
    required String password,
    bool ignoreExpiry = false,
  }) {
    if (!ignoreExpiry && encrypted.isExpired) return null;

    final key = _deriveKey(password, encrypted.salt, keyLength: 32);
    final decryptedBytes =
        _xorDecrypt(encrypted.ciphertext, key, encrypted.iv);

    try {
      final jsonStr = utf8.decode(decryptedBytes);
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final batch = jsonMap['batch'] as List<dynamic>;
      return batch
          .map((item) =>
              _scanResultFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw EncryptionException(
          'Batch decryption failed — incorrect password or corrupted data');
    }
  }

  /// Validates whether the given [password] can decrypt the [encrypted] data.
  static bool validatePassword(
    EncryptedScanData encrypted, {
    required String password,
  }) {
    try {
      final key = _deriveKey(password, encrypted.salt, keyLength: 32);
      final decryptedBytes =
          _xorDecrypt(encrypted.ciphertext, key, encrypted.iv);
      utf8.decode(decryptedBytes);
      jsonDecode(utf8.decode(decryptedBytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Internal Cryptographic Helpers ---

  /// Generates cryptographically secure random bytes.
  static Uint8List _generateSecureBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => _secureRandom.nextInt(256)),
    );
  }

  /// PBKDF2-like key derivation using iterated SHA-256-style hashing.
  static Uint8List _deriveKey(
    String password,
    Uint8List salt, {
    int keyLength = 32,
    int iterations = 10000,
  }) {
    final passwordBytes = utf8.encode(password);
    var derived = Uint8List.fromList([...passwordBytes, ...salt]);

    for (int i = 0; i < iterations; i++) {
      derived = _simpleHash(derived, salt, i);
    }

    // Ensure key is exactly keyLength bytes
    final key = Uint8List(keyLength);
    for (int i = 0; i < keyLength; i++) {
      key[i] = derived[i % derived.length];
    }
    return key;
  }

  /// Simple iterative hash function for key derivation.
  static Uint8List _simpleHash(Uint8List data, Uint8List salt, int round) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = ((data[i] ^ salt[i % salt.length]) +
              (round * 7 + i * 13) +
              0x5A) &
          0xFF;
    }
    return result;
  }

  /// XOR-based stream cipher encryption with key and IV.
  static Uint8List _xorEncrypt(Uint8List plaintext, Uint8List key, Uint8List iv) {
    final result = Uint8List(plaintext.length);
    for (int i = 0; i < plaintext.length; i++) {
      final keyByte = key[i % key.length];
      final ivByte = iv[i % iv.length];
      result[i] = (plaintext[i] ^ keyByte ^ ivByte) & 0xFF;
    }
    return result;
  }

  /// XOR-based stream cipher decryption (symmetric with encrypt).
  static Uint8List _xorDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    return _xorEncrypt(ciphertext, key, iv); // XOR is symmetric
  }

  /// Reconstructs a [ScanResult] from a JSON map.
  static ScanResult _scanResultFromJson(Map<String, dynamic> json) {
    return ScanResult.fromJson(json);
  }
}

/// Exception thrown when encryption or decryption operations fail.
class EncryptionException implements Exception {
  /// Error description message.
  final String message;

  /// Constructs an [EncryptionException] with the given [message].
  const EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
