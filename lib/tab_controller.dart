import 'dart:html';
import 'dart:convert';
import 'dart:async';

const String DEFAULT = 'default';
const String LOAD = 'load';
const String MASTER = 'master';
const String SLAVE = 'slave';
const String FOCUS = 'focus';
const String FOCUS_EVENT = 'focusEvent';
const String BLUR = 'blur';
const String CLOSE = 'close';
const String REFRESH = 'refresh';
const String WIN_TO_OPEN = 'windowToOpen';

class TabController {
  Window _window;
  Storage _localStorage;
  Storage _sessionStorage;
  String _prefix;
  int _tabNumber = 0;
  StreamController _onTabController;
  List<String> _listenOnFocus;

  TabController(Window window, String prefix,
      [List<String> listenOnFocus = const []]) {
    this._window = window;
    this._localStorage = _window.localStorage;
    this._sessionStorage = _window.sessionStorage;
    this._prefix = prefix;
    this._onTabController = new StreamController.broadcast();
    this._listenOnFocus = listenOnFocus;
  }
// Определяем события для контроля
  void watchWindow() {
    _window.onLoad.listen(checkLoad);
    _window.onStorage.listen(checkStorage);
    _window.onFocus.listen(checkFocus);
    _window.onBlur.listen(checkBlur);
    _window.onUnload.listen(checkUnload);
    _window.onBeforeUnload.listen(checkRefresh);
  }

// Проверим вкладку после загрузки
  void checkLoad(Event event) {
    addToStorage();
    setActive();
    if (checkMaster()) {
      _onTabController.add(new CustomEvent(MASTER));
    }
    _onTabController.add(new CustomEvent(LOAD));
  }
//  Следим за обновлениями на других вкладках
  void checkStorage(StorageEvent event) {
//      Треуется ли открыть новое окно: если, отправляем событие
    if (isWindowToOpen(event)) {
      _onTabController
          .add(new CustomEvent(WIN_TO_OPEN, detail: event.newValue));
    }
//    Проверить обновление стека - нужен ли выбор мастера
    if (checkUpdates(event)) {
      _onTabController.add(new CustomEvent(MASTER));
    } else if (isMaster() == false) {
      _onTabController.add(new CustomEvent(SLAVE));
    }
    if (checkFocusEvents(event)) {
      _onTabController.add(new CustomEvent(FOCUS, detail: event));
    }
  }
// Вкладка в фокусе
  void checkFocus(Event event) {
    setActive();
    _onTabController.add(new CustomEvent(FOCUS));
  }
// Фокус ушел с вкладки
  void checkBlur(Event event) {
    _onTabController.add(new CustomEvent(BLUR));
  }
//    Пользователь закрыл вкладку
  void checkUnload(Event event) {
    remove();
    _onTabController.add(new CustomEvent(CLOSE));
  }
  //    Пользователь обновил вкладку
  void checkRefresh(Event event) {
    remove();
    _onTabController.add(new CustomEvent(REFRESH));
  }
// Поток событий на вкладке
  Stream<CustomEvent> get onActions {
//    Вешаем обработчик событйи на вкладке
    watchWindow();
//    Возвращаем поток событий
    return _onTabController.stream;
  }

  void addToStorage() {
    List<int> stack = [];
    if (_localStorage.containsKey('$_prefix:stack')) {
      try {
        stack = getStack();
        if (stack.length > 0) {
          _tabNumber = stack.reduce(max) + 1;
        }
      } catch (e) {
        print('Ошибка при получении стека и номера вкладки: ${e.toString()}');
      }
    }
    stack.add(_tabNumber);
    _sessionStorage['$_prefix:current'] = _tabNumber.toString();
    _localStorage['$_prefix:stack'] = JSON.encode(stack);
  }

  bool checkMaster() {
    if (!_localStorage.containsKey('$_prefix:master')) {
      _localStorage['$_prefix:master'] = _tabNumber.toString();
      return true;
    }
    if (_localStorage['$_prefix:master'] == '' || checkMasterDead()) {
      List<int> stack = getStack();
      _localStorage['$_prefix:master'] = stack.reduce(min).toString();
    }
    return getMaster() == _tabNumber;
  }

  bool checkMasterDead() {
    if (_localStorage.containsKey('$_prefix:master')) {
      return !getStack().contains(getMaster());
    }
    return false;
  }

  void remove() {
    List<int> stack = getStack();
    stack.remove(_tabNumber);
    _localStorage['$_prefix:stack'] = JSON.encode(stack);
    if(stack.length > 0 && (!_localStorage.containsKey('$_prefix:active') || _localStorage['$_prefix:active'] == 'null')) {
      _localStorage['$_prefix:active'] = stack.reduce(max).toString();
    } else {
      _localStorage.remove('$_prefix:active');
    }
    if (_localStorage['$_prefix:master'] == _tabNumber.toString()) {
      _localStorage.remove('$_prefix:master');
    }
  }

  void setActive() {
    _localStorage['$_prefix:active'] = _tabNumber.toString();
  }

  void openWindow(String url, String name) => _window.open(url, name);

  List<int> getStack() {
    if (_localStorage.containsKey('$_prefix:stack')) {
      return JSON.decode(_localStorage['$_prefix:stack']);
    } else {
      putToLocalStorage('stack', '[]');
      return [];
    }
  }

  int getIntKey(String key) {
    if(_localStorage.containsKey('$_prefix:$key')) {
      try {
        return int.parse(_localStorage['$_prefix:$key']);
      } catch(e) {
        print(e);
        return 0;
      }
    }
    return 0;
  }
  int getMaster() => getIntKey('master');
  int getActive() => getIntKey('active');


  String getPrefix() => _prefix;

  void setStorageListener(listener) => _window.onStorage.listen(listener);

  bool checkUpdates(StorageEvent event) {
    if (event.key == '$_prefix:master' && (event.newValue == '' || event.newValue == null)) {
      return checkMaster();
    } else if (checkMasterDead()) {
      return checkMaster();
    }
    return false;
  }

  bool isWindowToOpen(StorageEvent event) {
    if (_localStorage['$_prefix:active'] == _tabNumber.toString() &&
        event.key == '$_prefix:openWindow' &&
        event.newValue != null) {
      print('${_localStorage['$_prefix:active']} == ${_tabNumber}');
      print('${event.key} == ${event.newValue}');
      return true;
    }
    return false;
  }

  bool isActive() {
    if (_localStorage.containsKey('$_prefix:active') && _localStorage['$_prefix:active'] != null) {
      return _localStorage['$_prefix:active'] == _sessionStorage['$_prefix:current'];
    } else if (_localStorage.containsKey('$_prefix:master')) {
      return _localStorage['$_prefix:master'] == _sessionStorage['$_prefix:current'];
    } else {
      _window.console.error('Нет ни мастера ни активной вкладки!');
      return false;
    }
  }

  bool isMaster() =>
      _localStorage['$_prefix:master'] == _sessionStorage['$_prefix:current'];

  void putToLocalStorage(String key, String value) {
    _localStorage['$_prefix:$key'] = value;
  }

  void removeFromLocalStorage(String key) =>
      _localStorage.remove('$_prefix:$key');

  bool checkFocusEvents(StorageEvent event) =>
      _listenOnFocus.contains(event.key) ? event.newValue != null : false;
}

int max(int a, int b) => a > b ? a : b;

int min(int a, int b) => a < b ? a : b;
