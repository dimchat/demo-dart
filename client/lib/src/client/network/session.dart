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
import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';
import 'package:stargate/stargate.dart';
import 'package:startrek/nio.dart';
import 'package:startrek/startrek.dart';

import '../../common/dbi/session.dart';
import '../../network/session.dart';

import 'state.dart';

///  Session for Connection
///  ~~~~~~~~~~~~~~~~~~~~~~
///
///  'key' - Session Key
///          A random string generated by station.
///          It will be set after handshake success.
///
///   'ID' - Local User ID
///          It will be set before connecting to remote station.
///          When it's empty, the session state would be 'Default'.
///
///   'active' - Session Status
///          It will be set to True after connected to remote station.
///          When connection broken, it will be set to False.
///          Only send message when it's True.
///
///   'station' - Remote Station
///          Station with remote IP & port, its ID will be set
///          when first handshake responded, and we can trust
///          all messages from this ID after that.
class ClientSession extends BaseSession with Logging {
  ClientSession(SessionDBI database, this._server)
      : super(database, remote: InetSocketAddress(_server.host!, _server.port)) {
    _fsm = SessionStateMachine(this);
    _key = null;
  }

  final Station _server;
  late final SessionStateMachine _fsm;

  String? _key;

  Station get station => _server;

  SessionState? get state => _fsm.currentState ?? _fsm.defaultState;

  @override
  String? get key => _key;

  set key(String? sessionKey) => _key = sessionKey;

  /// pause state machine
  Future<void> pause() async => await _fsm.pause();

  /// resume state machine
  Future<void> resume() async => await _fsm.resume();

  /// start session in background thread
  /// start session state machine
  Future<void> start(SessionStateDelegate delegate) async {
    await stop();
    // start a background thread
    /*await */run();
    // start state machine
    _fsm.delegate = delegate;
    await _fsm.start();
}

  /// stop state machine for this session
  /// stop background machine for this session
  @override
  Future<void> stop() async {
    await super.stop();
    // stop state machine
    await _fsm.stop();
    // wait for thread stop
  }

  @override
  Future<void> setup() async {
    setActive(true, null);
    await super.setup();
  }

  @override
  Future<void> finish() async {
    setActive(false, null);
    await super.finish();
  }

  // @override
  // StreamHub createHub(ConnectionDelegate delegate, SocketAddress remote) {
  //   ClientHub hub = ClientHub(delegate);
  //   // Connection? conn = await hub.connect(remote: remote);
  //   // assert(conn != null, 'failed to connect remote: $remote');
  //   // TODO: reset send buffer size
  //   return hub;
  // }

  //
  //  Docker Delegate
  //

  @override
  Future<void> onDockerStatusChanged(DockerStatus previous, DockerStatus current, Docker docker) async {
    // await super.onDockerStatusChanged(previous, current, docker);
    if (current == DockerStatus.error) {
      // connection error or session finished
      // TODO: reconnect?
      setActive(false, null);
      // TODO: clear session ID and handshake again
    } else if (current == DockerStatus.ready) {
      // connected/ reconnected
      setActive(true, null);
    }
  }

  @override
  Future<void> onDockerReceived(Arrival ship, Docker docker) async {
    // await super.onDockerReceived(ship, docker);
    List<Uint8List> allResponses = [];
    // 1. get data packages from arrival ship's payload
    List<Uint8List> packages = _getDataPackages(ship);
    List<Uint8List> responses;
    for (Uint8List pack in packages) {
      try {
        // 2. process each data package
        responses = await messenger!.processPackage(pack);
        if (responses.isEmpty) {
          continue;
        }
        for (Uint8List res in responses) {
          if (res.isEmpty) {
            // should not happen
            continue;
          }
          allResponses.add(res);
        }
      } catch (e, st) {
        // FIXME:
        logError('failed to process package: ${pack.length} bytes, error: $e');
        logDebug('failed to process package: ${pack.length} bytes, error: $e, $st');
      }
    }
    SocketAddress source = docker.remoteAddress!;
    SocketAddress? destination = docker.localAddress;
    // 3. send responses separately
    for (Uint8List res in allResponses) {
      await gate.sendResponse(res, ship, remote: source, local: destination);
    }
  }

}

List<Uint8List> _getDataPackages(Arrival ship) {
  Uint8List payload = (ship as PlainArrival).payload;
  // check payload
  if (payload.isEmpty) {
    return [];
  } else if (payload[0] == _jsonBegin) {
    // JsON in lines
    return _splitLines(payload);
  } else {
    return [payload];
  }
}

final int _jsonBegin = '{'.codeUnitAt(0);
final int _lineFeed = '\n'.codeUnitAt(0);

List<Uint8List> _splitLines(Uint8List payload) {
  int end = payload.indexOf(_lineFeed);
  if (end < 0) {
    return [payload];
  }
  int start = 0;
  List<Uint8List> lines = [];
  while (end > 0) {
    if (end > start) {
      lines.add(payload.sublist(start, end));
    }
    start = end + 1;
    end = payload.indexOf(_lineFeed, start);
  }
  if (start < payload.length) {
    lines.add(payload.sublist(start));
  }
  return lines;
}
