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
import 'package:dimsdk/dimsdk.dart';

import '../common/facebook.dart';
import '../common/messenger.dart';

import 'admin.dart';
import 'delegate.dart';
import 'emitter.dart';
import 'manager.dart';


class SharedGroupManager implements GroupDataSource {
  factory SharedGroupManager() => _instance;
  static final SharedGroupManager _instance = SharedGroupManager._internal();
  SharedGroupManager._internal();

  WeakReference<CommonFacebook>? _barrack;
  WeakReference<CommonMessenger>? _transceiver;

  CommonFacebook? get facebook => _barrack?.target;
  CommonMessenger? get messenger => _transceiver?.target;

  set facebook(CommonFacebook? delegate) {
    _barrack = delegate == null ? null : WeakReference(delegate);
    _clearDelegates();
  }
  set messenger(CommonMessenger? delegate) {
    _transceiver = delegate == null ? null : WeakReference(delegate);
    _clearDelegates();
  }

  //
  //  delegates
  //
  GroupDelegate? _delegate;
  GroupManager? _manager;
  AdminManager? _adminManager;
  GroupEmitter? _emitter;

  void _clearDelegates() {
    _delegate = null;
    _manager = null;
    _adminManager = null;
    _emitter = null;
  }

  GroupDelegate get delegate {
    GroupDelegate? target = _delegate;
    if (target == null) {
      _delegate = target = GroupDelegate(facebook!, messenger!);
    }
    return target;
  }
  GroupManager get manager {
    GroupManager? target = _manager;
    if (target == null) {
      _manager = target = GroupManager(delegate);
    }
    return target;
  }
  AdminManager get adminManager {
    AdminManager? target = _adminManager;
    if (target == null) {
      _adminManager = target = AdminManager(delegate);
    }
    return target;
  }
  GroupEmitter get emitter {
    GroupEmitter? target = _emitter;
    if (target == null) {
      _emitter = target = GroupEmitter(delegate);
    }
    return target;
  }

  Future<String> buildGroupName(List<ID> members) async =>
      await delegate.buildGroupName(members);

  //
  //  Entity DataSource
  //

  @override
  Future<Meta?> getMeta(ID group) async => await delegate.getMeta(group);

  @override
  Future<List<Document>> getDocuments(ID group) async =>
      await delegate.getDocuments(group);

  Future<Bulletin?> getBulletin(ID group) async => await delegate.getBulletin(group);

  //
  //  Group DataSource
  //

  @override
  Future<ID?> getFounder(ID group) async => await delegate.getFounder(group);

  @override
  Future<ID?> getOwner(ID group) async => await delegate.getOwner(group);

  @override
  Future<List<ID>> getAssistants(ID group) async =>
      await delegate.getAssistants(group);

  @override
  Future<List<ID>> getMembers(ID group) async => await delegate.getMembers(group);

  Future<List<ID>> getAdministrators(ID group) async =>
      await delegate.getAdministrators(group);

  Future<bool> isOwner(ID user, {required ID group}) async =>
      await delegate.isOwner(user, group: group);

  Future<bool> broadcastGroupDocument(Bulletin doc) async =>
      await adminManager.broadcastGroupDocument(doc);

  //
  //  Group Manage
  //

  /// Create new group with members
  Future<ID?> createGroup(List<ID> members) async =>
      await manager.createGroup(members);

  ///  Update 'administrators' in bulletin document
  ///
  /// @param newAdmins - new administrator ID list
  /// @return true on success
  Future<bool> updateAdministrators(List<ID> newAdmins, {required ID group}) async =>
      await adminManager.updateAdministrators(newAdmins, group: group);

  ///  Reset group members
  ///
  /// @param newMembers - new member ID list
  /// @return true on success
  Future<bool> resetGroupMembers(List<ID> newMembers, {required ID group}) async =>
      await manager.resetMembers(newMembers, group: group);

  ///  Expel members from this group
  ///
  /// @param expelMembers - members to be removed
  /// @return true on success
  Future<bool> expelGroupMembers(List<ID> expelMembers, {required ID group}) async {
    assert(group.isGroup && expelMembers.isNotEmpty, 'params error: $group, $expelMembers');

    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    List<ID> oldMembers = await delegate.getMembers(group);

    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);

    // check permission
    bool canReset = isOwner || isAdmin;
    if (canReset) {
      // You are the owner/admin, then
      // remove the members and 'reset' the group
      List<ID> members = [...oldMembers];
      for (ID item in expelMembers) {
        members.remove(item);
      }
      return await resetGroupMembers(members, group: group);
    }

    // not an admin/owner
    throw Exception('Cannot expel members from group: $group');
  }

  ///  Invite new members to this group
  ///
  /// @param newMembers - new member ID list to be added
  /// @return true on success
  Future<bool> inviteGroupMembers(List<ID> newMembers, {required ID group}) async =>
      await manager.inviteMembers(newMembers, group: group);

  ///  Quit from this group
  ///
  /// @return true on success
  Future<bool> quitGroup({required ID group}) async =>
      await manager.quitGroup(group: group);

  //
  //  Sending group message
  //

  ///  Send group message
  ///
  /// @param iMsg
  /// @param priority
  /// @return
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    assert(iMsg.content.group != null, 'group message error: $iMsg');
    iMsg['GF'] = true;  // group flag for notification
    return await emitter.sendInstantMessage(iMsg, priority: priority);
  }

}
