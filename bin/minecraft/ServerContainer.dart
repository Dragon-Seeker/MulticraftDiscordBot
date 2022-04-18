import 'dart:convert';
import 'dart:io';

import '../minecraft/multicraft/MulticraftAPI.dart';

final List<dynamic> global_user_info = [];

final List<ServerContainer> containerList = [];

class ServerContainer{
  MulticraftAPI api;
  String name;
  int id;

  String address;
  int port;

  int maxTimeOutTotal = 20;

  ServerContainer(this.name, this.id, this.address, this.port, this.api);

  bool checkIfIsServer(String? name, int? id){
    if(name != null){
      return name.toLowerCase() == this.name.toLowerCase();
    }else if(id != null){
      return id == this.id;
    }else{
      print("Something has gone wrong! A server was just checked with both a null name var and a null id var!!!");
    }

    return false;
  }

  static ServerContainer? getServer(String? name, int? id){
    if(name == null){
      return containerList.first;
    }

    for(ServerContainer container in containerList){
      if(container.checkIfIsServer(name, id)){
        return container;
      }
    }

    return null;
  }

  factory ServerContainer.of(String filePath, Map<String, dynamic> json){
    if(global_user_info.isEmpty){
      initGlobalInfo();
    }

    String userName = global_user_info[0];
    String apiKey = global_user_info[1];
    String apiUrl = global_user_info[2];

    if(json.containsKey("username"))
      userName = json["username"];

    if(json.containsKey("api_key"))
      apiKey = json["api_key"];

    if(json.containsKey("api_url"))
      apiUrl = json["api_url"];

    if(json.containsKey("server_info")) {
      Map<String, dynamic> serverInfo = json["server_info"];
      
      int serverId = int.parse(serverInfo["server_id"]);
      String serverName = serverInfo["server_name"];
      String serverAddress = serverInfo["server_address"];
      int port = int.parse(serverInfo["server_port"]);

      if(json.containsKey("max_conn_timeout")){
        return ServerContainer(serverName, serverId, serverAddress, port, MulticraftAPI(userName, apiKey, apiUrl))..setServerTimeoutTotal(int.parse(json["max_conn_timeout"]));
      }

      return ServerContainer(serverName, serverId, serverAddress, port, MulticraftAPI(userName, apiKey, apiUrl))..setServerTimeoutTotal(30);
    }else{
      throw FormatException("[$filePath] : It seems that it doesn't contain a server_info field! This is real bad so fix this before restarting.");
    }
  }

  void setServerTimeoutTotal(int timeoutTotal){
    maxTimeOutTotal = timeoutTotal;
  }

  static initGlobalInfo(){
    var userInfo = File("assets/info/user_info.json");
    Map<String, dynamic> json = jsonDecode(userInfo.readAsStringSync());

    global_user_info.add(json["username"]);
    global_user_info.add(json["api_key"]);
    global_user_info.add(json["api_url"]);
  }
}