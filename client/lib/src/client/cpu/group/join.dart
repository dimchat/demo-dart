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
import 'package:object_key/object_key.dart';

import '../group.dart';

///  Join Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. stranger can join a group
///      2. only group owner or administrator can review this command
class JoinCommandProcessor extends GroupCommandProcessor {
  JoinCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is JoinCommand, 'join command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    Pair<ID?, List<Content>?> grpPair = await checkCommandExpired(command, rMsg);
    ID? group = grpPair.first;
    if (group == null) {
      // ignore expired command
      return grpPair.second ?? [];
    }

    // 1. check group
    Triplet<ID?, List<ID>, List<Content>?> trip = await checkGroupMembers(command, rMsg);
    ID? owner = trip.first;
    List<ID> members = trip.second;
    if (owner == null || members.isEmpty) {
      return trip.third ?? [];
    }
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return [];
    }
    ID me = user.identifier;

    ID sender = rMsg.sender;
    List<ID> admins = await getAdministrators(group);
    bool isOwner = owner == sender;
    bool isAdmin = admins.contains(sender);
    bool isMember = members.contains(sender);
    bool canReset = isOwner || isAdmin;

    // 2. check membership
    if (!isMember) {
      bool iCanReset = owner == me || admins.contains(me);
      if (iCanReset && await attachApplication(command, rMsg)) {
        // add 'join' application for waiting review
      } else {
        assert(false, 'failed to add "join" application for group: $group');
      }
    } else if (canReset || owner != me) {
      // maybe the command sender is already become a member,
      // but if it can still receive a 'join' command here,
      // and I am the owner, here we should respond the sender
      // with the newest membership again.
    } else if (await sendResetCommand(group: group, members: members, receiver: sender)) {
      // the sender is an ordinary member, and I am the owner, so
      // send a 'reset' command to update members in the sender's memory
    } else {
      assert(false, 'failed to send "reset" command for group: $group => $sender');
    }

    // no need to response this group command
    return [];
  }

}
