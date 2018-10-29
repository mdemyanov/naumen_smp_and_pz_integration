import 'dart:html';
import 'dart:convert';
import 'dart:async';

/// Стандартные константы
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

typedef void StorageEventListener(StorageEvent event);

/// Класс TabController для управления вкладкой
///
/// При создании эксземпляра объекта проверяет наличие в localStorage
/// других вкладок текущего домена. Если вкладок нет - назначает текущую вкладку
/// мастером и запускает планировщик для проверки и обновления времени мастера,
/// если вкладка не является мастером - запускает планировщик для проверки
/// работоспособности мастера.
class TabController {
  static JsonCodec json = const JsonCodec();
  /// Требования к логгированию служебных событий вкладки
  bool _loggingIsEnabled;

  /// Локальное хранилище браузера для домена
  Storage _localStorage;

  /// Локальное хранилище браузера для вкладки
  Storage _sessionStorage;

  /// Префикс для обеспечения уникальности ключей в локальных хранилищах
  String _prefix;

  /// Номер вкладки, по умолчанию 0
  int _tabNumber = new DateTime.now().millisecondsSinceEpoch;

  /// Контроллер для управления событиями  вкладки
  StreamController<CustomEvent> _onTabController;

  /// Временной интервал для обновления времени мастера
  Duration _updatePeriod;

  /// Временной интервал для проверки времени мастера
  Duration _checkPeriod;

  /// Значение в секундах для контроля жизни мастер вкладки
  int _timeDiff;

  /// Признак того, что было принято решении об удалении (закрытии) вкладки.
  bool _removed = false;

  /// Таймер обновления времени мастера
  Timer _updateMasterTime;

  /// Таймер контроля времени мастера
  Timer _checkMasterTime;

  /// Конструктор контроллера вкладки
  ///
  /// Принимет на вход [prefix] для обеспечания уникальности данных,
  /// опциаонально доступна передача [updatePeriod] и [checkPeriod].
  /// Конструктор определяет приватные параметры контроллера вкладки и
  /// инициирует контроллер потока для обмена событиями.
  TabController(String prefix,
      [Duration updatePeriod = const Duration(seconds: 4),
      Duration checkPeriod = const Duration(seconds: 8),
      int timeDiff = 9,
      bool loggingIsEnabled = true]) {
    this._updatePeriod = updatePeriod;
    this._checkPeriod = checkPeriod;
    this._timeDiff = timeDiff;
    this._loggingIsEnabled = loggingIsEnabled;
    this._localStorage = window.localStorage;
    this._sessionStorage = window.sessionStorage;
    this._prefix = prefix;
    this._onTabController = new StreamController<CustomEvent>.broadcast();
  }

  /// Управление событиями вкладки
  ///
  /// Проверяет наличие других вкладок, добавляет текущую вкладку в общий стек.
  /// Вешает обработчики на ключевые события окна (проверка хранилища,
  /// обновление и закрытие вкладки).
  TabController watchWindow() {
    checkLoad();
    window.onStorage.listen(checkStorage);
    window.onFocus.listen(checkFocus);
    window.onBlur.listen(checkBlur);
    window.onUnload.listen(checkUnload);
    window.onBeforeUnload.listen(checkRefresh);
    return this;
  }

  /// Инициатор загрузки вкладки
  ///
  /// Добавляет вкладку в стек, отправляет события о загрузке или новом мастере.
  void checkLoad() {
    addToStorage();
    setActive();
    if (checkMaster()) {
      print('Первая вкладка в стеке - мастер');
      putToLocalStorage('masterTime', new DateTime.now().toIso8601String());
      _onTabController.add(new CustomEvent(MASTER));
    }
    checkMasterTime();
    _onTabController.add(new CustomEvent(LOAD));
  }

