import 'dart:html';
import 'dart:async';

import 'pz_account.dart';
import 'pz_event.dart';

class VendorController {
  bool _connected = false;
  WebSocket _webSocket;
  StreamController<VendorEvent> _streamController;
  VendorAccount _vendorAccount;

  VendorController(VendorAccount vendorAccount) {
    this._vendorAccount = vendorAccount;
    this._streamController = new StreamController<VendorEvent>.broadcast();
  }

  Stream<VendorEvent> get events => _streamController.stream;

  bool get connected => _connected;
  String get accountUid => _vendorAccount.uuid;

  void processEvent(MessageEvent event) {
    print('PZ: новое событие - ${event.data}');
    VendorEvent vendorEvent =
        VendorEvent(_vendorAccount.parseEvent(event.data.toString()));
    print('Тип ${vendorEvent.type}, ID ${vendorEvent.callID}');
    if (vendorEvent.type != null) {
      _streamController.add(vendorEvent);
    } else {
      print('PZ: неопознанное событие');
    }
  }

  bool connect([String request = null]) {
    String connectionUrl = _vendorAccount.connectionUrl;
    try {
      print('PZ: Пробую подключиться к $connectionUrl');
      _webSocket = new WebSocket(connectionUrl);
      _connected = true;
      if (request != null) {
        _webSocket.onOpen.listen((_) => sendMessage(request));
      }
      _webSocket.onMessage.listen(processEvent);
      _webSocket.onError.listen((Event e) => _vendorAccount.eventInfo('Проблема с WS каналом: ${e.toString()}'));
      _vendorAccount.connectionSuccessInfo();
    } catch (e) {
      handleError(
          'При подключении к $connectionUrl возникла ошибка', e.toString());
      _vendorAccount.connectionFailedInfo(e.toString());
    }
    return _connected;
  }

  bool sendMessage(String message) {
    try {
      _webSocket.send(message);
      print('PZ: отправка сообщения - ${message}');
      return true;
    } catch (e) {
      handleError(e);
      return false;
    }
  }

  void actionListener(CustomEvent event) {
    print('PZ: новое действие - ${event.type}/${event.detail}');
    switch (event.type) {
      case 'makeCall':
        makeCall(event.detail.toString());
        break;
      case 'transfer':
        makeCall(event.detail.toString());
        break;
    }
  }

  String prepareRequest(String method, String data) {
    String request = '<Request>'
        '<ProtocolVersion>1</ProtocolVersion>'
        '<Method>$method</Method>'
        '<RequestID>0</RequestID>'
        '<Data>$data</Data>'
        '</Request>';
    if (_vendorAccount.secure == false) {
      request = VendorAccount.normalizeString(request);
    }
    return request;
  }

  void makeCall(String number) => sendWsMessage(prepareRequest(
      'Call', '<From>${_vendorAccount.login}</From><To>$number</To>'));

  void transfer(String number) =>
      sendWsMessage(prepareRequest('Transfer', number));

  bool close() {
    if (_connected) {
      try {
        _webSocket.close();
        _connected = false;
        _vendorAccount.connectionClosedInfo();
        print('PZ: Отключился от ${_vendorAccount.connectionUrl}');
      } catch (e) {
        handleError(
            'Возникла ошибка, при попытке отключиться от ${_vendorAccount.connectionUrl}',
            e.toString());
      }
    }
    return _connected;
  }

  bool disconnect() => close();

  bool sendWsMessage(String request) {
    bool sent = false;
    if (!_connected) {
      print("PZ: нет соединения, не могу послать вызов.");
      return sent;
    }
    switch (_webSocket.readyState) {
      case 0:
        _webSocket.onOpen.listen((_) => sent = sendMessage(request));
        break;
      case 1:
        sent = sendMessage(request);
        break;
      case 2:
        print("PZ: идет отключение от канала, не могу послать вызов.");
        break;
      case 3:
        sent = connect(request);
    }
    return sent;
  }

  void handleError(dynamic e, [String msg = 'PZ: ']) =>
      window.console.error('$msg: ${e.toString()}');

  void printEvent(String rawEvent) {
    window.console.info(rawEvent);
  }
}
