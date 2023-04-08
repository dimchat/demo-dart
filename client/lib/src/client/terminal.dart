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

import '../dim_network.dart';
import 'messenger.dart';
import 'network/session.dart';
import 'network/state.dart';
import 'packer.dart';
import 'processor.dart';

mixin DeviceMixin {

  // "zh-CN"
  String get language;

  // "DIM"
  String get displayName;

  // "1.0.1"
  String get versionName;

  // "4.0"
  String get systemVersion;

  // "HMS"
  String get systemModel;

  // "hammerhead"
  String get systemDevice;

  // "HUAWEI"
  String get deviceBrand;

  // "hammerhead"
  String get deviceBoard;

  // "HUAWEI"
  String get deviceManufacturer;

  ///  format: "DIMP/1.0 (Linux; U; Android 4.1; zh-CN) DIMCoreKit/1.0 (Terminal, like WeChat) DIM-by-GSP/1.0.1"
  String get userAgent {
    String model = systemModel;
    String device = systemDevice;
    String sysVersion = systemVersion;
    String lang = language;

    String appName = displayName;
    String appVersion = versionName;

    return "DIMP/1.0 ($model; U; $device $sysVersion; $lang)"
        " DIMCoreKit/1.0 (Terminal, like WeChat) $appName-by-MOKY/$appVersion";
  }

}

abstract class Terminal with DeviceMixin implements SessionStateDelegate {
  Terminal(this.facebook, this.sdb) : _messenger = null;

  final SessionDBI sdb;
  final CommonFacebook facebook;

  ClientMessenger? _messenger;

  ClientMessenger? get messenger => _messenger;

  ClientSession? get session => messenger?.session;

  ClientMessenger connect(String host, int port) {
    ClientMessenger? old = messenger;
    if (old != null) {
      ClientSession session = old.session;
      if (session.isActive) {
        // current session is active
        Station station = session.station;
        if (station.host == host && station.port == port) {
          // same target
          return old;
        }
      }
    }
    // // stop the machine & remove old messenger
    // StateMachine machine = fsm;
    // if (machine != null) {
    //   machine.stop();
    //   fsm = null;
    // }
    // create new messenger with session
    Station station = createStation(host, port);
    ClientSession session = createSession(station);
    ClientMessenger transceiver = createMessenger(session, facebook);
    _messenger = transceiver;
    // create packer, processor for messenger
    // they have weak references to facebook & messenger
    transceiver.packer = createPacker(facebook, transceiver);
    transceiver.processor = createProcessor(facebook, transceiver);
    // set weak reference to messenger
    session.messenger = transceiver;
    // // create & start state machine
    // machine = StateMachine(session);
    // machine.setDelegate(this);
    // machine.start();
    // fsm = machine;
    return transceiver;
  }
  // protected
  Station createStation(String host, int port) {
    Station station = Station.fromRemote(host, port);
    station.dataSource = facebook;
    return station;
  }
  // protected
  ClientSession createSession(Station station) {
    ClientSession session = ClientSession(station, sdb);
    // set current user for handshaking
    User? user = facebook.currentUser;
    if (user != null) {
      session.setIdentifier(user.identifier);
    }
    session.start();
    return session;
  }
  // protected
  Packer createPacker(CommonFacebook facebook, ClientMessenger messenger) {
    return ClientMessagePacker(facebook, messenger);
  }
  // protected
  Processor createProcessor(CommonFacebook facebook, ClientMessenger messenger) {
    return ClientMessageProcessor(facebook, messenger);
  }
  // protected
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook);

  bool login(ID current) {
    ClientSession? clientSession = session;
    if (clientSession == null) {
      return false;
    } else {
      clientSession.setIdentifier(current);
      return true;
    }
  }

  // protected
  void keepOnline(ID uid, ClientMessenger messenger) {
    if (uid.type == EntityType.kStation) {
      // a station won't login to another station, if here is a station,
      // it must be a station bridge for roaming messages, we just send
      // report command to the target station to keep session online.
      messenger.reportOnline(uid);
    } else {
      // send login command to everyone to provide more information.
      // this command can keep the user online too.
      messenger.broadcastLogin(uid, userAgent);
    }
  }

  //
  //  FSM Delegate
  //

  @override
  void enterState(SessionState next, SessionStateMachine ctx, int now) {
    // called before state changed
  }

  @override
  void exitState(SessionState previous, SessionStateMachine ctx, int now) {
    // called after state changed
    SessionState? current = ctx.currentState;
    if (current == null) {
      return;
    }
    if (current.index == SessionStateOrder.kHandshaking) {
      // start handshake
      messenger?.handshake(null);
    } else if (current.index == SessionStateOrder.kRunning) {
      // broadcast current meta & visa document to all stations
      messenger?.handshakeSuccess();
    }
  }

  @override
  void pauseState(SessionState current, SessionStateMachine ctx, int now) {

  }

  @override
  void resumeState(SessionState current, SessionStateMachine ctx, int now) {
    // TODO: clear session key for re-login?
  }

}
