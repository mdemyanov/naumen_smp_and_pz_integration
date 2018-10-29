import 'dart:html';
import 'dart:core';
import 'dart:js';

import 'package:pzdart/src/tab/tab_controller.dart';
import 'package:pzdart/src/cti/cti_controller.dart';
import 'package:pzdart/src/cti/pz_account.dart';

final employee = new RegExp(r"employee\$\d+");

void main() {
  print('Запускаем модуль интеграции с Простыми звонками');
//  var currentUser = 'employee\$000';
  String currentUser = context['currentUser']['uuid'];
  if (!employee.hasMatch(currentUser)) {
    print("Модуль не предназначен для суперпользователя: $currentUser");
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
    print("Нет активного аккаунта для пользователя: $currentUser");
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
  context['pz'] = new JsObject.jsify(ctiController.bindings);
  context['prostiezvonki'] = context['pz'];
  ;
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
