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
import 'package:lnc/lnc.dart';
import 'package:object_key/object_key.dart';

import '../common/facebook.dart';
import '../common/messenger.dart';
import '../client/messenger.dart';

import 'delegate.dart';
import 'packer.dart';

abstract class GroupEmitter {

  // NOTICE: group assistants (bots) can help the members to redirect messages
  //
  //      if members.length < POLYLOGUE_LIMIT,
  //          means it is a small polylogue group, let the members to split
  //          and send group messages by themself, this can keep the group
  //          more secretive because no one else can know the group ID even;
  //      else,
  //          set 'assistants' in the bulletin document to tell all members
  //          that they can let the group bot to do the job for them.
  //
  static int kPolylogueLimit = 32;

  // NOTICE: expose group ID to reduce encrypting time
  //
  //      if members.length < SECRET_GROUP_LIMIT,
  //          means it is a tiny group, you can choose to hide the group ID,
  //          that you can split and encrypt message one by one;
  //      else,
  //          you should expose group ID in the instant message level, then
  //          encrypt message by one symmetric key for this group, after that,
  //          split and send to all members directly.
  static int kSecretGroupLimit = 16;

  GroupEmitter(this.delegate);

  // protected
  final GroupDelegate delegate;
  // protected
  late final GroupPacker packer = createPacker();

  /// override for customized packer
  GroupPacker createPacker() => GroupPacker(delegate);

  // protected
  Future<EncryptKey> getEncryptKey({required ID sender, required ID receiver}) async {
    ClientMessenger? messenger = delegate.messenger as ClientMessenger?;
    EncryptKey? key = await messenger?.getCipherKey(
      sender: sender, receiver: receiver, generate: true,
    );
    return key!;
  }

  /// Send group message content
  Future<Pair<InstantMessage?, ReliableMessage?>> sendContent(Content content, {int priority = 0}) async {
    CommonFacebook? facebook = delegate.facebook;
    assert(facebook != null, 'facebook messenger not ready');

    // get 'sender' => 'group'
    ID? group = content.group;
    if (group == null) {
      assert(false, 'not a group message: $content');
      return Pair(null, null);
    }
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return Pair(null, null);
    }
    ID sender = user.identifier;

