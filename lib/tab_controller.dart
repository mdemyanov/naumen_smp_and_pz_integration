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
  int _tabNumber;
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

  Stream<CustomEvent> get onActions {
//    Действия на загрузку окна
    _window.onLoad.listen((event) {
      addToStorage();
      if (checkMaster()) {
        _onTabController.add(new CustomEvent(MASTER));
      }
      setActive();
      _onTabController.add(new CustomEvent(LOAD));
    });
//    Действия на обновление localStorage в других вкладках
    window.onStorage.listen((event) {
//      Треуется ли открыть новое окно: если, отправляем событие
      if (isWindowToOpen(event)) {
        _onTabController.add(new CustomEvent(WIN_TO_OPEN, detail: event.newValue));
      }
//    Проверить обновление стека - нужен ли выбор мастера
      if (checkUpdates(event)) {
        _onTabController.add(new CustomEvent(MASTER));
      } else if(isMaster() == false){
        _onTabController.add(new CustomEvent(SLAVE));
      }
      if (checkFocusEvents(event)) {
        _onTabController.add(new CustomEvent(FOCUS, detail: event));
      }
    });
//    Если в фокусе
    _window.onFocus.listen((event) {
      setActive();
      _onTabController.add(new CustomEvent(FOCUS));
    });
//    Если ушли с фокуса
    _window.onBlur.listen((event) {
      _onTabController.add(new CustomEvent(BLUR));
    });
//    Пользователь закрыл вкладку
    _window.onUnload.listen((event) {
      remove();
      _onTabController.add(new CustomEvent(CLOSE));
    });
//    Пользователь обновляет вкладку
    _window.onBeforeUnload.listen((event) {
      remove();
      _onTabController.add(new CustomEvent(REFRESH));
    });
//    Возвращаем поток событий
    return _onTabController.stream;
  }

  void addToStorage() {
    List<int> stack = [];
    if (_localStorage.containsKey('$_prefix:stack')) {
      try {
        stack = JSON.decode(_localStorage['$_prefix:stack']);
        _tabNumber = stack.reduce(max) + 1;
      } catch (e) {
        _tabNumber = 0;
      }
    } else {
      _tabNumber = 0;
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
      List<int> stack = JSON.decode(_localStorage['$_prefix:stack']);
      _localStorage['$_prefix:master'] = stack.reduce(min).toString();
    }
    return _localStorage['$_prefix:master'] == _tabNumber.toString();
  }

  bool checkMasterDead() {
    if(_localStorage.containsKey('$_prefix:master')) {
      return !getStack().contains(getMaster());
    }
    return false;
  }

  void remove() {
    List<int> stack = JSON.decode(_localStorage['$_prefix:stack']);
    stack.remove(_tabNumber);
    _localStorage['$_prefix:stack'] = JSON.encode(stack);
    _localStorage['$_prefix:active'] = stack.reduce(max).toString();
    if (_localStorage['$_prefix:master'] == _tabNumber.toString()) {
      _localStorage['$_prefix:master'] = '';
    }
  }

  void setActive() {
    _localStorage['$_prefix:active'] = _tabNumber.toString();
  }

  void openWindow(String url, String name) => _window.open(url, name);

  List<int> getStack() => JSON.decode(_localStorage['$_prefix:stack']);

  int getMaster() => int.parse(_localStorage['$_prefix:master']);

  String getPrefix() => _prefix;

  void setStorageListener(listener) => _window.onStorage.listen(listener);

  bool checkUpdates(StorageEvent event) {
    if (event.key == '$_prefix:master' && event.newValue == '') {
      return checkMaster();
    } else if(checkMasterDead()) {
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

  bool isActive() => _localStorage['$_prefix:active'] == _sessionStorage['$_prefix:current'];
  bool isMaster() => _localStorage['$_prefix:master'] == _sessionStorage['$_prefix:current'];

  void putToLocalStorage(String key, String value) {
    _localStorage['$_prefix:$key'] = value;
  }
  void removeFromLocalStorage(String key) => _localStorage.remove('$_prefix:$key');

  bool checkFocusEvents(StorageEvent event) =>
      _listenOnFocus.contains(event.key) ? event.newValue != null : false;
}

int max(int a, int b) => a > b ? a : b;

int min(int a, int b) => a < b ? a : b;
