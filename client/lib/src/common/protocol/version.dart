/* license: https://mit-license.org
 *
 *  Ming-Ke-Ming : Decentralized User Identity Authentication
 *
 *                                Written in 2023 by Moky <albert.moky@gmail.com>
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

///  enum MKMMetaVersion
///
///  abstract Defined for algorithm that generating address.
///
///  discussion Generate and check ID/Address
///
///      MKMMetaVersion_MKM give a seed string first, and sign this seed to get
///      fingerprint; after that, use the fingerprint to generate address.
///      This will get a firmly relationship between (username, address and key).
///
///      MKMMetaVersion_BTC use the key data to generate address directly.
///      This can build a BTC address for the entity ID (no username).
///
///      MKMMetaVersion_ExBTC use the key data to generate address directly, and
///      sign the seed to get fingerprint (just for binding username and key).
///      This can build a BTC address, and bind a username to the entity ID.
///
///  Bits:
///      0000 0001 - this meta contains seed as ID.name
///      0000 0010 - this meta generate BTC address
///      0000 0100 - this meta generate ETH address
///      ...
class MetaVersion {

  // ignore_for_file: constant_identifier_names
  static const int DEFAULT = (0x01);
  static const int MKM     = (0x01);  // 0000 0001

  static const int BTC     = (0x02);  // 0000 0010
  static const int ExBTC   = (0x03);  // 0000 0011

  static const int ETH     = (0x04);  // 0000 0100
  static const int ExETH   = (0x05);  // 0000 0101

  static String parseString(dynamic type) {
    if (type is String) {
      return type;
    } else if (type is MetaVersion) {
      return type.toString();
    } else if (type is int) {
      return type.toString();
    } else if (type is num) {
      return type.toString();
    } else {
      assert(type == null, 'meta type error: $type');
      return '';
    }
  }

  static bool hasSeed(dynamic type) {
    int version = parseInt(type, 0);
    return 0 < version && (version & MKM) == MKM;
  }

  static int parseInt(dynamic type, int defaultValue) {
    if (type == null) {
      return defaultValue;
    } else if (type is int) {
      // exactly
      return type;
    } else if (type is num) {
      return type.toInt();
    } else if (type is String) {
      // fixed values
      if (type == 'MKM' || type == 'mkm') {
        return MKM;
      } else if (type == 'BTC' || type == 'btc') {
        return BTC;
      } else if (type == 'ExBTC') {
        return ExBTC;
      } else if (type == 'ETH' || type == 'eth') {
        return ETH;
      } else if (type == 'ExETH') {
        return ExETH;
      }
      // TODO: other algorithms
    // } else if (type is MetaVersion) {
    //   // enum
    //   return type;
    } else {
      return -1;
    }
    try {
      return int.parse(type);
    } catch (e) {
      return -1;
    }
  }

}
