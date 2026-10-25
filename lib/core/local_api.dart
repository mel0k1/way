import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Loopback-only HTTP API so external tools (scripts, hotkeys, widgets) can
/// drive Way: status, servers, select, connect, disconnect.
///
/// Every request except /ping must carry `Authorization: Bearer <token>`.
class LocalApiServer {
  final Future<Map<String, dynamic>> Function() status;
  final Future<List<Map<String, dynamic>>> Function() servers;
  final Future<void> Function(String id) select;
  final Future<void> Function() connect;
  final Future<void> Function() disconnect;

  HttpServer? _server;
  int port = 20718;
  String token = '';

  LocalApiServer({
    required this.status,
    required this.servers,
    required this.select,
    required this.connect,
    required this.disconnect,
  });

  bool get running => _server != null;

  Future<void> start(int portNumber, String authToken) async {
    await stop();
    port = portNumber;
    token = authToken;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (e) {
      _server = null;
      rethrow;
    }
    _server!.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    try {
      await s?.close(force: true);
    } catch (_) {}
  }

  void _handle(HttpRequest request) async {
    final path = request.uri.path;
    try {
      if (path == '/ping') {
        _json(request, 200, {'app': 'way', 'ok': true, 'port': port});
        return;
      }
      final auth = request.headers.value('authorization') ?? '';
      final expected = 'Bearer $token';
      if (token.isEmpty || auth != expected) {
        _json(request, 401, {'ok': false, 'error': 'unauthorized'});
        return;
      }
      switch (path) {
        case '/status':
          _json(request, 200, await status());
          break;
        case '/servers':
          _json(request, 200, {
            'ok': true,
            'servers': await servers(),
          });
          break;
        case '/select':
          final id = request.uri.queryParameters['id'] ?? '';
          if (id.isEmpty) {
            _json(request, 400, {'ok': false, 'error': 'missing id'});
            break;
          }
          await select(id);
          _json(request, 200, {'ok': true, 'selected': id});
          break;
        case '/connect':
          unawaited(connect());
          _json(request, 200, {'ok': true, 'action': 'connect'});
          break;
        case '/disconnect':
          unawaited(disconnect());
          _json(request, 200, {'ok': true, 'action': 'disconnect'});
          break;
        default:
          _json(request, 404, {'ok': false, 'error': 'not_found'});
      }
    } catch (e) {
      _json(request, 500, {'ok': false, 'error': '$e'});
    } finally {
      unawaited(request.response.drain().catchError((_) {}));
    }
  }

  void _json(HttpRequest request, int code, Map<String, dynamic> body) {
    try {
      request.response.statusCode = code;
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode(body));
      request.response.close();
    } catch (_) {}
  }
}
