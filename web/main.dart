import 'dart:html';
import 'dart:core';
import 'dart:js';

import 'package:pzdart/tab_controller.dart';
import 'package:pzdart/cti_controller.dart';
import 'package:pzdart/pz_controller.dart';

final employee = new RegExp(r"employee\$\d+");

main() async {
  var currentUser = context['currentUser']['uuid'];
  if (!employee.hasMatch(currentUser)) {
    print("Модуль не предназначен для суперпользователя: $currentUser");
    return;
  }
  VendorController vendorController;
  //  Запускаем на странице контроллер, передаем данные пользователя и вкладку

  CtiController ctiController =
      new CtiController(context['currentUser']['uuid']);
  Map acc = await ctiController.getAccount(VendorController.getVendor());

  if (acc.length == 0) {
    print("Нет активного аккаунта для пользователя: $currentUser -- ${acc
        .toString()}");
    return;
  }

  TabController currentTab = new TabController(window, 'nsmp');
  ctiController.setTab(currentTab);

//  Подписываемся на обновления LocalStorage
  window.onStorage.listen(ctiController.storageListener);
//  Для поддержания обратной совместимости Groovy скриптов
//  определяем контекстные переменные для вызова функций
  context['pz'] = new JsObject.jsify(ctiController.getBindings());
  context['prostiezvonki'] = context['pz'];
  ;
//  Подписываемся на события вкладки
  currentTab.onActions.listen((tabEvent) async {
    print(tabEvent.type);
    switch (tabEvent.type) {
      case MASTER:
        try {
          vendorController = new VendorController.fromJson(acc);
//          Для тестирования: получаем учетку из MAP
//          vendorController = new VendorController.fromJson(ncc);
//          Если есть контакт подписываемся на события
          if (await vendorController.connect()) {
            ctiController.setConnected();
            ctiController
                .addCallActionListener(vendorController.actionListener);
            vendorController.addEventListener(ctiController.eventListener);
//            vendorController.events.listen((event) => print(event.type));
          }
        } catch (e) {
          window.console.error(e);
        }
        break;
      case SLAVE:
        break;
      case REFRESH:
        vendorController.disconnect();
        break;
      case CLOSE:
        vendorController.disconnect();
        break;
      case LOAD:
        break;
    }
  });
}

//Map acc = {
//  "login": "3015",
//  'password': "449370",
//  'url': "wss://softphone.prostiezvonki.ru:443"
//};
