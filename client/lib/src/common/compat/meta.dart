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

import 'btc.dart';


///  Default Meta to build ID with 'name@address'
///
///  version:
///      0x01 - MKM
///
///  algorithm:
///      CT      = fingerprint = sKey.sign(seed);
///      hash    = ripemd160(sha256(CT));
///      code    = sha256(sha256(network + hash)).prefix(4);
///      address = base58_encode(network + hash + code);
class _DefaultMeta extends BaseMeta {
  _DefaultMeta(super.dict);

  _DefaultMeta.from(int version, VerifyKey key, String seed, TransportableData fingerprint)
      : super.from(version, key, seed:seed, fingerprint:fingerprint);

  // caches
  final Map<int, Address> _cachedAddresses = {};

  @override
  Address generateAddress(int? network) {
    assert(type == MetaType.kMKM, 'meta type error: $type');
    assert(network != null, 'address type should not be empty');
    // check caches
    Address? address = _cachedAddresses[network];
    if (address == null) {
      // generate and cache it
      address = CompatibleBTCAddress.generate(fingerprint!, network!);
      _cachedAddresses[network] = address;
    }
    return address;
  }
}


///  Meta to build BTC address for ID
///
///  version:
///      0x02 - BTC
///      0x03 - ExBTC
///
///  algorithm:
///      CT      = key.data;
///      hash    = ripemd160(sha256(CT));
///      code    = sha256(sha256(network + hash)).prefix(4);
///      address = base58_encode(network + hash + code);
class _BTCMeta extends BaseMeta {
  _BTCMeta(super.dict) : _cachedAddress = null;

  _BTCMeta.from(int version, VerifyKey key, {String? seed, TransportableData? fingerprint})
      : super.from(version, key, seed: seed, fingerprint: fingerprint) {
    _cachedAddress = null;
  }

  // cache
  Address? _cachedAddress;

  @override
  Address generateAddress(int? network) {
    assert(type == MetaType.kBTC || type == MetaType.kExBTC, 'meta type error: $type');
    // assert(network == NetworkID.kBTCMain, 'BTC address type error: $network');
    Address? address = _cachedAddress;
    if (address == null || address.type != network) {
      // if (type == MetaType.kBTC) {
      //   // TODO: compress public key?
      //   key['compressed'] = 1;
      // }
      Uint8List data = publicKey.data;
      // generate and cache it
      _cachedAddress = address = CompatibleBTCAddress.generate(data, network!);
    }
    return address;
  }
}


class _CompatibleMetaFactory implements MetaFactory {
  _CompatibleMetaFactory(this._version);

  final int _version;

  @override
  Meta createMeta(VerifyKey pKey, {String? seed, TransportableData? fingerprint}) {
    switch (_version) {
      case MetaType.kMKM:
      // MKM
        return _DefaultMeta.from(_version, pKey, seed!, fingerprint!);
      case MetaType.kBTC:
      // BTC
        return _BTCMeta.from(_version, pKey);
      case MetaType.kExBTC:
      // ExBTC
        return _BTCMeta.from(_version, pKey, seed: seed, fingerprint: fingerprint);
      case MetaType.kETH:
    }
    throw Exception('unknown meta type: $_version');
  }

  @override
  Meta generateMeta(SignKey sKey, {String? seed}) {
    TransportableData? fingerprint;
    if (seed == null) {
      fingerprint = null;
    } else {
      Uint8List sig = sKey.sign(UTF8.encode(seed));
      fingerprint = TransportableData.create(sig);
    }
    VerifyKey pKey = (sKey as PrivateKey).publicKey;
    return createMeta(pKey, seed: seed, fingerprint: fingerprint);
  }

  @override
  Meta? parseMeta(Map meta) {
    Meta out;
    AccountFactoryManager man = AccountFactoryManager();
    int? type = man.generalFactory.getMetaType(meta, 0);
    assert(type != null, 'failed to get meta type: $meta');
    if (type == MetaType.kMKM) {
      // MKM
      out = _DefaultMeta(meta);
    } else if (type == MetaType.kBTC || type == MetaType.kExBTC) {
      // BTC, ExBTC
      out = _BTCMeta(meta);
    } else {
      throw Exception('unknown meta type: $type');
    }
    return out.isValid ? out : null;
  }
}

void registerCompatibleMetaFactories() {
  Meta.setFactory(MetaType.kMKM,   _CompatibleMetaFactory(MetaType.kMKM));
  Meta.setFactory(MetaType.kBTC,   _CompatibleMetaFactory(MetaType.kBTC));
  Meta.setFactory(MetaType.kExBTC, _CompatibleMetaFactory(MetaType.kExBTC));
}
