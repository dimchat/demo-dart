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
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/lnc.dart';

import '../common/facebook.dart';
import '../common/messenger.dart';

import 'delegate.dart';

class AdminManager {
  AdminManager(this.delegate);

  // protected
  final GroupDelegate delegate;

  ///  Update 'administrators' in bulletin document
  ///  (broadcast new document to all members and neighbor station)
  ///
  /// @param group     - group ID
  /// @param newAdmins - administrator list
  /// @return false on error
  Future<bool> updateAdministrators(ID group, List<ID> newAdmins) async {
    assert(group.isGroup, 'group ID error: $group');
    CommonFacebook? facebook = delegate.facebook;
    assert(facebook != null, 'facebook not ready');

    //
    //  0. get current user
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    SignKey? sKey = await facebook?.getPrivateKeyForVisaSignature(me);
    assert(sKey != null, 'failed to get sign key for current user: $me');

    //
    //  1. check permission
    //
    bool isOwner = await delegate.isOwner(me, group: group);
    if (!isOwner) {
      assert(false, 'cannot update administrators for group: $group, $me');
      return false;
    }

    //
    //  2. update document
    //
    Document? doc = await delegate.getDocument(group, '*');
    if (doc == null) {
      // TODO: create new one?
      assert(false, 'failed to get group document: $group, owner: $me');
      return false;
    }
    doc.setProperty('administrators', ID.revert(newAdmins));
    var signature = sKey == null ? null : doc.sign(sKey);
    if (signature == null) {
      assert(false, 'failed to sign document for group: $group, owner: $me');
      return false;
    } else if (!await delegate.saveDocument(doc)) {
      assert(false, 'failed to save document for group: $group');
      return false;
    } else {
      Log.info('group document updated: $group');
    }

    //
    //  3. broadcast bulletin document
    //
    return broadcastDocument(doc as Bulletin);
  }

  /// Broadcast group document
  // protected
  Future<bool> broadcastDocument(Bulletin doc) async {
    CommonFacebook? facebook = delegate.facebook;
    CommonMessenger? messenger = delegate.messenger;
    assert(facebook != null && messenger != null, 'facebook messenger not ready: $facebook, $messenger');

    //
    //  0. get current user
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    //
    //  1. create 'document' command, and send to current station
    //
    ID group = doc.identifier;
    Meta? meta = await facebook?.getMeta(group);
    Command content = DocumentCommand.response(group, meta, doc);
    messenger?.sendContent(content, sender: me, receiver: Station.kAny, priority: 1);

    //
    //  2. check group bots
    //
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // group bots exist, let them to deliver to all other members
      for (ID item in bots) {
        if (me == item) {
          assert(false, 'should not be a bot here: $me');
          continue;
        }
        messenger?.sendContent(content, sender: me, receiver: item, priority: 1);
      }
      return true;
    }

    //
    //  3. broadcast to all members
    //
    List<ID> members = await delegate.getMembers(group);
    if (members.isEmpty) {
      assert(false, 'failed to get group members: $group');
      return false;
    }
    for (ID item in members) {
      if (me == item) {
        Log.info('skip cycled message: $item, $group');
        continue;
      }
      messenger?.sendContent(content, sender: me, receiver: item, priority: 1);
    }
    return true;
  }

}
