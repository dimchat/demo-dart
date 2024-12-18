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
import 'package:dim_plugins/dim_plugins.dart';
import 'package:dimp/dimp.dart';

import 'network.dart';


class _EntityID extends Identifier {
  _EntityID(super.string, {super.name, required super.address, super.terminal});

  @override
  int get type {
    String? text = name;
    if (text == null || text.isEmpty) {
      // all ID without 'name' field must be a user
      // e.g.: BTC address
      return EntityType.USER;
    }
    // compatible with MKM 0.9.*
    return NetworkID.getType(address.type);
  }

}

class _EntityIDFactory extends IdentifierFactory {

  @override // protected
  ID newID(String identifier, {String? name, required Address address, String? terminal}) {
    /// override for customized ID
    return _EntityID(identifier, name: name, address: address, terminal: terminal);
  }

  @override
  ID? parse(String identifier) {
    // check broadcast IDs
    int len = identifier.length;
    if (len == 0) {
      assert(false, 'ID empty');
      return null;
    } else if (len == 15) {
      // "anyone@anywhere"
      String lower = identifier.toLowerCase();
      if (ID.ANYONE.toString() == lower) {
        return ID.ANYONE;
      }
    } else if (len == 19) {
      // "everyone@everywhere"
      // "stations@everywhere"
      String lower = identifier.toLowerCase();
      if (ID.EVERYONE.toString() == lower) {
        return ID.EVERYONE;
      }
    } else if (len == 13) {
      // "moky@anywhere"
      String lower = identifier.toLowerCase();
      if (ID.FOUNDER.toString() == lower) {
        return ID.FOUNDER;
      }
    }
    return super.parse(identifier);
  }

}


void registerEntityIDFactory() {
  ID.setFactory(_EntityIDFactory());
}
