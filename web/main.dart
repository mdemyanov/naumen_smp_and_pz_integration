/**
 * @signedBy mdemyanov
 * @date 30/11/2018
 */
@JS()
import 'dart:html';
//import 'dart:core';
import 'dart:async';

//import 'package:async/async.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'package:pzdart/src/tab/tab_controller.dart';
import 'package:pzdart/src/cti/cti_controller.dart';
import 'package:pzdart/src/cti/pz_account.dart';

final employee = new RegExp(r"employee\$\d+");

@JS('window')
external dynamic get _window;

dynamic getWindowProperty(String name) {
  return getProperty<dynamic>(_window, name);
}

void main() {
  window.console.group('Простые звонки');
  window.console.log('Запускаем модуль интеграции с Простыми звонками');
  window.console.log('Версия контроллера: ${VendorAccount.ver} (${VendorAccount.vendor})');
  window.console.log('Версия контроллера CTI: ${CtiController.ver}');
//  var currentUser = 'employee\$000';
//  String currentUser = context['currentUser']['uuid'];
  dynamic currentUserParams = getWindowProperty('currentUser');
  String sessionHash = getWindowProperty('sessionHash') as String;
  String currentUser = getProperty<String>(currentUserParams, 'uuid');
  if (!employee.hasMatch(currentUser)) {
    window.console.log("Модуль не предназначен для суперпользователя: $currentUser");
    window.console.groupEnd();
    return;
  }
  TabController currentTab = TabController('nsmp').watchWindow().updateSessionHash(sessionHash);
  //  Запускаем на странице контроллер, передаем данные пользователя и вкладку
  VendorAccount.get(currentUser)
      .then((account) => runCTI(account, currentTab, currentUser)).catchError((Error error) {
    window.console.log(error);
  });
  window.console.groupEnd();
}

void runCTI(
    VendorAccount vendorAccount, TabController currentTab, String currentUser) {
  window.console.group('Простые звонки - запуск');
  if (vendorAccount == null) {
    window.console.log("Нет активного аккаунта для пользователя: $currentUser");
    window.console.groupEnd();
    return;
  }
  CtiController ctiController = CtiController(vendorAccount, currentTab);
  if(currentTab.isMaster()) {
    ctiController.connect();
  }
  window.console.groupEnd();
//  Подписываемся на обновления LocalStorage
  window.onStorage.listen(ctiController.storageListener);
//  Для поддержания обратной совместимости Groovy скриптов
//  определяем контекстные переменные для вызова функций
  setProperty<dynamic>(_window, 'pz', jsify(ctiController.bindings));
  setProperty<dynamic>(_window, 'prostiezvonki', jsify(ctiController.bindings));
//  Подписываемся на события вкладки
  currentTab.onActions.listen((tabEvent) async {
    print(tabEvent.type);
    switch (tabEvent.type) {
      case MASTER:
        if(ctiController.connected == false) {
          ctiController.connect();
        }
        break;
      case SLAVE:
        ctiController.disconnect(currentTab.getStack());
        break;
      case REFRESH:
        ctiController.disconnect(currentTab.getStack());
        break;
      case CLOSE:
        ctiController.disconnect(currentTab.getStack());
        break;
      case LOAD:
        break;
      case FOCUS:
        print('ws connection is ${ctiController.connected}');
        if(currentTab.isMaster() && ctiController.connected == false) {
          while(ctiController.connected == false) {
            print('try reconnect to server');
            await Future<Duration>.delayed(const Duration(seconds: 3));
            ctiController.reconnect();
          }
        }
        break;
    }
  });
}