    // pack and send
    Envelope envelope = Envelope.create(sender: sender, receiver: group);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    ReliableMessage? rMsg = await sendMessage(iMsg, priority: priority);
    return Pair(iMsg, rMsg);
  }

  Future<ReliableMessage?> sendMessage(InstantMessage iMsg, {int priority = 0}) async {
    Content content = iMsg.content;
    ID? group = content.group;
    if (group == null) {
      assert(false, 'not a group message: $iMsg');
      return null;
    }

    //
    //  0. check file message
    //
    if (content is FileContent) {
      // call emitter to encrypt & upload file data before send out
      EncryptKey password = await getEncryptKey(sender: iMsg.sender, receiver: group);
      bool ok = await uploadFileData(content, password, iMsg);
      assert(ok, 'failed to upload file data: $content');
    }

    //
    //  1. check group bots
    //
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // group bots found, forward this message to any bot to let it split for me;
      // this can reduce my jobs.
      ID prime = bots.first;
      return await _forwardMessage(iMsg, prime, group: group, priority: priority);
    }

    //
    //  2. check group members
    //
    List<ID> members = await delegate.getMembers(group);
    if (members.isEmpty) {
      assert(false, 'failed to get members for group: $group');
      return null;
    }
    // no 'assistants' found in group's bulletin document?
    // split group messages and send to all members one by one
    if (members.length < kSecretGroupLimit) {
      // it is a tiny group, split this message before encrypting and signing,
      // then send this group message to all members one by one
      int success = await _splitAndSendMessage(iMsg, members, group: group, priority: priority);
      Log.info('split $success message(s) for group: $group');
      return null;
    } else {
      // encrypt and sign this message first,
      // then split and send to all members one by one
      return await _disperseMessage(iMsg, members, group: group, priority: priority);
    }
  }

  /// Send file data encrypted with password
  /// (store download URL & decrypt key into file content after uploaded)
  ///
  /// @param content  - file content
  /// @param password - symmetric key to encrypt/decrypt file data
  /// @param iMsg     - outgoing message
  // protected
  Future<bool> uploadFileData(FileContent content, EncryptKey password, InstantMessage iMsg);

  /// Encrypt & sign message, then forward to the bot
  Future<ReliableMessage?> _forwardMessage(InstantMessage iMsg, ID bot, {required ID group, int priority = 0}) async {
    assert(bot.isUser && group.isGroup, 'ID error: $bot, $group');
    // NOTICE: because group assistant (bot) cannot be a member of the group, so
    //         if you want to send a group command to any assistant, you must
    //         set the bot ID as 'receiver' and set the group ID in content;
    //         this means you must send it to the bot directly.
    CommonMessenger? messenger = delegate.messenger;

    // group bots designated, let group bot to split the message, so
    // here must expose the group ID; this will cause the client to
    // use a "user-to-group" encrypt key to encrypt the message content,
    // this key will be encrypted by each member's public key, so
    // all members will received a message split by the group bot,
    // but the group bots cannot decrypt it.
    iMsg.setString('group', group);

    // the group bot can only get the message 'signature',
    // but cannot know the 'sn' because it cannot decrypt the content,
    // this is usually not a problem;
    // but sometimes we want to respond a receipt with original sn,
    // so I suggest to expose 'sn' too.
    int sn = iMsg.content.sn;
    iMsg['sn'] = sn;

    // pack message
    ReliableMessage? rMsg = await packer.encryptAndSignMessage(iMsg);
    if (rMsg == null) {
      assert(false, 'failed to encrypt & sign message: ${iMsg.sender} => $group');
      return null;
    }

    // forward the group message to any bot
    Content content = ForwardContent.create(forward: rMsg);
    var pair = await messenger?.sendContent(content, sender: null, receiver: bot, priority: priority);
    if (pair == null || pair.second == null) {
      assert(false, 'failed to forward message for group: $group, bot: $bot');
    }

    // OK, return the forwarding message
    return rMsg;
  }

  /// Encrypt & sign message, then disperse to all members
  Future<ReliableMessage?> _disperseMessage(InstantMessage iMsg, List<ID> members, {required ID group, int priority = 0}) async {
    assert(group.isGroup, 'group ID error: $group');
    // assert(!iMsg.containsKey('group'), 'should not happen');
    CommonMessenger? messenger = delegate.messenger;

    // NOTICE: there are too many members in this group
    //         if we still hide the group ID, the cost will be very high.
    //  so,
    //      here I suggest to expose 'group' on this message's envelope
    //      to use a user-to-group password to encrypt the message content,
    //      and the actual receiver can get the decrypt key
    //      with the accurate direction: (sender -> group)
    iMsg.setString('group', group);

    ID sender = iMsg.sender;

    // pack message
    ReliableMessage? rMsg = await packer.encryptAndSignMessage(iMsg);
    if (rMsg == null) {
      assert(false, 'failed to encrypt & sign message: $sender => $group');
      return null;
    }

    // split messages
    List<ReliableMessage> messages = await packer.splitReliableMessage(rMsg, members);
    ID receiver;
    bool? ok;
    for (ReliableMessage msg in messages) {
      receiver = msg.receiver;
      if (sender == receiver) {
        assert(false, 'cycled message: $sender => $receiver, $group');
        continue;
      }
      ok = await messenger?.sendReliableMessage(rMsg, priority: priority);
      assert(ok == true, 'failed to send message: $sender => $receiver, $group');
    }

    return rMsg;
  }

  /// Split and send (encrypt + sign) group messages to all members one by one
  Future<int> _splitAndSendMessage(InstantMessage iMsg, List<ID> members, {required ID group, int priority = 0}) async {
    assert(group.isGroup, 'group ID error: $group');
    assert(!iMsg.containsKey('group'), 'should not happen');
    CommonMessenger? messenger = delegate.messenger;

    // NOTICE: this is a tiny group
    //         I suggest NOT to expose the group ID to maximize its privacy,
    //         the cost is we cannot use a user-to-group password here;
    //         So the other members can only treat it as a personal message
    //         and use the user-to-user symmetric key to decrypt content,
    //         they can get the group ID after decrypted.

    ID sender = iMsg.sender;
    int success = 0;

    // split messages
    List<InstantMessage> messages = await packer.splitInstantMessage(iMsg, members);
    ID receiver;
    ReliableMessage? rMsg;
    for (InstantMessage msg in messages) {
      receiver = msg.receiver;
      if (sender == receiver) {
        assert(false, 'cycled message: $sender => $receiver, $group');
        continue;
      }
      // send message
      rMsg = await messenger?.sendInstantMessage(msg, priority: priority);
      if (rMsg == null) {
        Log.error('failed to send message: $sender => $receiver, $group');
        continue;
      }
      success += 1;
    }

    // done!
    return success;
  }

}
