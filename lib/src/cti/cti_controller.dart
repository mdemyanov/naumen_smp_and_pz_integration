import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:naumen_smp_rest/naumen_smp_rest.dart' as utils;

import 'package:pzdart/src/tab/tab_controller.dart';
import 'package:pzdart/src/nsmp/nsmp_response.dart';
import 'pz_controller.dart';
import 'pz_account.dart';

const String interactionFqn = 'interaction';
const String incomingFqn = 'interaction\$incomingCall';
const String outgoingFqn = 'interaction\$outgoingCall';
const String idHolder = 'idHolder';
const String openWindow = 'openWindow';
const String newCall = 'newCall';
const Map<String, String> cardFqns = <String, String>{
  'serviceCall': 'serviceCall',
  'interaction': 'interaction'
};

final uid = new RegExp(r"#uuid:((\w+)\$\d+)");

class CtiController {
  static String ver = '1.1.0';
  TabController _tab;
  VendorController _vendorController;
  String _prefix;
  StreamController<CustomEvent> _callActions;

  CtiController(VendorAccount account, TabController tab) {
    _tab = tab;
    _prefix = tab.getPrefix();
    _vendorController = VendorController(account);
    this._callActions = new StreamController<CustomEvent>();
  }

  bool get connected => _vendorController.connected;

  bool reconnect() => _vendorController.reconnect();

  bool connect() {
    if (connected) {
      return true;
    }
    if (_vendorController.connecting) {
      window.console.warn('alrady connectiing...');
      return true;
    }
    if(_vendorController.used) {
      _vendorController.reconnect();
      //_vendorController.events.listen(eventListener);
    } else if (_vendorController.connect()) {
      callActions.listen(_vendorController.actionListener);
      _vendorController.events.listen(eventListener);
      return true;
    }
    return false;
  }

  bool disconnect(List<int> stack) => _vendorController.disconnect(stack);

  void storageListener(StorageEvent event) {
    String key = event.key.split('$_prefix:').last;
    switch (key) {
      case openWindow:
        if (_tab.isActive()) {
          print('Активная вкладка - открываем окно: ${event.newValue}');
          _tab.openWindow(event.newValue, event.newValue);
          _tab.removeFromLocalStorage('openWindow');
        }
        break;
      case 'makeCall':
        if (connected && event.newValue != null) {
          makeCall(event.newValue);
          _tab.removeFromLocalStorage('makeCall');
        }
        break;
    }
  }

  Future eventListener(Map<String, String> event) async {
    if(event.containsKey('direction') && event['direction'] == '1') {
      event.addAll(getCallFromUUID(cardFqns, _tab));
    }
    try {
      processEvent(event);
    } catch (e) {
      handleError(e);
    }
  }

  Future<Null> processEvent(Map<String, String> event) async {
    NsmpResponse response = NsmpResponse.fromJson(await utils.execPostContent(
        'pzRest.call', event) as Map<String, dynamic>);
    if (response.result == 'ok') {
      switch (response.data.action) {
        case 'openNewWindow':
          windowOpenAction(true, response.data);
          break;
      }
    }

      return null;
  }

  void windowOpenAction(bool openInteractionCard, Data interaction) {
    if (openInteractionCard) {
      if (_tab.isActive()) {
        print('Open window');
        _tab.openWindow('./#uuid:${interaction.UUID}',
            '../#uuid:${interaction.title}');
      } else {
        print('put to storage');
        _tab.putToLocalStorage(openWindow, './#uuid:${interaction.UUID}');
      }
    }
  }

  void makeCall(String number) {
    _tab.removeFromLocalStorage('makeCall');
    if (_tab.isActive()) {
      _tab.removeFromLocalStorage('callFromCard');
      _tab.putToLocalStorage('callFromCard', _tab.getCurrentHash());
    }
    if (connected) {
      _callActions.add(new CustomEvent('makeCall', detail: number));
    } else {
      _tab.putToLocalStorage('makeCall', number);
    }
  }

  Stream<CustomEvent> get callActions => _callActions.stream;

  Map<String, dynamic> get bindings => <String, dynamic>{
        'call': allowInterop(makeCall),
        'isConnected': connected
      };
}

Map<String, String> getSourceParams(Map<String, String> cards) {
  Match match = uid.firstMatch(window.location.hash);
  if (match != null) {
    return cards.map((attr, fqn) {
      return (fqn == match.group(2) ? {attr: match.group(1)} : null)
          as MapEntry<String, String>;
    });
  }
  return null;
}

Map<String, String> getCallFromUUID(
    Map<String, String> cards, TabController tab) {
  Map<String, String> result = {};
  Match match = uid.firstMatch(tab.getKey('callFromCard').toString());
  tab.removeFromLocalStorage('callFromCard');
  if (match != null) {
    cards.forEach((attr, fqn) {
      if (fqn == match.group(2)) {
        result[attr] = match.group(1);
      }
    });
  }
  return result;
}

void handleError(dynamic e, [String msg = 'PZ: ']) =>
    window.console.error('$msg: ${e.toString()}');
