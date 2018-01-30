import 'dart:html';

final String nsmpNotifierContainer = '''
    z-index: 999;
    position: fixed;
    top: 4px;
    right: 4px;
    padding: 4px;
    width: 350px;
    max-width: 98%;
    font-family: "Segoe UI",Tahoma,Calibri,Verdana,sans-serif;
    color: #999;
    -webkit-box-sizing: border-box;
    -moz-box-sizing: border-box;
    -ms-box-sizing: border-box;
    box-sizing: border-box''';

DivElement getNotifier(String x, String y) {
  DivElement notifier = new Element.tag('div');
  notifier.id = 'nsmp-notifier-container';
  notifier.setAttribute('style', nsmpNotifierContainer);
  return notifier;
}
