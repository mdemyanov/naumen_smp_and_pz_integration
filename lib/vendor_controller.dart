import 'dart:convert';
import 'dart:html';
import 'dart:async';
import 'package:intl/intl.dart';

final eventAttr = new RegExp(r"\s(\w+)=\W([\+\w]+)\W");
final hasPort = new RegExp(r":\d+$");
final hasProtocol = new RegExp(r"^wss?p?://");

final Map eventTypes = {
  '1': 'transfer',
  '2': 'incoming',
  '4': 'history',
  '8': 'outgoing',
  '16': 'outgoingAnswer',
  '32': 'incomingAnswer',
};
const bool log = true;
// Для всех событий
const String state = 'type';
const String callID = 'callID';
const String from = 'from';
const String to = 'to';
// Для завершенных звонков
const String startTime = 'start';
const String endTime = 'end';
const String duration = 'duration';
const String direction = 'direction';
const String record = 'record';
final Map allAttrs = {
  state: 'state',
  callID: 'callID',
  from: 'from',
  to: 'to',
  startTime: 'startTime',
  endTime: 'endTime',
  duration: 'duration',
  direction: 'direction',
  record: 'record'
};

final List<String> dates = [startTime, endTime];

class VendorController {
  static const String _vendor = 'simpleCalls';

  bool _isConnected = false;
  WebSocket _webSocket;
  String _url;
  String _connectionUrl;
  String _login;
  String _password;
  String _clientType = 'jsapi';
  String _broadcastGroup = '';
  int _broadcastEventsMask = 0;
  int _protocolVersion = 1;
  String _defaultPort = ':10150';
  String _defaultProtocol = 'ws://';
  StreamController _streamController;

  VendorController.fromJson(Map account) {
    this._login = account['login'];
    this._url = normalizeUrl(account['url']);
    this._password = normalizePassword(account['password'] != null ? account['password'] : '');
    this._connectionUrl = '$_url/'
        '?CID=$_password'
        '&CT=$_clientType'
        '&GID=$_login'
        '&PhoneNumber=$_login'
        '&BroadcastEventsMask=$_broadcastEventsMask'
        '&BroadcastGroup=$_broadcastGroup'
        '&PzProtocolVersion=1';
    this._streamController = new StreamController.broadcast();
  }

  static String getVendor() => _vendor;

  String getConnectionUrl() => _connectionUrl;

  bool isSecure() => _connectionUrl.contains('wss');

  static String normalizeString(String password) =>
      BASE64.encode(UTF8.encode(password));

  static String normalizePassword(String password) => normalizeString(password);

  static String parseMsg(String message, bool secure) {
    if(secure == false) {
      message = new String.fromCharCodes(BASE64.decode(message));
    }
    return message;
  }

  String normalizeUrl(String url) {
    if (!hasProtocol.hasMatch(url)) {
      url = _defaultProtocol + url;
    }
    if (!hasPort.hasMatch(url)) {
      url += _defaultPort;
    }
    return url;
  }

  bool connect() {
    try {
      _webSocket = new WebSocket(_connectionUrl);
      _isConnected = true;
    } catch (e) {
      handleError(e);
    }
    return _isConnected;
  }

  bool sendMessage(String message) {
    try {
      _webSocket.send(message);
      return true;
    } catch (e) {
      handleError(e);
      return false;
    }
  }

  Stream<CustomEvent> get events {
    _webSocket.onMessage.listen((vendorEvent) {
      print(vendorEvent.data);
      CustomEvent event = getEvent(parseEvent(vendorEvent));
      if (event != null) {
        _streamController.add(event);
      }
    })
    .onError(handleError);
    return _streamController.stream;
  }

  StreamSubscription addEventListener(listener) => events.listen(listener);

  CustomEvent getEvent(Map event) {
    try {
      return new CustomEvent(
          eventTypes[event['state']] != null
              ? eventTypes[event['state']]
              : 'undefined',
          detail: event);
    } catch (e) {
      print(e);
      return null;
    }
  }

  Map parseEvent(MessageEvent event) {
    Map eventData = {};
    String message = parseMsg(event.data, isSecure());
    eventAttr.allMatches(message).forEach((attr) {
      eventData[attr.group(1)] = attr.group(2);
    });
    Map data = {};
    eventData.forEach((vendorKey, value) {
      if (allAttrs.containsKey(vendorKey)) {
        switch (vendorKey) {
          case startTime:
          case endTime:
            var formatter = new DateFormat('yyyy.MM.dd HH:mm:ss');
            DateTime dt =
                new DateTime.fromMillisecondsSinceEpoch(int.parse(value) * 1000, isUtc: true);
            data[allAttrs[vendorKey]] = formatter.format(dt);
            break;
          case duration:
            data[allAttrs[vendorKey]] = int.parse(value) * 1000;
            break;
          default:
            data[allAttrs[vendorKey]] = value;
        }
      }
    });
    printEvent(message, data);
    return data;
  }

  void actionListener(CustomEvent event) {
    switch (event.type) {
      case 'makeCall':
        makeCall(event.detail);
        break;
      case 'transfer':
        makeCall(event.detail);
        break;
    }
  }

  String prepareRequest(String method, String data) {
    String request = '<Request>'
        '<ProtocolVersion>$_protocolVersion</ProtocolVersion>'
        '<Method>$method</Method>'
        '<RequestID>0</RequestID>'
        '<Data>$data</Data>'
        '</Request>';
    if (isSecure() == false) {
      request = normalizeString(request);
    }
    return request;
  }

  void makeCall(String number) => _webSocket
      .send(prepareRequest('Call', '<From>$_login</From><To>$number</To>'));

  void transfer(String number) =>
      _webSocket.send(prepareRequest('Transfer', number));
  void handleError(e) => window.console.error(e);

  void printEvent(String rawEvent, Map eventData) {
    window.console.group(rawEvent);
    eventData.forEach((key, value){window.console.log('$key: $value');});
    window.console.groupEnd();
  }
}