  /// Контроль за состоянием локального хранилища
  /// (при изменении на других вкладках)
  ///
  /// Метод используется при подписке на обновления изменений локального
  /// хранилища другими вкладками, на основании которых может:
  /// 1) послать событие для открытия новой вкладки
  /// 2) проверить является ли текущая вкладка новым мастером
  /// 3) проверить жива ли текущая вкладка (возможно ее нет в стеке)
  void checkStorage(StorageEvent event) {
//      Треуется ли открыть новое окно: если, отправляем событие
    if (isWindowToOpen(event)) {
      _onTabController
          .add(new CustomEvent(WIN_TO_OPEN, detail: event.newValue));
    }
//    Проверить обновление стека - нужен ли выбор мастера
    if (checkNewMaster(event)) {
      print("Вкладка ${_tabNumber} стала мастером.");
      putToLocalStorage('masterTime', new DateTime.now().toIso8601String());
      _onTabController.add(new CustomEvent(MASTER));
    }
    if (isDead()) {
      addToStorage();
    }
  }

  /// Обновлять время мастер вкладки
  ///
  /// Метод обновляет время вкладки в локальном хранилище, затем запускает
  /// планировщик, который обновляет время с заданным для вкладки интервалом
  void updateMasterTime() {
    putToLocalStorage('masterTime', new DateTime.now().toIso8601String());
    if (_updateMasterTime?.isActive != true) {
      _updateMasterTime = new Timer.periodic(_updatePeriod, (Timer t) {
        print('updateMasterTime');
        putToLocalStorage('masterTime', new DateTime.now().toIso8601String());
      });
    }
  }

  void checkMasterTime() {
    checkMasterTimeRule(_checkMasterTime);
    if (_checkMasterTime?.isActive != true) {
      _checkMasterTime = new Timer.periodic(_checkPeriod, checkMasterTimeRule);
    }
//            (Timer t) {
//      int master = getMaster();
//      String strMasterTime = getKey('masterTime');
//      List<int> stack = getStack();
//      DateTime masterTime = DateTime.parse(strMasterTime);
//      DateTime now = new DateTime.now();
//      int currentTimeDiff = now.difference(masterTime).inSeconds;
//      print("Вкладка ${_tabNumber} проверяет время: ${now}");
//      if (!isMaster() && currentTimeDiff >= _timeDiff) {
//        print("Время мастера прошло: ${masterTime} - ${now} = ${currentTimeDiff}");
//        removeFromLocalStorage('master');
//        stack.remove(master);
//        putToLocalStorage('stack', JSON.encode(stack));
//        if (stack.length == 1 && checkMaster()) {
//          print("Вкладка ${_tabNumber} стала мастером.");
//          putToLocalStorage('masterTime', new DateTime.now().toIso8601String());
//          _onTabController.add(new CustomEvent(MASTER));
//        }
//      } else if (isMaster()) {
//        updateMasterTime();
//        t.cancel();
//      }
//    }
  }

  /// Правило контроля за временм мастера
  ///
  /// Если время мастера (в секундах) больше текущего на 9 секунд, то правило
  /// удаляет мастер вкладку из стека.
  /// Если текущая вкалдка сама становится мастером - отменяет периодическую
  /// проверку.
  void checkMasterTimeRule(Timer t) {
    // Если вкладка мастер - нет смысла делать проверку
    if (isMaster()) {
      updateMasterTime();
      if (t?.isActive == true) {
        t.cancel();
      }
      return;
    }
    int master = getMaster();
    String strMasterTime = getKey('masterTime');
    List<int> stack = getStack();
    // Если время мастера не установлено - удаляем мастера из стека
    if (strMasterTime == null) {
      print('Время мастера не установлено. Обнуляем стек.');
      stack.remove(master);
      putToLocalStorage('stack', json.encode(stack));
      // Нет смысла в дальнеших шагах, прекращаем работу, но таймер не отменяем
      return;
    }
    // Коневертируем время мастера в тип ДатаВремя
    DateTime masterTime = DateTime.parse(strMasterTime);
    // Получаем текущее значение времени
    DateTime now = new DateTime.now();
    // Определяем значение разницы времени мастера в скундах
    int timeDiff = now.difference(masterTime).inSeconds;
    print("Вкладка ${_tabNumber} проверяет время: ${now}");
    if (!isMaster() && timeDiff >= 9) {
      print("Время мастера ${master} прошло: ${masterTime} - ${now} = ${timeDiff}");
      stack = removeFromStack(master);
      removeFromLocalStorage('master');
      if (checkMaster()) {
        print("Вкладка ${_tabNumber} стала мастером.");
        putToLocalStorage('masterTime', new DateTime.now().toIso8601String());
        _onTabController.add(new CustomEvent(MASTER));
      }
    } else if (isMaster()) {
      updateMasterTime();
      t.cancel();
    }
  }

