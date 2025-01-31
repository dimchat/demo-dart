/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'package:dimsdk/plugins.dart';
import 'package:dim_plugins/crypto.dart';
import 'package:dim_plugins/format.dart';
import 'package:dim_plugins/plugins.dart';

import '../protocol/ans.dart';
import '../protocol/block.dart';
import '../protocol/customized.dart';
import '../protocol/handshake.dart';
import '../protocol/login.dart';
import '../protocol/mute.dart';
import '../protocol/report.dart';
import '../protocol/search.dart';

import 'address.dart';
import 'entity.dart';
import 'meta.dart';


/// Extensions Loader
/// ~~~~~~~~~~~~~~~~~
class CommonLoader extends ExtensionLoader {
  CommonLoader() {
    pluginLoader = createPluginLoader();
  }

  // private
  late final PluginLoader pluginLoader;

  // protected
  PluginLoader createPluginLoader() => CommonPluginLoader();

  @override
  void run() {
    super.run();
    pluginLoader.run();
  }

  /// Customized content factories
  // protected
  void registerCustomizedFactories() {

    // Application Customized
    Content.setFactory(ContentType.APPLICATION, ContentParser((dict) => AppCustomizedContent(dict)));
    Content.setFactory(ContentType.CUSTOMIZED, ContentParser((dict) => AppCustomizedContent(dict)));

  }

  @override
  void registerContentFactories() {
    super.registerContentFactories();
    registerCustomizedFactories();
  }

  @override
  void registerCommandFactories() {
    super.registerCommandFactories();

    // ANS
    Command.setFactory(AnsCommand.ANS, CommandParser((dict) => BaseAnsCommand(dict)));

    // Handshake
    Command.setFactory(HandshakeCommand.HANDSHAKE, CommandParser((dict) => BaseHandshakeCommand(dict)));
    // Login
    Command.setFactory(LoginCommand.LOGIN, CommandParser((dict) => BaseLoginCommand(dict)));

    // Mute
    Command.setFactory(MuteCommand.MUTE, CommandParser((dict) => MuteCommand(dict)));
    // Block
    Command.setFactory(BlockCommand.BLOCK, CommandParser((dict) => BlockCommand(dict)));

    // Report: online, offline
    Command.setFactory(ReportCommand.REPORT,  CommandParser((dict) => BaseReportCommand(dict)));
    Command.setFactory(ReportCommand.ONLINE,  CommandParser((dict) => BaseReportCommand(dict)));
    Command.setFactory(ReportCommand.OFFLINE, CommandParser((dict) => BaseReportCommand(dict)));

    // Search: users
    Command.setFactory(SearchCommand.SEARCH,       CommandParser((dict) => BaseSearchCommand(dict)));
    Command.setFactory(SearchCommand.ONLINE_USERS, CommandParser((dict) => BaseSearchCommand(dict)));

  }

}


/// Plugin Loader
/// ~~~~~~~~~~~~~
class CommonPluginLoader extends PluginLoader {

  @override
  void registerIDFactory() {
    ID.setFactory(EntityIDFactory());
  }

  @override
  void registerAddressFactory() {
    Address.setFactory(CompatibleAddressFactory());
  }

  @override
  void registerMetaFactories() {
    var mkm = CompatibleMetaFactory(Meta.MKM);
    var btc = CompatibleMetaFactory(Meta.BTC);
    var eth = CompatibleMetaFactory(Meta.ETH);

    Meta.setFactory('1', mkm);
    Meta.setFactory('2', btc);
    Meta.setFactory('4', eth);

    Meta.setFactory('mkm', mkm);
    Meta.setFactory('btc', btc);
    Meta.setFactory('eth', eth);

    Meta.setFactory('MKM', mkm);
    Meta.setFactory('BTC', btc);
    Meta.setFactory('ETH', eth);
  }

  @override
  void registerBase64Coder() {
    /// Base64 coding
    Base64.coder = _Base64Coder();
  }

  @override
  void registerRSAKeyFactories() {
    /// RSA
    var rsaPub = RSAPublicKeyFactory();
    PublicKey.setFactory(AsymmetricKey.RSA, rsaPub);
    PublicKey.setFactory('SHA256withRSA', rsaPub);
    PublicKey.setFactory('RSA/ECB/PKCS1Padding', rsaPub);

    var rsaPri = _RSAPrivateKeyFactory();
    PrivateKey.setFactory(AsymmetricKey.RSA, rsaPri);
    PrivateKey.setFactory('SHA256withRSA', rsaPri);
    PrivateKey.setFactory('RSA/ECB/PKCS1Padding', rsaPri);
  }

}

/// Base-64
class _Base64Coder extends Base64Coder {

  @override
  Uint8List? decode(String string) {
    string = trimBase64String(string);
    return super.decode(string);
  }

  static String trimBase64String(String b64) {
    if (b64.contains('\n')) {
      b64 = b64.replaceAll('\n', '');
      b64 = b64.replaceAll('\r', '');
      b64 = b64.replaceAll('\t', '');
      b64 = b64.replaceAll(' ', '');
    }
    return b64.trim();
  }

}

/// RSA factory
class _RSAPrivateKeyFactory extends RSAPrivateKeyFactory {

  @override
  PrivateKey generatePrivateKey() {
    Map key = {'algorithm': AsymmetricKey.RSA};
    return _RSAPrivateKey(key);
  }

  @override
  PrivateKey? parsePrivateKey(Map key) {
    return _RSAPrivateKey(key);
  }

}

/// RSA key with created time
class _RSAPrivateKey extends RSAPrivateKey {
  _RSAPrivateKey(super.dict) {
    DateTime? time = getDateTime('time', null);
    if (time == null) {
      time = DateTime.now();
      setDateTime('time', time);
    }
  }

  @override
  PublicKey get publicKey {
    PublicKey key = super.publicKey;
    DateTime? time = getDateTime('time', null);
    if (time != null) {
      key.setDateTime('time', time);
    }
    return key;
  }

}
