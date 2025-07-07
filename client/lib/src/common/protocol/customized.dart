/* license: https://mit-license.org
 *
 *  DIMP : Decentralized Instant Messaging Protocol
 *
 *                                Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
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
 * ==============================================================================
 */
import 'package:dimsdk/dimsdk.dart';


///  Application Customized message: {
///      type : 0xCC,
///      sn   : 123,
///
///      app   : "{APP_ID}",  // application (e.g.: "chat.dim.sechat")
///      mod   : "{MODULE}",  // module name (e.g.: "drift_bottle")
///      act   : "{ACTION}",  // action name (3.g.: "throw")
///      extra : info         // action parameters
///  }
abstract interface class CustomizedContent implements Content {

  /// get App ID
  String get application;

  /// get Module name
  String get module;

  /// get Action name
  String get action;

  //
  //  Factory
  //

  static CustomizedContent create({
    required String app, required String mod, required String act
  }) => AppCustomizedContent.from(app: app, mod: mod, act: act);

}


/// CustomizedContent
class AppCustomizedContent extends BaseContent implements CustomizedContent {
  AppCustomizedContent(super.dict);

  AppCustomizedContent.fromType(String msgType, {
    required String app, required String mod, required String act
  }) : super.fromType(msgType) {
    this['app'] = app;
    this['mod'] = mod;
    this['act'] = act;
  }
  AppCustomizedContent.from({
    required String app, required String mod, required String act
  }) : this.fromType(ContentType.CUSTOMIZED, app: app, mod: mod, act: act);

  @override
  String get application => getString('app', null) ?? '';

  @override
  String get module => getString('mod', null) ?? '';

  @override
  String get action => getString('act', null) ?? '';

}
