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
import 'package:lnc/log.dart';

import 'utils/cache.dart';

class CommonArchivist extends Barrack with Logging {
  CommonArchivist(Facebook facebook) : _facebook = WeakReference(facebook);

  final WeakReference<Facebook> _facebook;

  // protected
  Facebook? get facebook => _facebook.target;

  /// memory caches
  late final MemoryCache<ID, User>   _userCache = createUserCache();
  late final MemoryCache<ID, Group> _groupCache = createGroupCache();

  // protected
  MemoryCache<ID, User> createUserCache() => ThanosCache();
  MemoryCache<ID, Group> createGroupCache() => ThanosCache();

  /// Call it when received 'UIApplicationDidReceiveMemoryWarningNotification',
  /// this will remove 50% of cached objects
  ///
  /// @return number of survivors
  int reduceMemory() {
    int cnt1 = _userCache.reduceMemory();
    int cnt2 = _groupCache.reduceMemory();
    return cnt1 + cnt2;
  }

  //
  //  Barrack
  //

  @override
  void cacheUser(User user) {
    user.dataSource ??= facebook;
    _userCache.put(user.identifier, user);
  }

  @override
  void cacheGroup(Group group) {
    group.dataSource ??= facebook;
    _groupCache.put(group.identifier, group);
  }

  @override
  User? getUser(ID identifier) => _userCache.get(identifier);

  @override
  Group? getGroup(ID identifier) => _groupCache.get(identifier);

}
