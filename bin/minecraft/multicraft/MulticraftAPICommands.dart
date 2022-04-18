import 'MulticraftAPI.dart';
import '../ServerContainer.dart';

class CommandHelper{

  static Future<Map<String, dynamic>> getStatus(ServerContainer container) async{
    return container.api.call("getServerStatus", {"id": container.id.toString(), "player_list" : "0"});//.then((value) => value is List ? MulticraftAPI.errorMap : value);
  }

  static Future<Map<String, dynamic>> getResources(ServerContainer container) async{
    return container.api.call("getServerResources", {"id": container.id.toString()});//.then((value) => value is List ? MulticraftAPI.errorMap : value);
  }

  static Future<Map<String, dynamic>> startServer(ServerContainer container) async{
    return container.api.call("startServer", {"id": container.id.toString()});//.then((value) => value is List ? MulticraftAPI.errorMap : value);
  }

  static Future<Map<String, dynamic>> stopServer(ServerContainer container) async{
    return container.api.call("stopServer", {"id": container.id.toString()});//.then((value) => value is List ? MulticraftAPI.errorMap : value);
  }

  static Future<Map<String, dynamic>> restartServer(ServerContainer container) async{
    return container.api.call("restartServer", {"id": container.id.toString()});//.then((value) => value is List ? MulticraftAPI.errorMap : value);
  }
}