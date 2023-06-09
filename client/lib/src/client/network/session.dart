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

import '../../dim_common.dart';
import '../../dim_network.dart';

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
abstract class ClientSession extends BaseSession {
  ClientSession(this.station, super.remoteAddress, super.database) {
    _key = null;
  }

  final Station station;
  String? _key;

  @override
  String? get key => _key;

  set key(String? sessionKey) => _key = sessionKey;

  SessionState get state;

  /// pause state machine
  void pause();

  /// resume state machine
  void resume();

  /// start session in background thread
  /// start session state machine
  void start();

  /// stop state machine for this session
  /// stop background machine for this session
  void stop();

  //
  //  Docker Delegate
  //

  @override
  Future<void> onDockerStatusChanged(int previous, int current, Docker docker) async {
    await super.onDockerStatusChanged(previous, current, docker);
    if (current == DockerStatus.kError) {
      // connection error or session finished
      // TODO: reconnect?
      setActive(false, when: 0);
      // TODO: clear session ID and handshake again
    } else if (current == DockerStatus.kReady) {
      // connected/ reconnected
      setActive(true, when: 0);
    }
  }

  @override
  Future<void> onDockerReceived(Arrival ship, Docker docker) async {
    await super.onDockerReceived(ship, docker);
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
      } catch (e) {
        // e.printStackTrace();
      }
    }
    SocketAddress source = docker.remoteAddress;
    SocketAddress destination = docker.localAddress;
    // 3. send responses separately
    for (Uint8List res in allResponses) {
      sendResponse(res, ship, remote: source, local: destination);
    }
  }

}

List<Uint8List> _getDataPackages(Arrival ship) {
  Uint8List payload = ship.payload;
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
