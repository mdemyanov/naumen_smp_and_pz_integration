import 'dart:async';
import 'dart:html';

import 'package:naumen_smp_jsapi/naumen_smp_jsapi.dart';

import 'package:pzdart/src/tab/tab_controller.dart';
import 'pz_controller.dart';
import 'pz_account.dart';
import 'pz_event.dart';

const String interactionFqn = 'interaction';
const String incomingFqn = 'interaction\$incomingCall';
const String outgoingFqn = 'interaction\$outgoingCall';
const String idHolder = 'idHolder';
const String openWindow = 'openWindow';
const String newCall = 'newCall';

final Map<String, String> transformRule = {
  'from': 'fromText',
  'to': 'toText',
  'startTime': 'startTime',
  'endTime': 'endTime',
  'duration': 'activeTime',
  'record': 'linkToRecord'
};

final uid = new RegExp(r"#uuid:(\w+\$\d+)");

class CtiController {
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

  bool connect() {
    if (connected) {
      return true;
    }
    if (_vendorController.connect()) {
      callActions.listen(_vendorController.actionListener);
      _vendorController.events.listen(eventListener);
      return true;
    }
    return false;
  }

  bool disconnect() => _vendorController.disconnect();

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
  // 'from': 'fromText',
  //  'to': 'toText',
  //  'startTime': 'startTime',
  //  'endTime': 'endTime',
  //  'duration': 'activeTime',
  //  'record': 'linkToRecord'
  Future eventListener(VendorEvent event) async {
    Map<String, String> data = event.toMap();
    Map interaction =
        await SmpAPI.findFirst('/$interactionFqn/{$idHolder:${event.callID}}');
    bool openInteractionCard =
        (interaction == null || interaction.length == 0) ? true : false;
    switch (event.type) {
      case 'incoming':
        break;
      case 'outgoing':
        break;
      case 'transfer':
        break;
      case 'history':
        interaction = await processEvent(data, interaction, event.fqn, event.callID);
        windowOpenAction(openInteractionCard, interaction);
        break;
      case 'outgoingAnswer':
        String serviceCall = getCallFromUUID('serviceCall', _tab);
        print('Source ' + _tab.getKey('callFromCard').toString());
        print('Scall ' + (serviceCall == null).toString());
        if (serviceCall != null) {
          data.addAll({'serviceCall': serviceCall});
        }
        interaction =
            await processEvent(data, interaction, outgoingFqn, event.callID);
        windowOpenAction(true, interaction);
        break;
      case 'incomingAnswer':
        interaction =
            await processEvent(data, interaction, incomingFqn, event.callID);
        windowOpenAction(true, interaction);
        break;
    }
  }

  Future<Map> processEvent(
      Map data, Map interaction, String fqn, String callID) async {
    print('interaction');
    if (interaction == null || interaction.length == 0) {
      data[idHolder] = callID;
      interaction = await SmpAPI.create('/$fqn', data);
    } else {
      SmpAPI.edit('/${interaction['UUID']}', data);
    }
    print(interaction);
    return interaction;
  }

  void windowOpenAction(bool openInteractionCard, Map interaction) {
    if (openInteractionCard) {
      if (_tab.isActive()) {
        print('Open window');
        _tab.openWindow('./#uuid:${interaction['UUID']}',
            '../#uuid:${interaction['title']}');
      } else {
        print('put to storage');
        _tab.putToLocalStorage(openWindow, './#uuid:${interaction['UUID']}');
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

  Map<String, dynamic> get bindings =>
      <String, dynamic>{'call': makeCall, 'isConnected': connected};
}

String getSourceUUID(String fqn) {
  Match match = uid.firstMatch(window.location.hash);
  if (match != null) {
    String uuid = match.group(1);
    return uuid.contains(fqn) ? uuid : null;
  }
  return null;
}

String getCallFromUUID(String fqn, TabController tab) {
  Match match = uid.firstMatch(tab.getKey('callFromCard').toString());
  if (match != null) {
    String uuid = match.group(1);
    return uuid.contains(fqn) ? uuid : null;
  }
  return null;
}