  /// Реакция на событие фокуса
  ///
  /// Устанавливает текущую вкладку активной в локальном хранилище,
  /// запускает событие фокуса для слушателей вкладки.
  void checkFocus(Event event) {
    setActive();
    _onTabController.add(new CustomEvent(FOCUS));
  }

  /// Реакция на уход с вкладки
  ///
  /// Посылает событие ухода с вкладки
  void checkBlur(Event event) {
    _onTabController.add(new CustomEvent(BLUR));
  }

  /// Реакция на закрытие вкладки
  ///
  /// Удаляет упоминание о вкладке из стека
  void checkUnload(Event event) {
    remove();
    _onTabController.add(new CustomEvent(CLOSE));
  }

  /// Реакция на обновление вкладки
  ///
  /// Удаляет упоминание о вкладке из стека
  void checkRefresh(Event event) {
    remove();
    _onTabController.add(new CustomEvent(REFRESH));
  }

  /// Возвращает поток событий вкладки
  Stream<CustomEvent> get onActions {
//    Возвращаем поток событий
    return _onTabController.stream;
  }

  /// Добавить инфо о вкладке в хранилище
  ///
  /// Получает текущее наполнение стека вкладок и помещает туда ткущую вкладку,
  /// затем помещает инфо о текущей вкладкии в SessionStorage.
  void addToStorage() {
    List<int> stack = getStack();
    print('номер вкладки ${_tabNumber}');
    stack.add(_tabNumber);
    putToLocalStorage('stack', json.encode(stack));
    putToSessionStorage('current', _tabNumber.toString());
  }

  /// Проверка наличия мастера
  ///
  /// Проверяет существование мастера, если матера нет - устанавливает
  /// самую старую вкладку
  bool checkMaster() {
    List<int> stack = getStack();
    if (getKey('master') == null && stack.length == 0) {
      print('Нет упоминаний о мастере, запишем текущую вкладку');
      putToLocalStorage('master', _tabNumber.toString());
      return true;
    }
    if (checkMasterDead()) {
      print('Нет мастера, берем самую старую');
      putToLocalStorage('master', stack.reduce(min).toString());
    }
    return isMaster();
  }
  /// Проверить существование мастера
  ///
  /// Возвращает правду, если нет упоминаний о мастере
  bool checkMasterDead() {
    if (isMaster())
      return false;
    int master = getMaster();
    if (master != null) {
      print("Вкладка ${_tabNumber} ищет мастера ${master}.");
      print("Состояние стека: ${getKey('stack')}");
      return !getStack().contains(getMaster());
    }
    print('Отсутствует запись о мастере!');
    return true;
  }
  /// Проверить стала ли вкладка новым мастером
  ///
  /// Возвращает правду, если вкладка в настоящий момент является мастером
  bool checkNewMaster(StorageEvent event) {
    if (event.key == '$_prefix:master' &&
        (event.newValue == '' || event.newValue == null)) {
      return checkMaster();
    } else if (event.key == '$_prefix:stack' && checkMasterDead()) {
      return checkMaster();
    }
    return false;
  }

  /// Удалить упоминания о вкладке из стека
  ///
  /// Удаляет вкладку из стека, назначает активной самую последнюю вкладку,
  /// кроме того, если вкладка мастер - удаляет упоминание о мастере.
  void remove() {
    _removed = true;
    List<int> stack = removeFromStack(_tabNumber);
    if (stack.length > 0 && (getKey('active') == null)) {
      putToLocalStorage('active', stack.reduce(max).toString());
    } else {
      removeFromLocalStorage('active');
    }
    if (isMaster()) {
      removeFromLocalStorage('master');
    }
  }

