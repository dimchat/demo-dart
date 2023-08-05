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


///  Handshake State
///  ~~~~~~~~~~~~~~~
class HandshakeState {

  static const int kStart = 0;    // C -> S, without session key(or session expired)
  static const int kAgain = 1;    // S -> C, with new session key
  static const int kRestart = 2;  // C -> S, with new session key
  static const int kSuccess = 3;  // S -> C, handshake accepted

  static int checkState(String title, String? session) {
    if (title == 'DIM!'/* || title == 'OK!'*/) {
      return kSuccess;
    } else if (title == 'DIM?') {
      return kAgain;
    } else if (session == null) {
      return kStart;
    } else {
      return kRestart;
    }
  }
}


///  Handshake command: {
///      type : 0x88,
///      sn   : 123,
///
///      command : "handshake",    // command name
///      title   : "Hello world!", // "DIM?", "DIM!"
///      session : "{SESSION_KEY}" // session key
///  }
abstract class HandshakeCommand implements Command {

  static const String kHandshake = 'handshake';

  String get title;
  String? get sessionKey;

  int get state;

  //
  //  Factories
  //

  static HandshakeCommand start() =>
      BaseHandshakeCommand.from('Hello world!');

  static HandshakeCommand restart(String session) =>
      BaseHandshakeCommand.from('Hello world!', sessionKey: session);

  static HandshakeCommand again(String session) =>
      BaseHandshakeCommand.from('DIM?', sessionKey: session);

  static HandshakeCommand success(String? session) =>
      BaseHandshakeCommand.from('DIM!', sessionKey: session);

}

class BaseHandshakeCommand extends BaseCommand implements HandshakeCommand {
  BaseHandshakeCommand(super.dict);

  BaseHandshakeCommand.from(String title, {String? sessionKey})
      : super.fromName(HandshakeCommand.kHandshake) {
    // text message
    this['title'] = title;
    // session key
    if (sessionKey != null) {
      this['session'] = sessionKey;
    }
  }

  @override
  String get title => getString('title')!;

  @override
  String? get sessionKey => getString('session');

  @override
  int get state => HandshakeState.checkState(title, sessionKey);

}
