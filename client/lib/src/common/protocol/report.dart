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


///  Report command: {
///      type : 0x88,
///      sn   : 123,
///
///      command : "report",
///      title   : "online",      // or "offline"
///      //---- extra info
///      time    : 1234567890,    // timestamp
///  }
abstract interface class ReportCommand implements Command {

  // ignore_for_file: constant_identifier_names
  static const String REPORT  = 'report';
  static const String ONLINE  = 'online';
  static const String OFFLINE = 'offline';

  String get title;
  set title(String text);

  //
  //  Factory
  //

  static ReportCommand fromTitle(String text) => BaseReportCommand.fromTitle(text);

}

class BaseReportCommand extends BaseCommand implements ReportCommand {
  BaseReportCommand(super.dict);

  BaseReportCommand.fromTitle(String text) : super.fromName(ReportCommand.REPORT) {
    title = text;
  }

  @override
  String get title => getString('title') ?? '';

  @override
  set title(String text) => this['title'] = text;

}
