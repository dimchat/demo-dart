/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
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
 * =============================================================================
 */
import 'package:dimp/dimp.dart';

import '../common/ans.dart';
import '../common/facebook.dart';
import '../common/protocol/helper.dart';
import '../common/register.dart';

///  Client Facebook with Address Name Service
abstract class ClientFacebook extends CommonFacebook {
  ClientFacebook(super.database);

  @override
  Future<User?> selectLocalUser(ID receiver) async {
    if (receiver.isUser) {
      return await super.selectLocalUser(receiver);
    }
    // group message (recipient not designated)
    assert(receiver.isGroup, 'receiver error: $receiver');
    // the messenger will check group info before decrypting message,
    // so we can trust that the group's meta & members MUST exist here.
    List<User> users = await archivist.localUsers;
    List<ID> members = await getMembers(receiver);
    assert(members.isNotEmpty, "members not found: $receiver");
    for (User item in users) {
      if (members.contains(item.identifier)) {
        // DISCUSS: set this item to be current user?
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    bool ok = await super.saveDocument(doc);
    if (ok && doc is Bulletin) {
      // check administrators
      Object? array = doc.getProperty('administrators');
      if (array is List) {
        ID group = doc.identifier;
        assert(group.isGroup, 'group ID error: $group');
        List<ID> admins = ID.convert(array);
        ok = await saveAdministrators(admins, group);
      }
    }
    return ok;
  }

  //
  //  Group Data Source
  //

  @override
  Future<ID?> getFounder(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // check broadcast group
    if (group.isBroadcast) {
      // founder of broadcast group
      return BroadcastHelper.getBroadcastFounder(group);
    }
    // check bulletin document
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      // the owner(founder) should be set in the bulletin document of group
      return null;
    }
    // check local storage
    ID? user = await database.getFounder(group: group);
    if (user != null) {
      // got from local storage
      return user;
    }
    // get from bulletin document
    user = doc.founder;
    assert(user != null, 'founder not designated for group: $group');
    return user;
  }

  @override
  Future<ID?> getOwner(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // check broadcast group
    if (group.isBroadcast) {
      // owner of broadcast group
      return BroadcastHelper.getBroadcastOwner(group);
    }
    // check bulletin document
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      // the owner(founder) should be set in the bulletin document of group
      return null;
    }
    // check local storage
    ID? user = await database.getOwner(group: group);
    if (user != null) {
      // got from local storage
      return user;
    }
    // check group type
    if (group.type == EntityType.GROUP) {
      // Polylogue owner is its founder
      user = await database.getFounder(group: group);
      user ??= doc.founder;
    }
    assert(user != null, 'owner not found for group: $group');
    return user;
  }

  @override
  Future<List<ID>> getMembers(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // check broadcast group
    if (group.isBroadcast) {
      // members of broadcast group
      return BroadcastHelper.getBroadcastMembers(group);
    }
    // check group owner
    ID? owner = await getOwner(group);
    if (owner == null) {
      // assert false : "group owner not found: " + group;
      return [];
    }
    // check local storage
    var members = await database.getMembers(group: group);
    /*await */checker.checkMembers(group, members);
    return members.isEmpty ? [owner] : members;
  }

  @override
  Future<List<ID>> getAssistants(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // check bulletin document
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      // the owner(founder) should be set in the bulletin document of group
      return [];
    }
    // check local storage
    var bots = await database.getAssistants(group: group);
    if (bots.isNotEmpty) {
      // got from local storage
      return bots;
    }
    // get from bulletin document
    return doc.assistants ?? [];
  }

  //
  //  Organizational Structure
  //

  @override
  Future<List<ID>> getAdministrators(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // check bulletin document
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      // the administrators should be set in the bulletin document
      return [];
    }
    // the 'administrators' should be saved into local storage
    // when the newest bulletin document received,
    // so we must get them from the local storage only,
    // not from the bulletin document.
    return await database.getAdministrators(group: group);
  }

  @override
  Future<bool> saveAdministrators(List<ID> admins, ID group) async =>
      await database.saveAdministrators(admins, group: group);

  @override
  Future<bool> saveMembers(List<ID> newMembers, ID group) async =>
      await database.saveMembers(newMembers, group: group);

  //
  //  Address Name Service
  //
  static AddressNameServer? ans;

  static void prepare() {
    if (_loaded) {
      return;
    }

    // load plugins
    Register.prepare();

    _identifierFactory = ID.getFactory();
    ID.setFactory(_IdentifierFactory());

    _loaded = true;
  }
  static bool _loaded = false;

}

IDFactory? _identifierFactory;

class _IdentifierFactory implements IDFactory {

  @override
  ID generateIdentifier(Meta meta, int? network, {String? terminal}) {
    return _identifierFactory!.generateIdentifier(meta, network, terminal: terminal);
  }

  @override
  ID createIdentifier({String? name, required Address address, String? terminal}) {
    return _identifierFactory!.createIdentifier(name: name, address: address, terminal: terminal);
  }

  @override
  ID? parseIdentifier(String identifier) {
    // try ANS record
    ID? id = ClientFacebook.ans?.identifier(identifier);
    if (id != null) {
      return id;
    }
    // parse by original factory
    return _identifierFactory?.parseIdentifier(identifier);
  }

}
