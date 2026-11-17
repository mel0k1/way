import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum PhoneImportPhase { idle, waiting, received, expired, locked, failed }

class PhoneImportState {
  final PhoneImportPhase phase;
  final String url;
  final String pin;
  final String? payload;

  /// Wallpaper mode only: the temp file the image landed in.
  final String? wallpaperPath;

  const PhoneImportState(
    this.phase, {
    this.url = '',
    this.pin = '',
    this.payload,
    this.wallpaperPath,
  });
}

/// Receives a config: or, in wallpaper mode, an image: from a phone over
/// the local network, Chumpy-style: a QR with the LAN URL, a 6-digit PIN
/// as the proof, a self-contained HTML page on the phone side and a single
/// POST with the payload (text/plain for configs, application/octet-stream
/// for wallpapers). The session lives 5 minutes and closes itself after the
/// first accepted payload or 8 bad PIN attempts.
class PhoneImportServer {
  static const _lifetime = Duration(minutes: 5);
  static const _maxBody = 256 * 1024;
  static const _maxImage = 40 * 1024 * 1024;

  final bool wallpaper;

  PhoneImportServer({this.wallpaper = false});

  final _state =
      ValueNotifier<PhoneImportState>(const PhoneImportState(PhoneImportPhase.idle));
  ValueListenable<PhoneImportState> get state => _state;

  HttpServer? _server;
  Timer? _timer;
  String _session = '';
  String _pin = '';
  String _origin = '';
  int _badAttempts = 0;
  bool _closed = false;

  Future<void> start() async {
    final ip = await _lanAddress();
    if (ip == null) throw StateError('no_lan');
    final rng = Random.secure();
    _session = List.generate(
      24,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _pin = (100000 + rng.nextInt(900000)).toString();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    _origin = 'http://${ip.address}:${server.port}';
    _closed = false;
    _state.value = PhoneImportState(
      PhoneImportPhase.waiting,
      url: _origin,
      pin: _pin,
    );
    _timer = Timer(_lifetime, _expire);
    unawaited(_serve(server));
  }

  Future<void> stop() async {
    _closed = true;
    _timer?.cancel();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  void _expire() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _server?.close(force: true);
    _server = null;
    _state.value = PhoneImportState(
      PhoneImportPhase.expired,
      url: _origin,
      pin: _pin,
    );
  }

  static Future<InternetAddress?> _lanAddress() async {
    final itfs = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final itf in itfs) {
      for (final address in itf.addresses) {
        if (!address.isLoopback && !address.isLinkLocal) return address;
      }
    }
    return null;
  }

  static bool _constantEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        if (_closed) break;
        unawaited(_handle(request));
      }
    } catch (_) {
      // listener torn down: the state notifier already said why
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final authority = _origin.substring('http://'.length);
      final host = request.headers.value('host');
      final origin = request.headers.value('origin');
      // Anti-DNS-rebind: the Host must be our own authority; foreign
      // origins are refused outright.
      if (host != authority || (origin != null && origin != _origin)) {
        return _respond(request, 403, 'Forbidden');
      }
      if (request.method == 'GET' && request.uri.path == '/') {
        return _respond(
          request,
          200,
          (wallpaper ? _wallpaperPage : _page).replaceFirst(
            '__WAY_SESSION__',
            _session,
          ),
          'text/html; charset=utf-8',
        );
      }
      if (request.method != 'POST' || request.uri.path != '/import') {
        return _respond(request, 404, 'Not found');
      }
      if (_closed) {
        return _respond(request, 410, 'Session closed');
      }
      if (origin != _origin ||
          request.headers.value('x-way-session') != _session) {
        return _respond(request, 403, 'Invalid session');
      }
      final auth = request.headers.value('authorization') ?? '';
      final credential =
          auth.startsWith('Bearer ') ? auth.substring(7) : '';
      if (!_constantEq(credential, _pin)) {
        _badAttempts++;
        if (_badAttempts >= 8) {
          _expire();
          return _respond(request, 429, 'Session locked');
        }
        return _respond(request, 401, 'Invalid code');
      }
      final expectedType = wallpaper ? 'application/octet-stream' : 'text/plain';
      final maxPayload = wallpaper ? _maxImage : _maxBody;
      final contentType =
          (request.headers.value('content-type') ?? '').split(';').first.trim();
      if (contentType != expectedType ||
          request.headers.value('transfer-encoding') != null) {
        return _respond(request, 413, 'Invalid payload');
      }
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
        if (bytes.length > maxPayload) {
          return _respond(request, 413, 'Too large');
        }
      }
      if (wallpaper) {
        if (bytes.isEmpty) return _respond(request, 400, 'Empty payload');
        return _acceptImage(request, bytes);
      }
      final body = utf8.decode(bytes, allowMalformed: true).trim();
      if (body.isEmpty) return _respond(request, 400, 'Empty payload');
      return _accept(request, PhoneImportState(
        PhoneImportPhase.received,
        url: _origin,
        pin: _pin,
        payload: body,
      ));
    } catch (_) {
      try {
        _respond(request, 400, 'Bad request');
      } catch (_) {}
    }
  }

  /// Wallpaper mode: the image lands in a temp file, the state carries its
  /// path; the app copies it into place and the temp dies with the session.
  Future<void> _acceptImage(HttpRequest request, List<int> bytes) async {
    try {
      final tmp = await Directory.systemTemp.createTemp('way-phone-wallpaper');
      final file = File('${tmp.path}/wallpaper.upload');
      await file.writeAsBytes(bytes, flush: true);
      await _accept(request, PhoneImportState(
        PhoneImportPhase.received,
        url: _origin,
        pin: _pin,
        wallpaperPath: file.path,
      ));
    } catch (_) {
      try {
        _respond(request, 500, 'Storage error');
      } catch (_) {}
    }
  }

  Future<void> _accept(HttpRequest request, PhoneImportState state) async {
    _closed = true;
    _timer?.cancel();
    final server = _server;
    _server = null;
    await server?.close(force: true);
    _state.value = state;
    return _respond(request, 202, 'Accepted');
  }

  void _respond(
    HttpRequest request,
    int status,
    String body, [
    String type = 'text/plain; charset=utf-8',
  ]) {
    request.response.statusCode = status;
    request.response.headers.set('Content-Type', type);
    request.response.headers.set('Cache-Control', 'no-store');
    request.response.headers.set('Referrer-Policy', 'no-referrer');
    request.response.headers.set('X-Content-Type-Options', 'nosniff');
    request.response.headers.set('X-Frame-Options', 'DENY');
    request.response.writeln(body);
    unawaited(request.response.close());
  }

  /// Adapted from Chumpy's phone_import.html (MIT), minus the logo.
  static const _page = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Way</title>
