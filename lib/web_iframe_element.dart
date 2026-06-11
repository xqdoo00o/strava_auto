import 'package:web/web.dart' as web;

web.HTMLIFrameElement createEmbeddedIframe({
  required String src,
  required String title,
}) {
  return web.HTMLIFrameElement()
    ..src = src
    ..title = title
    ..style.cssText = '''
      width: 100%;
      height: 100%;
      border: 0;
      display: block;
    '''
    ..setAttribute('referrerpolicy', 'origin')
    ..setAttribute('allow', 'storage-access');
}
