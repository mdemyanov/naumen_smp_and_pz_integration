
class NsmpResponse {
  String result;
  String error;
  Data data;

  NsmpResponse.fromJson(Map<String, dynamic> json) {
    result = json['result'] as String;
    if (result == 'ok') {
      data = Data.fromJson(json['data'] as Map<String, dynamic>);
    } else {
      error = json['error'] as String;
    }
  }
}

class Data {
  final String UUID, title, action;

  Data.fromJson(Map<String, dynamic> json)
      : UUID = json['UUID'] as String,
        title = json['title'] as String,
        action = json['action'] as String;
}
