/**
 * @signedBy mdemyanov
 * @date 30/11/2018
 */
import 'dart:html';
import 'dart:core';

import 'package:js/js_util.dart' as js;

import 'package:pzdart/src/tab/tab_controller.dart';
import 'package:pzdart/src/cti/cti_controller.dart';
import 'package:pzdart/src/cti/pz_account.dart';
/**
 * @signedBy mdemyanov
 * @date 30/11/2018
 * 33456
 */
final employee = new RegExp(r"employee\$\d+");

void main() {
  window.console.group('Простые звонки');
  window.console.log('Запускаем модуль интеграции с Простыми звонками');
  window.console.log('Версия контроллера: ${VendorAccount.ver} (${VendorAccount.vendor})');
  window.console.log('Версия контроллера CTI: ${CtiController.ver}');
//  var currentUser = 'employee\$000';
//  String currentUser = context['currentUser']['uuid'];
  dynamic currentUserParams = js.getProperty(window, 'currentUser');
  String currentUser = js.getProperty(currentUserParams, 'uuid') as String;
  if (!employee.hasMatch(currentUser)) {
    window.console.log("Модуль не предназначен для суперпользователя: $currentUser");
    window.console.groupEnd();
    return;
  }
  TabController currentTab = TabController('nsmp').watchWindow();
  //  Запускаем на странице контроллер, передаем данные пользователя и вкладку
  VendorAccount.get(currentUser)
      .then((account) => runCTI(account, currentTab, currentUser));
}

void runCTI(
    VendorAccount vendorAccount, TabController currentTab, String currentUser) {
  if (vendorAccount == null) {
    window.console.log("Нет активного аккаунта для пользователя: $currentUser");
    window.console.groupEnd();
    return;
  }
  CtiController ctiController = CtiController(vendorAccount, currentTab);
  if(currentTab.isMaster()) {
    ctiController.connect();
  }

//  Подписываемся на обновления LocalStorage
  window.onStorage.listen(ctiController.storageListener);
//  Для поддержания обратной совместимости Groovy скриптов
//  определяем контекстные переменные для вызова функций
  js.setProperty(window, 'pz', js.jsify(ctiController.bindings));
  js.setProperty(window, 'prostiezvonki', js.jsify(ctiController.bindings));
//  Подписываемся на события вкладки
  currentTab.onActions.listen((tabEvent) async {
    print(tabEvent.type);
    switch (tabEvent.type) {
      case MASTER:
        ctiController.connect();
        break;
      case SLAVE:
        ctiController.disconnect();
        break;
      case REFRESH:
        ctiController.disconnect();
        break;
      case CLOSE:
        ctiController.disconnect();
        break;
      case LOAD:
        break;
    }
  });
}
