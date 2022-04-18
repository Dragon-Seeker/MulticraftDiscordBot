
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../network/net_io.dart';


///
/// Based off of A Java Implementation of Multicraft API
/// Repo: [https://github.com/pavog/Multicraft-api]
///
class MulticraftAPI{

  static Map<String, dynamic> nullMap = {"null": "a null response was given"};
  static Map<String, dynamic> errorMap = {"error": "a error response was given"};

  String url;
  String user;
  String key;

  MulticraftAPI(this.user, this.key, this.url);

  Future<Map<String, dynamic>> call(String method, Map<String, String> parameters) async{
    parameters = HashMap.from(parameters);

    try {
      Uri url = Uri.parse(this.url);

      // Add neccessary parameters
      parameters["_MulticraftAPIMethod"] = method;
      parameters["_MulticraftAPIUser"] = user;

      StringBuffer apiKeySalt = StringBuffer();
      for (MapEntry<String, String> param in parameters.entries) {
        // The api key is hashed with all params put after each other (with their values)
        apiKeySalt..write(param.key)..write(param.value);
      }

      //Must happen after apiKeySalt has been written to with all the other parameters
      parameters["_MulticraftAPIKey"] = getMulticraftEncodedAPIKey(apiKeySalt.toString(), key);

      String response = await getPost(url, parameters).then((value) => value.body);

      Map<String, dynamic> result = JsonDecoder().convert(response);

      if (!(result.containsKey("success"))) {
        List<String> errors = result["errors"];
        StringBuffer exc = StringBuffer();
        for (String element in errors) {
          exc.write(element);
          exc.write(", ");
        }
        throw Exception(exc.toString());
      }

      if(result["success"]){
        if(result["data"] is List){
          return {};
        }

        return result["data"];
      }else{
        print("Errored!");
        print(result);

        return errorMap;
      }
    }
    catch (e) {
      print(e);
      return nullMap;
    }
  }

  String getMulticraftEncodedAPIKey(String parameterQuery, String apiKey) {
    var mac = Hmac(sha256, utf8.encode(apiKey));

    return mac.convert(utf8.encode(parameterQuery)).toString();
  }
}