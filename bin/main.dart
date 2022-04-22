import 'dart:convert';
import 'dart:io';

import 'bot/discord_bot_wisper.dart';
import 'minecraft/ServerContainer.dart';
import 'minecraft/network/net_io.dart' as net_io;

void main(List<String> arguments) {
  net_io.open();

  initServerContainers();

  var botClass = FuBot("assets/info/bot_info.json");
}

void initServerContainers(){
  var directory = Directory("assets/servers/");

  for(var file in directory.listSync().whereType<File>().where((file) => file.path.endsWith(".json"))){
    Map<String, dynamic> json = jsonDecode(file.readAsStringSync());

    ServerContainer container = ServerContainer.of(file.path, json);

    containerList.add(container);
  }
}