  /// Установить текущую вкладку активной
  void setActive() => putToLocalStorage('active', _tabNumber.toString());

  /// Открыть окно
  ///
  /// Открывает новую вкладку с адресом [url] и названием [name]
  void openWindow(String url, String name) => window.open(url, name);

  /// Получить содержимое стека из локального хранилища
  ///
  /// Получает значение stack из localStorage, если значение не пусто,
  /// то преобразует его в коллекцию, в противном случае - возвращает
  /// пустую коллекцию.
  List<int> getStack() {
    String stack = getKey('stack');
    if (stack != null) {
      return json.decode(stack).toList().cast<int>() as List<int>;
    } else {
      putToLocalStorage('stack', '[]');
      return [];
    }
  }
  /// Получить значение из localStorage и привести его к int
  int getIntKey(String key) {
    String value = getKey(key);
    if (value != null) {
      try {
        return int.parse(value);
      } catch (e) {
        print(e.toString());
        return null;
      }
    }
    return null;
  }
  /// Получить значение из localStorage
  String getKey(String key) {
    if (_localStorage.containsKey('$_prefix:$key')) {
      try {
        return _localStorage['$_prefix:$key'];
      } catch (e) {
        print(e.toString());
        return null;
      }
    }
    return null;
  }
  /// Получить значение master из localStorage
  int getMaster() => getIntKey('master');
  /// Получить значение active из localStorage
  int getActive() => getIntKey('active');
  /// Получить значение _prefix
  String getPrefix() => _prefix;
  /// Получить значение window.location.hash
  String getCurrentHash() => window.location.hash;

  /// Установить слушателей изменений в локальном хранилище на вкладке
  void setStorageListener(StorageEventListener listener) => window.onStorage.listen(listener);

  bool isWindowToOpen(StorageEvent event) {
    if (isActive() &&
        event.key == '$_prefix:openWindow' &&
        event.newValue != null) {
      print('${_localStorage['$_prefix:active']} == ${_tabNumber}');
      print('${event.key} == ${event.newValue}');
      return true;
    }
    return false;
  }
  /// Является ли вкладка активной
  ///
  /// Возвращает правду, если вкладка активная или является мастером,
  /// если активной вкладки нет
  bool isActive() {
    int active = getActive();
    if (active != null) {
      return active == _tabNumber;
    }
    return isMaster();
  }
  /// Является ли вкладка мастером
  bool isMaster() => getMaster() == _tabNumber;
  /// Можно ли назначить вкладку мастером
  bool isNewMaster() => getStack().reduce(min) == _tabNumber;
  /// Является ли вкладка мертвой
  ///
  /// Пользователь не закрывал вкладку, но она потерялась из стека
  bool isDead() => !getStack().contains(_tabNumber) && !_removed;
  /// Поместить [value] в ячейку [key] localStorage
  void putToLocalStorage(String key, String value) =>
      _localStorage['$_prefix:$key'] = value;
  /// Поместить [value] в ячейку [key] sessionStorage
  void putToSessionStorage(String key, String value) =>
      _sessionStorage['$_prefix:$key'] = value;
  /// Удалить ключ [key] из localStorage
  void removeFromLocalStorage(String key) =>
      _localStorage.remove('$_prefix:$key');
  /// Удалить ключ [key] из sessionStorage
  void removeFromSessionStorage(String key) =>
      _sessionStorage.remove('$_prefix:$key');
  /// Удалить [number] из стека в локальном хранилище
  List<int> removeFromStack(int number) {
    List<int> stack = getStack();
    stack.remove(number);
    putToLocalStorage('stack', json.encode(stack));
    return stack;
  }
  /// Послать сообщение в консоль
  void print(String message) {
    if (_loggingIsEnabled) {
      window.console.log(message);
    }
  }
}

/// Найти масимальный по значению элемент
int max(int a, int b) => a > b ? a : b;
/// Найти минимальный по значению элемент
int min(int a, int b) => a < b ? a : b;
