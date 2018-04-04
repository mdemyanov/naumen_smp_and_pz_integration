import 'dart:html';
import 'dart:core';
import 'dart:js';
import 'dart:async';

import 'package:pzdart/tab_controller.dart';
import 'package:pzdart/cti_controller.dart';
import 'package:pzdart/pz_controller.dart';

final employee = new RegExp(r"employee\$\d+");

main() async {
  print('Запускаем модуль интеграции с Простыми звонками');
//  var currentUser = 'employee\$000';
  var currentUser = context['currentUser']['uuid'];
  if (!employee.hasMatch(currentUser)) {
    print("Модуль не предназначен для суперпользователя: $currentUser");
    return;
  }
  TabController currentTab = new TabController('nsmp').watchWindow();
  //  Запускаем на странице контроллер, передаем данные пользователя и вкладку
  CtiController ctiController =
      new CtiController(currentUser);
  Map acc = await ctiController.getAccount(VendorController.getVendor());


  if (acc.length == 0) {
    print("Нет активного аккаунта для пользователя: $currentUser -- ${acc
        .toString()}");
    return;
  }

  ctiController.setTab(currentTab);
  VendorController vendorController = await connect(ctiController, acc, currentTab.isMaster(), null);

//  Подписываемся на обновления LocalStorage
  window.onStorage.listen(ctiController.storageListener);
//  Для поддержания обратной совместимости Groovy скриптов
//  определяем контекстные переменные для вызова функций
  context['pz'] = new JsObject.jsify(ctiController.getBindings());
  context['prostiezvonki'] = context['pz'];
  if(vendorController != null) {
    context['debugDD'] = new JsObject.jsify(vendorController.getBindings());
  }
  ;
//  Подписываемся на события вкладки
  currentTab.onActions.listen((tabEvent) async {
    print(tabEvent.type);
    switch (tabEvent.type) {
      case MASTER:
        vendorController = await connect(ctiController, acc, currentTab.isMaster(), vendorController);
        if(vendorController != null) {
          context['debugDD'] = new JsObject.jsify(vendorController.getBindings());
        }
        break;
      case SLAVE:
        vendorController.disconnect();
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

Future<VendorController> connect(CtiController ctiController, Map acc, bool isMaster, VendorController vendorController) async{
  if(isMaster && vendorController == null) {
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
      }
    } catch (e) {
      window.console.error(e);
    }
  }
  return vendorController;
}

Map acc1 = {
  "login": "3015",
  'password': "449370",
  'url': "wss://softphone.prostiezvonki.ru:443"
};
