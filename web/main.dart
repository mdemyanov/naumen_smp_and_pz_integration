import 'dart:html';
import 'dart:core';
import 'dart:js';

import 'package:pzdart/tab_controller.dart';
import 'package:pzdart/cti_controller.dart';
import 'package:pzdart/vendor_controller.dart';

main() async {
  VendorController vendorController;
  TabController currentTab = new TabController(window, 'nsmp');
//  Запускаем на странице контроллер, передаем данные пользователя и вкладку
  CtiController ctiController = new CtiController(context['currentUser']['uuid'], currentTab);
//  Подписываемся на обновления LocalStorage
  window.onStorage.listen(ctiController.storageListener);
//  Для поддержания обратной совместимости Groovy скриптов
//  определяем контекстные переменные для вызова функций
  context['pz'] = new JsObject.jsify(ctiController.getBindings());
  context['prostiezvonki'] = context['pz'];
//  Подписываемся на события вкладки
  currentTab.onActions.listen((tabEvent) async {
    switch (tabEvent.type) {
      case MASTER:
        try {
          vendorController = new VendorController.fromJson(
              await ctiController.getAccount(VendorController.getVendor())
          );
//          Для тестирования: получаем учетку из MAP
//          vendorController = new VendorController.fromJson(acc);
//          Если есть контакт подписываемся на события
          if(vendorController.connect()){
            ctiController.setConnected();
            ctiController.addCallActionListener(vendorController.actionListener);
            vendorController.addEventListener(ctiController.eventListener);
          }
        } catch(e) {
          window.console.error(e);
        }
        break;
//      case SLAVE:
//      case REFRESH:
//      case CLOSE:
//      case LOAD:
//      case FOCUS:
//      case BLUR:
//      case DEFAULT:
    }
  });
}
Map acc = {
  "login":"3015",
  'password': "449370",
  'url': "wss://softphone.prostiezvonki.ru:443"
};
