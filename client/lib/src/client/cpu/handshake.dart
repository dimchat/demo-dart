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
import '../../dim_common.dart';

import '../messenger.dart';
import '../network/session.dart';

class HandshakeCommandProcessor extends BaseCommandProcessor {
  HandshakeCommandProcessor(super.facebook, super.messenger);

  @override
  ClientMessenger get messenger => super.messenger as ClientMessenger;

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is HandshakeCommand, 'handshake command error: $content');
    HandshakeCommand command = content as HandshakeCommand;
    ClientSession session = messenger.session;
    // update station's default ID ('station@anywhere') to sender (real ID)
    Station station = session.station;
    ID oid = station.identifier;
    ID sender = rMsg.sender;
    if (oid.isBroadcast) {
      station.identifier = sender;
    } else {
      assert(oid == sender, 'station ID not match: $oid, $sender');
    }
    // handle handshake command with title & session key
    String title = command.title;
    String? newKey = command.sessionKey;
    String? oldKey = session.key;
    assert(newKey != null, "new session key should not be empty: $command");
    if (title == "DIM?") {
      // S -> C: station ask client to handshake again
      if (oldKey == null) {
        // first handshake response with new session key
        messenger.handshake(newKey);
      } else if (oldKey == newKey) {
        // duplicated handshake response?
        // or session expired and the station ask to handshake again?
        messenger.handshake(newKey);
      } else {
        // connection changed?
        // erase session key to handshake again
        session.key = null;
      }
    } else if (title == "DIM!") {
      // S -> C: handshake accepted by station
      if (oldKey == null) {
        // normal handshake response,
        // update session key to change state to 'running'
        session.key = newKey;
      } else if (oldKey == newKey) {
        // duplicated handshake response?
        Log.warning("duplicated handshake response");
      } else {
        // FIXME: handshake error
        // erase session key to handshake again
        session.key = null;
      }
    } else {
      // C -> S: Hello world!
      Log.warning("Handshake from other user? $sender: $content");
    }
    return [];
  }

}
