import 'dart:convert';
import 'dart:async';

import 'package:naumen_smp_rest/naumen_smp_rest.dart' as utils;

final hasProtocol = new RegExp(r"^wss?p?://");
final hasPort = new RegExp(r":\d+$");
final eventAttr = new RegExp(r"\s(\w+)=\W([\+-=\w:/\.]+)\W");

class VendorAccount {
  static String ver = '1.0.1';
  static const String vendor = 'simpleCalls';
  static const String _clientType = 'itsm365';
  static const String _defaultPort = ':10150';
  static const String _defaultProtocol = 'ws://';
  static Base64Codec base64Codec = Base64Codec();
  static Utf8Codec utf8Codec = Utf8Codec();
  String login;
  String uuid;
  String _url;
  String _password;

  VendorAccount.fromMap(Map account) {
    this.login = account['login'] as String;
    this.uuid = account['UUID'] as String;
    this._url = account['url'] as String;
    this._password =
        (account['password'] != null ? account['password'] : '') as String;
  }

  static Future<VendorAccount> get(String userId) async {
    var account = await utils.findFirst('account\$$vendor',
        <String, String>{'employee': userId, 'state': 'registered'});
    if (account.length != 0) {
      return VendorAccount.fromMap(account);
    }
    return null;
  }

  static String normalizeString(String string) =>
      base64Codec.encode(utf8Codec.encode(string));

  bool get secure => url.contains('wss');

  String get password => normalizeString(_password);

  String get connectionUrl => '$url/'
      '?CID=$password'
      '&CT=$_clientType'
      '&GID=$login'
      '&PhoneNumber=$login'
      '&BroadcastEventsMask=0'
      '&BroadcastGroup=1'
      '&PzProtocolVersion=1';

  String get url {
    String result = _url;
    if (!hasProtocol.hasMatch(_url)) {
      result = _defaultProtocol + _url;
    }
    if (!hasPort.hasMatch(_url)) {
      result += _defaultPort;
    }
    return result;
  }

  Map<String, String> parseEvent(String event) {
    Map<String, String> eventData = {};
    if (secure == false) {
      event = new String.fromCharCodes(base64Codec.decode(event));
    }
    eventAttr.allMatches(event).forEach((attr) {
      eventData[attr.group(1)] = attr.group(2);
    });
    print('PZ: массив события - ${eventData}');
    print('PZ: массив события - ${eventData}');
    return eventData;
  }

  void connectionSuccessInfo() => utils.create('comment',
      <String, String>{'source': uuid, 'text': 'Успешно подключился'});

  void connectionClosedInfo(List<int> stack) => utils.create(
      'comment', <String, String>{'source': uuid, 'text': 'Отключился ' + stack.toString()});

  void connectionFailedInfo(String error) => utils.create('comment',
      <String, String>{'source': uuid, 'text': 'Ошибка подключения: $error'});

  void eventInfo(String message) => utils
      .create('comment', <String, String>{'source': uuid, 'text': message});
}
