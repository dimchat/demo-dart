/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * ==============================================================================
 */
import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';
import 'package:dim_plugins/plain.dart';


/// SymmetricKey
/// ~~~~~~~~~~~~
/// This is for generating symmetric key with a text string
class Password {

  static const int _keySize = 32;
  // static const int _blockSize = 16;

  /// Generate AES key
  static SymmetricKey generate(String passphrase) {
    Uint8List data = UTF8.encode(passphrase);
    Uint8List digest = SHA256.digest(data);
    // AES key data
    int filling = _keySize - data.length;
    if (filling > 0) {
      // format: {digest_prefix}+{pwd_data}
      data = Uint8List.fromList(digest.sublist(0, filling) + data);
    } else if (filling < 0) {
      // throw Exception('password too long: $passphrase');
      if (_keySize == digest.length) {
        data = digest;
      } else {
        // FIXME: what about _keySize > digest.length?
        data = digest.sublist(0, _keySize);
      }
    }
    // Uint8List iv = digest.sublist(digest.length - _blockSize);
    Map key = {
      'algorithm': SymmetricAlgorithms.AES,
      'data': Base64.encode(data),
      // 'iv': Base64.encode(iv),
    };
    return SymmetricKey.parse(key)!;
  }

  //
  //  Key Digest
  //

  /// Get key digest
  static String digest(SymmetricKey password) {
    Uint8List key = password.data;      // 32 bytes
    Uint8List dig = MD5.digest(key);    // 16 bytes
    Uint8List pre = dig.sublist(0, 6);  //  6 bytes
    return Base64.encode(pre);          //  8 chars
  }

  /// Plain Key
  /// ~~~~~~~~~
  /// (no password)
  // ignore: constant_identifier_names
  static const String PLAIN = SymmetricAlgorithms.PLAIN;
  static final SymmetricKey kPlainKey = PlainKey.getInstance();

}
