import 'dart:io';

import 'package:http/http.dart';

Client? _client;

const Map<String, String> header = {"User-Agent": "Mozilla/4.0 (compatible; MSIE 5.0;Windows98;DigExt)"};

void open() {
  _client = Client();
}

void close() {
  if (_client != null) {
    _client!.close();
    _client = null;
  }
}

Client _getClient() {
  if (_client == null) throw StateError("The network clients have not been initialized");
  return _client!;
}

Future<Response> get(Uri uri) {
  return _getClient().get(uri);
}

Future<Response> getPost(Uri uri, Object? body) {
  return _getClient().post(uri, body: body);

  //return getClient().post(uri, headers: header);
}


