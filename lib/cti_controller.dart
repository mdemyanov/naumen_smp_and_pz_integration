import 'dart:async';
import 'dart:html';

import 'package:pzdart/tab_controller.dart';

import 'nsmp_rest.dart';

const String interactionFqn = 'interaction';
const String incomingFqn = 'interaction\$incomingCall';
const String outgoingFqn = 'interaction\$outgoingCall';
const String idHolder = 'idHolder';
const String openWindow = 'openWindow';
const String newCall = 'newCall';

final Map transformRule = {
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
  static const String _getAccountUrl = '/account';
  String _userId = '';
  String _account;
  String _prefix;
  StreamController _callActions;
  bool _connected = false;

  CtiController(String userId) {
    this._userId = userId;
    this._callActions = new StreamController.broadcast();
  }

  void setTab(TabController tab) {
    _tab = tab;
    _prefix = tab.getPrefix();
  }

  Future<List> getAccounts() =>
      NsmpRest.find('$_getAccountUrl/{employee:$_userId,state: \'registered\'}');

  Future<Map> getAccount(String vendor) {
    print('$_getAccountUrl\$$vendor/{employee:$_userId}');
    return NsmpRest.findFirst('$_getAccountUrl\$$vendor/{employee:$_userId,state: \'registered\'}');
  }

  void printEvent(CustomEvent event) {
    print(event.type);
    print(event?.detail != null ? event?.detail : '');
  }

  void storageListener(StorageEvent event) {
    String key = event.key.split('$_prefix:').last;
    switch (key) {
      case openWindow:
        if(_tab.isActive()) {
          print('Активная вкладка - открываем окно: ${event.newValue}');
          _tab.openWindow(event.newValue, event.newValue);
          _tab.removeFromLocalStorage('openWindow');
        }
        break;
      case 'makeCall':
        if(_connected && event.newValue != null) {
          makeCall(event.newValue);
          _tab.removeFromLocalStorage('makeCall');
        }
        break;
    }
  }

  Future eventListener(CustomEvent event) async {
    print(event.type);
    print(event.detail);
    Map data = {};
    new Map.from(event.detail).forEach((key, value) {
      if (transformRule.containsKey(key)) {
        data[transformRule[key]] = value;
      }
    });
    String fqn = outgoingFqn;
    if(['incoming', 'incomingAnswer'].contains(event.type)) {
      fqn = incomingFqn;
    }
    String callID = event.detail['callID'];
    Map interaction =
        await NsmpRest.findFirst('/$interactionFqn/{$idHolder:${callID}}');
    bool openInteractionCard =
        (interaction == null || interaction.length == 0) ? true : false;
    print('call switch');
    switch (event.type) {
      case 'incoming':
        break;
      case 'outgoing':
        break;
      case 'transfer':
        break;
      case 'history':
        fqn = event.detail['direction'] == '1' ? outgoingFqn : incomingFqn;
        interaction = await processEvent(data, interaction, fqn, callID);
        windowOpenAction(openInteractionCard, interaction);
        break;
      case 'outgoingAnswer':
        var serviceCall = getCallFromUUID('serviceCall', _tab);
        print('Source ' + _tab.getKey('callFromCard').toString());
        print('Scall ' + (serviceCall == null).toString());
        if (serviceCall != null) {
          data.addAll({'serviceCall': serviceCall});
        }
        interaction =
            await processEvent(data, interaction, outgoingFqn, callID);
        windowOpenAction(true, interaction);
        break;
      case 'incomingAnswer':
        interaction =
            await processEvent(data, interaction, incomingFqn, callID);
        windowOpenAction(true, interaction);
        break;
    }
  }

  Future<Map> processEvent(
      Map data, Map interaction, String fqn, String callID) async {
    print('interaction');
    if (interaction == null || interaction.length == 0) {
      data[idHolder] = callID;
      interaction = await NsmpRest.create('/$fqn', data);
    } else {
      NsmpRest.edit('/${interaction['UUID']}', data);
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
    if(_tab.isActive()){
      _tab.removeFromLocalStorage('callFromCard');
      _tab.putToLocalStorage('callFromCard', _tab.getCurrentHash());
    }
    if(_connected) {
      _callActions.add(new CustomEvent('makeCall', detail: number));
    } else {
      _tab.putToLocalStorage('makeCall', number);
    }
  }

  Stream<CustomEvent> get callActions => _callActions.stream;

  StreamSubscription addCallActionListener(listener) => callActions.listen(listener);

  bool setConnected() => _connected = true;

  bool isConnected() => _connected;

  Map getBindings() {
    return {
      'call': makeCall,
      'isConnected': isConnected
    };
  }

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