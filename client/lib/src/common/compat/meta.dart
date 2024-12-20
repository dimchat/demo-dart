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
import 'dart:typed_data';

import 'package:dimp/dimp.dart';
import 'package:dim_plugins/dim_plugins.dart';


///  Default Meta to build ID with 'name@address'
///
///  version:
///      1 = MKM
///
///  algorithm:
///      CT      = fingerprint = sKey.sign(seed);
///      hash    = ripemd160(sha256(CT));
///      code    = sha256(sha256(network + hash)).prefix(4);
///      address = base58_encode(network + hash + code);
class _DefaultMeta extends BaseMeta {
  _DefaultMeta(super.dict);

  _DefaultMeta.from(String type, VerifyKey key, String seed, TransportableData fingerprint)
      : super.from(type, key, seed: seed, fingerprint: fingerprint);

  @override
  bool get hasSeed => true;

  // caches
  final Map<int, Address> _cachedAddresses = {};

  @override
  Address generateAddress(int? network) {
    // assert(type == Meta.MKM || type == '1', 'meta type error: $type');
    assert(network != null, 'address type should not be empty');
    // check caches
    Address? cached = _cachedAddresses[network];
    if (cached == null) {
      // generate and cache it
      var data = fingerprint;
      assert(data != null && data.isNotEmpty, 'meta.fingerprint empty');
      cached = BTCAddress.generate(data!, network!);
      _cachedAddresses[network] = cached;
    }
    return cached;
  }

}


///  Meta to build BTC address for ID
///
///  version:
///      2 = BTC
///
///  algorithm:
///      CT      = key.data;
///      hash    = ripemd160(sha256(CT));
///      code    = sha256(sha256(network + hash)).prefix(4);
///      address = base58_encode(network + hash + code);
class _BTCMeta extends BaseMeta {
  _BTCMeta(super.dict);

  _BTCMeta.from(String type, VerifyKey key, {String? seed, TransportableData? fingerprint})
      : super.from(type, key, seed: seed, fingerprint: fingerprint);

  @override
  bool get hasSeed => true;

  // caches
  final Map<int, Address> _cachedAddresses = {};

  @override
  Address generateAddress(int? network) {
    // assert(type == Meta.BTC || type == '2', 'meta type error: $type');
    assert(network != null, 'address type should not be empty');
    // check caches
    Address? cached = _cachedAddresses[network];
    if (cached == null) {
      // TODO: compress public key?
      VerifyKey key = publicKey;
      Uint8List data = key.data;
      // generate and cache it
      cached = BTCAddress.generate(data, network!);
      _cachedAddresses[network] = cached;
    }
    return cached;
  }
}


///  Meta to build ETH address for ID
///
///  version:
///      4 = ETH
///
///  algorithm:
///      CT      = key.data;  // without prefix byte
///      digest  = keccak256(CT);
///      address = hex_encode(digest.suffix(20));
class _ETHMeta extends BaseMeta {
  _ETHMeta(super.dict);

  _ETHMeta.from(String type, VerifyKey key, {String? seed, TransportableData? fingerprint})
      : super.from(type, key, seed: seed, fingerprint: fingerprint);

  @override
  bool get hasSeed => true;

  // cache
  Address? _cachedAddress;

  @override
  Address generateAddress(int? network) {
    assert(type == Meta.ETH || type == '4', 'meta type error: $type');
    assert(network == null || network == EntityType.USER, 'address type error: $network');
    // check cache
    Address? cached = _cachedAddress;
    if (cached == null/* || cached.type != network*/) {
      // 64 bytes key data without prefix 0x04
      VerifyKey key = publicKey;
      Uint8List data = key.data;
      // generate and cache it
      cached = ETHAddress.generate(data);
      _cachedAddress = cached;
    }
    return cached;
  }
}


class _CompatibleMetaFactory extends GeneralMetaFactory {
  _CompatibleMetaFactory(super.version);

  @override
  Meta createMeta(VerifyKey pKey, {String? seed, TransportableData? fingerprint}) {
    Meta out;
    switch (type) {

      case Meta.MKM:
        out = _DefaultMeta.from('1', pKey, seed!, fingerprint!);
        break;

      case Meta.BTC:
        out = _BTCMeta.from('2', pKey);
        break;

      case Meta.ETH:
        out = _ETHMeta.from('4', pKey);
        break;

      default:
        throw Exception('unknown meta type: $type');
    }
    assert(out.isValid, 'meta error: $out');
    return out;
  }

  @override
  Meta? parseMeta(Map meta) {
    Meta out;
    AccountFactoryManager man = AccountFactoryManager();
    String? version = man.generalFactory.getMetaType(meta, '');
    switch (version) {

      case 'MKM':
      case 'mkm':
      case '1':
        out = _DefaultMeta(meta);
        break;

      case 'BTC':
      case 'btc':
      case '2':
        out = _BTCMeta(meta);
        break;

      case 'ETH':
      case 'eth':
      case '4':
        out = _ETHMeta(meta);
        break;

      default:
        throw Exception('unknown meta type: $type');
    }
    return out.isValid ? out : null;
  }
}


void registerCompatibleMetaFactories() {
  var mkm = _CompatibleMetaFactory(Meta.MKM);
  var btc = _CompatibleMetaFactory(Meta.BTC);
  var eth = _CompatibleMetaFactory(Meta.ETH);

  Meta.setFactory('1', mkm);
  Meta.setFactory('2', btc);
  Meta.setFactory('4', eth);

  Meta.setFactory('mkm', mkm);
  Meta.setFactory('btc', btc);
  Meta.setFactory('eth', eth);

  Meta.setFactory('MKM', mkm);
  Meta.setFactory('BTC', btc);
  Meta.setFactory('ETH', eth);
}
