import 'package:intl/intl.dart';

final DateFormat formatter = new DateFormat('yyyy.MM.dd HH:mm:ss');

final Map<String,String> eventTypes = {
  '1': 'transfer',
  '2': 'incoming',
  '4': 'history',
  '8': 'outgoing',
  '16': 'outgoingAnswer',
  '32': 'incomingAnswer',
};

class VendorEvent {
  Map<String,String> _sourceData;

  VendorEvent(this._sourceData);

  String _getHistoryParam(String param) {
    if (type == 'history') {
      return _sourceData[param];
    }
    return null;
  }

  String _getDate(String value) {
    if (value != null) {
      DateTime dt = new DateTime.fromMillisecondsSinceEpoch(
          int.parse(value) * 1000,
          isUtc: true);
      return formatter.format(dt);
    }
    return null;
  }

  String get fqn => direction == '1'
      ? 'interaction\$outgoingCall'
      : 'interaction\$incomingCall';

  String get type => eventTypes[_sourceData['type']];

  String get callID => _sourceData['callID'];

  String get from => _sourceData['from'];

  String get to {
    if (type != 'transfer') {
      return _sourceData['to'];
    }
    return null;
  }

  String get start => _getDate(_getHistoryParam('start'));

  String get end => _getDate(_getHistoryParam('end'));

  int get duration {
    String value = _getHistoryParam('duration');
    return value == null ? null : int.parse(value) * 1000;
  }

  String get direction => _getHistoryParam('direction');

  String get record => _getHistoryParam('record');

  Map<String, String> toMap() {
    Map<String, String> data = {};
    switch (type) {
      case 'history':
        data['startTime'] = start;
        data['endTime'] = end;
        data['activeTime'] = duration.toString();
        data['linkToRecord'] = record;
        data['toText'] = to;
        data['fromText'] = from;
        break;
      case 'transfer':
        break;
        default:
          data['toText'] = to;
          data['fromText'] = from;
    }
    return data;
  }
}