<style>
*{box-sizing:border-box}[hidden]{display:none!important}body{font:18px system-ui,sans-serif;min-height:100vh;min-height:100svh;margin:0;padding:2rem 1.2rem;display:grid;grid-template-columns:minmax(0,1fr);place-items:center;background:#f5f7fa;color:#17212b;text-align:center}main{width:100%;min-width:0;max-width:36rem;overflow-wrap:anywhere}h1{font-size:2rem;margin:0}input,textarea{text-align:center}label{display:block;margin-top:1.4rem}textarea,input,button{box-sizing:border-box;font:inherit;width:100%;padding:.9rem;border:1px solid #687782;border-radius:12px;margin-top:.6rem}textarea{min-height:12rem;resize:vertical}button{background:#2f5d50;color:white;border:0;cursor:pointer}button:disabled{opacity:.6}p{line-height:1.5}#status{min-height:3rem}input:focus,textarea:focus,button:focus{outline:3px solid #6fac6d;outline-offset:3px}
</style>
<main><h1>Way</h1><p id="intro"></p>
<form id="form"><label id="codeLabel"><span id="codeText"></span><input id="code" required inputmode="numeric" autocomplete="off" maxlength="6" pattern="[0-9]{6}"></label>
<label><span id="linkText"></span><textarea id="link" required maxlength="262144" autocomplete="off" autocapitalize="off" spellcheck="false"></textarea></label>
<button id="send" type="submit" disabled></button></form><p id="status" role="status" aria-live="polite"></p>
</main>
<script>
const ru=navigator.language.toLowerCase().startsWith('ru');
const t=ru?{intro:'Вставь ссылку подписки или конфигурацию. После отправки подтверди импорт в приложении Way. Данные передаются напрямую по локальной сети.',expired:'Приём закрыт. Открой его заново в Way и отсканируй новый QR-код.',code:'Код с экрана Way',link:'Ссылка или конфигурация',send:'Отправить в Way',sending:'Отправка…',ok:'Отправлено. Подтверди импорт в Way.',bad:'Неверный код. Проверь код на экране Way.',locked:'Слишком много попыток. Закрой и снова открой приём в Way.',large:'Слишком большой или пустой текст.',failed:'Не удалось отправить. Проверь общую Wi-Fi/локальную сеть и снова открой приём в Way.'}:{intro:'Paste a subscription link or configuration, then confirm the import in Way. Data is sent directly over your local network.',expired:'Reception is closed. Reopen it in Way and scan the new QR code.',code:'Code shown in Way',link:'Link or configuration',send:'Send to Way',sending:'Sending…',ok:'Sent. Confirm the import in Way.',bad:'Incorrect code. Check the code shown in Way.',locked:'Too many attempts. Close and reopen the receiver in Way.',large:'The text is empty or too large.',failed:'Could not send. Check that both devices share a Wi-Fi/local network and reopen the receiver in Way.'};
history.replaceState(null,'',location.pathname);
document.documentElement.lang=ru?'ru':'en';
for(const [id,key] of [['intro','intro'],['codeText','code'],['linkText','link'],['send','send']])document.getElementById(id).textContent=t[key];

const session='__WAY_SESSION__';
const form=document.getElementById('form');
const code=document.getElementById('code');
const button=document.getElementById('send');
const status=document.getElementById('status');
const fields=Array.from(form.querySelectorAll('input,textarea'));
let sending=false,finished=false,currentRequest=null;
function validPayload(){const text=document.getElementById('link').value.trim();return !!text&&new TextEncoder().encode(text).length<=262144;}
function updateForm(){
 fields.forEach(field=>{field.disabled=sending||finished;});
 button.disabled=sending||finished||!code.validity.valid||!validPayload();
}
form.addEventListener('input',updateForm);
form.addEventListener('change',updateForm);
window.addEventListener('pagehide',()=>{finished=true;currentRequest?.abort();updateForm();});

form.addEventListener('submit',async event=>{
 event.preventDefault();
 if(sending||finished)return;
 if(!form.reportValidity()||!/^[0-9]{6}\$/.test(code.value.trim())||!validPayload()){updateForm();return;}
 const credential=code.value.trim();
 const body=document.getElementById('link').value.trim();
 sending=true;updateForm();status.textContent=t.sending;
 const controller=new AbortController();currentRequest=controller;
 const timer=setTimeout(()=>controller.abort(),10000);
 try{
  const response=await fetch('/import',{method:'POST',credentials:'omit',cache:'no-store',redirect:'error',
   headers:{'Content-Type':'text/plain;charset=UTF-8','Authorization':'Bearer '+credential,'X-Way-Session':session},body,signal:controller.signal});
  if(response.status===202){
   finished=true;status.textContent=t.ok;
   document.getElementById('link').value='';
   code.value='';
  }else if(response.status===401){code.value='';status.textContent=t.bad;}
  else if(response.status===429){finished=true;status.textContent=t.locked;}
  else if(response.status===403||response.status===410){finished=true;status.textContent=t.expired;}
  else status.textContent=response.status===413?t.large:t.failed;
 }catch{if(!finished)status.textContent=t.failed;}
 finally{clearTimeout(timer);currentRequest=null;sending=false;updateForm();}
});
updateForm();
</script></html>
''';

  /// Wallpaper mode, adapted from Chumpy's phone_wallpaper.html (MIT):
  /// file picker with a live preview, 40 MiB guard on the client side and
  /// the image sent as one octet-stream body.
  static const _wallpaperPage = '''
<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Way</title>
<style>
*{box-sizing:border-box}[hidden]{display:none!important}body{font:18px system-ui,sans-serif;min-height:100vh;min-height:100svh;margin:0;padding:2rem 1.2rem;display:grid;grid-template-columns:minmax(0,1fr);place-items:center;background:#f5f7fa;color:#17212b;text-align:center}main{width:100%;min-width:0;max-width:36rem;overflow-wrap:anywhere}h1{font-size:2rem;margin:0}img{max-width:100%;max-height:16rem;border-radius:12px;margin-top:1.2rem}input,button{box-sizing:border-box;font:inherit;width:100%;padding:.9rem;border:1px solid #687782;border-radius:12px;margin-top:.6rem;text-align:center}button{background:#2f5d50;color:white;border:0;cursor:pointer}button:disabled{opacity:.6}p{line-height:1.5}#status{min-height:3rem}.file-picker{position:relative;display:block;margin-top:.6rem;padding:1rem 1.2rem;border:1px solid #687782;border-radius:12px;background:#e5edf5;color:#17212b;font-weight:600;cursor:pointer}.file-picker input{position:absolute;inset:0;width:100%;height:100%;margin:0;padding:0;opacity:0;cursor:pointer}#fileName{margin:.75rem 0 0;font-size:.9rem;color:#52616d;overflow-wrap:anywhere}input:focus,button:focus,.file-picker:focus-within{outline:3px solid #6fac6d;outline-offset:3px}
</style>
<main><h1>Way</h1><p id="intro"></p>
<form id="form"><label><span id="codeText"></span><input id="code" required inputmode="numeric" autocomplete="off" maxlength="6" pattern="[0-9]{6}"></label>
<div class="file-field"><span id="linkText"></span><label class="file-picker"><span id="chooseText"></span><input id="image" type="file" accept="image/*" required aria-labelledby="chooseText" aria-describedby="fileName"></label><p id="fileName" aria-live="polite"></p></div>
<img id="preview" alt="" hidden>
<button id="send" type="submit" disabled></button></form><p id="status" role="status" aria-live="polite"></p>
</main>
<script>
const ru=navigator.language.toLowerCase().startsWith('ru');
const t=ru?{intro:'Выбери изображение до 40 МиБ. После отправки подтверди установку обоев в приложении Way. Данные передаются напрямую по локальной сети.',expired:'Приём закрыт. Открой его заново в Way и отсканируй новый QR-код.',code:'Код с экрана Way',link:'Изображение',choose:'Выбрать изображение',empty:'Изображение не выбрано',send:'Отправить в Way',sending:'Отправка…',ok:'Отправлено. Подтверди установку обоев в Way.',bad:'Неверный код. Проверь код на экране Way.',locked:'Слишком много попыток. Закрой и снова открой приём в Way.',large:'Файл пустой или больше 40 МиБ.',failed:'Не удалось отправить. Проверь общую Wi-Fi/локальную сеть и снова открой приём в Way.'}:{intro:'Choose an image up to 40 MiB, then confirm the wallpaper in the Way app. Data is sent directly over your local network.',expired:'Reception is closed. Reopen it in Way and scan the new QR code.',code:'Code shown in Way',link:'Image',choose:'Choose image',empty:'No image selected',send:'Send to Way',sending:'Sending…',ok:'Sent. Confirm the wallpaper in Way.',bad:'Incorrect code. Check the code shown in Way.',locked:'Too many attempts. Close and reopen the receiver in Way.',large:'The file is empty or exceeds 40 MiB.',failed:'Could not send. Check that both devices share a Wi-Fi/local network and reopen the receiver in Way.'};
history.replaceState(null,'',location.pathname);
document.documentElement.lang=ru?'ru':'en';
for(const [id,key] of [['intro','intro'],['codeText','code'],['linkText','link'],['chooseText','choose'],['fileName','empty'],['send','send']])document.getElementById(id).textContent=t[key];

const session='__WAY_SESSION__';
const form=document.getElementById('form');
const code=document.getElementById('code');
const button=document.getElementById('send');
const status=document.getElementById('status');
const image=document.getElementById('image');
const preview=document.getElementById('preview');
let previewUrl=null,sending=false,finished=false,currentRequest=null;
function updateForm(){
 code.disabled=sending||finished;image.disabled=sending||finished;
 button.disabled=sending||finished||!code.validity.valid||!validPayload();
}
function validPayload(){const file=image.files[0];return !!file&&file.size>0&&file.size<=41943040;}
function clearPreview(){if(previewUrl){URL.revokeObjectURL(previewUrl);previewUrl=null;}preview.hidden=true;}
image.addEventListener('change',()=>{
 const file=image.files[0];
 document.getElementById('fileName').textContent=file?.name||t.empty;
 document.getElementById('status').textContent='';
 clearPreview();
 if(!file)return;
 if(file.size===0||file.size>41943040){document.getElementById('status').textContent=t.large;return;}
 previewUrl=URL.createObjectURL(file);preview.src=previewUrl;preview.hidden=false;
 updateForm();
});
form.addEventListener('input',updateForm);
form.addEventListener('change',updateForm);
window.addEventListener('pagehide',()=>{finished=true;currentRequest?.abort();clearPreview();updateForm();});

form.addEventListener('submit',async event=>{
 event.preventDefault();
 if(sending||finished)return;
 if(!form.reportValidity()||!/^[0-9]{6}\$/.test(code.value.trim())||!validPayload()){updateForm();return;}
 const credential=code.value.trim();
 const body=image.files[0];
 sending=true;updateForm();status.textContent=t.sending;
 const controller=new AbortController();currentRequest=controller;
 const timer=setTimeout(()=>controller.abort(),120000);
 try{
  const response=await fetch('/import',{method:'POST',credentials:'omit',cache:'no-store',redirect:'error',
   headers:{'Content-Type':'application/octet-stream','Authorization':'Bearer '+credential,'X-Way-Session':session},body,signal:controller.signal});
  if(response.status===202){
   finished=true;status.textContent=t.ok;clearPreview();
  }else if(response.status===401){code.value='';status.textContent=t.bad;}
  else if(response.status===429){finished=true;status.textContent=t.locked;}
  else if(response.status===403||response.status===410){finished=true;status.textContent=t.expired;}
  else status.textContent=response.status===413?t.large:t.failed;
 }catch{if(!finished)status.textContent=t.failed;}
 finally{clearTimeout(timer);currentRequest=null;sending=false;updateForm();}
});
updateForm();
</script></html>
''';
}
