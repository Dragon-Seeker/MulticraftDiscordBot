import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';

import 'bot/discord_bot_wisper.dart';
import 'minecraft/ServerContainer.dart';
import 'minecraft/network/net_io.dart' as net_io;

FuBot? botClass;

void main(List<String> arguments) async {
  net_io.open();

  initServerContainers();

  botClass = FuBot("assets/info/bot_info.json");

  while(true){
    var consoleInput = await readLine();
    
    if(consoleInput != "") {
      if (consoleInput == "close") {
        botClass!.bot!.dispose();
        
        exit(0);
      }
    }
  }

}

void initServerContainers(){
  var directory = Directory("assets/servers/");

  for(var file in directory.listSync().whereType<File>().where((file) => file.path.endsWith(".json"))){
    Map<String, dynamic> json = jsonDecode(file.readAsStringSync());

    ServerContainer container = ServerContainer.of(file.path, json);

    containerList.add(container);
  }
}

var _stdinLines = StreamQueue(LineSplitter().bind(Utf8Decoder().bind(stdin)));

Future<String> readLine([String? query]) async {
  if (query != null) stdout.write(query);
  return _stdinLines.next;
}


