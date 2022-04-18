
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dart_minecraft/dart_minecraft.dart';
import 'package:nyxx/nyxx.dart';
import "package:nyxx_interactions/nyxx_interactions.dart";
import 'package:string_capitalize/string_capitalize.dart';

import '../minecraft//multicraft/MulticraftAPI.dart';
import '../minecraft/multicraft/MulticraftAPICommands.dart';
import '../minecraft/ServerContainer.dart';

typedef Predicate<ServerContainer> = bool Function(ServerContainer);

class FuBot{

  static final String _defaultFaviconData = File("assets/default_favicon_data.txt").readAsLinesSync().first;
  static Snowflake roleSnowflake = Snowflake("0");
  static Snowflake guildSnowflake = Snowflake("0");

  INyxxWebsocket? bot;

  FuBot(String filePath) {
    try{
      var tokenFile = File(filePath);
      
      Map<String, dynamic> botInfo = jsonDecode(tokenFile.readAsStringSync());

      bot = NyxxFactory.createNyxxWebsocket(botInfo["bot_token"], GatewayIntents.allUnprivileged)
        ..registerPlugin(Logging()) // Default logging plugin
        ..registerPlugin(CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
        ..registerPlugin(IgnoreExceptions()); // Plugin that handles uncaught exceptions that may occur;


      guildSnowflake = Snowflake(botInfo["server_guild_id"]);
      roleSnowflake = Snowflake(botInfo["server_role_snowflake"]);

    } on FileSystemException catch(fileE){
      print("File not found, Idiot! Next time give the proper file location: [ ${fileE.message} ]");
      exit(1);
    }catch(e){
      print("Well Someone has fucked up real bad as the file wasnt the problem... not my fault yet: \n [ $e ]");
      exit(1);
    }

    registerBotCommands();

    bot!.connect();
  }

  static final CommandOptionBuilder mainServerPar = CommandOptionBuilder(CommandOptionType.string, "servername", "The server's name");

  static final SlashCommandBuilder serverStatus = SlashCommandBuilder("serverstatus", "Get the Server Status for a given Server", [mainServerPar])
    ..registerHandler((event) async {

      var severName = event.args.isNotEmpty ? event.getArg("servername").value : null;
      var id = severName != null ? int.tryParse(severName) : null;

      ServerContainer? container = ServerContainer.getServer(severName, id);

      if(container != null){
        event.acknowledge();

        bool hasButtonPerms = await _checkIfHasPermission(event.interaction.memberAuthor!);

        event.sendFollowup(await outputServerEmbed(container, await event.interaction.channel.getOrDownload(), null, null, hasButtonPerms: hasButtonPerms));

      }else{
        String response = "It Seems that [$severName] isn't a Server I know, did you type it in correctly?";

        if(id != null){
          response = "It Seems that [$id] isn't a Server I know, did you type it in correctly?";
        }

        event.respond(MessageBuilder()..replyBuilder = ReplyBuilder.fromMessage(await event.getOriginalResponse())..appendMention(event.interaction.userAuthor!)..appendBold(response));
      }
    });

  static final SlashCommandBuilder startServer = SlashCommandBuilder("startserver", "Start a given server", [mainServerPar], defaultPermissions: false)
    ..registerHandler((event) async {
    var severName = event.args.isNotEmpty ? event.getArg("servername").value : null;
    var id = severName != null ? int.tryParse(severName) : null;

    ServerContainer? container = ServerContainer.getServer(severName, id);

    if(container != null){
      bool isServerOn = await isServerOnline(container);

      if(isServerOn){
        event.respond(MessageBuilder()..appendBold("The Server is already online."));
      }else{
        Map<String, dynamic> returnMap = await CommandHelper.startServer(container);

        if(returnMap != MulticraftAPI.errorMap) {
          await event.respond(MessageBuilder()..appendBold("${container.name} Starting up..."));

          IMessage message = await event.getOriginalResponse();

          message.edit(await outputServerEmbed(container, await event.interaction.channel.getOrDownload(), message, (container) => isServerOnline(container)));
        }else{
          event.respond(MessageBuilder()..append("Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
        }
      }

    }else{
      String response = "It Seems that [$severName] isn't a Server I know, did you type it in correctly?";

      if(id != null){
        response = "It Seems that [$id] isn't a Server I know, did you type it in correctly?";
      }

      event.respond(MessageBuilder()..replyBuilder = ReplyBuilder.fromMessage(await event.getOriginalResponse())..appendMention(event.interaction.userAuthor!)..appendBold(response));
    }
  });

  static final SlashCommandBuilder stopServer = SlashCommandBuilder("stopserver", "Stop a given server", [mainServerPar], defaultPermissions: false)
    ..registerHandler((event) async {
    var severName = event.args.isNotEmpty ? event.getArg("servername").value : null;
    var id = severName != null ? int.tryParse(severName) : null;

    ServerContainer? container = ServerContainer.getServer(severName, id);

    if(container != null){
      bool isServerOn = await isServerOnline(container);

      if(!isServerOn){
        event.respond(MessageBuilder()..appendBold("The Server is off!"));
      }else{
        Map<String, dynamic> returnMap = await CommandHelper.stopServer(container);

        if(returnMap != MulticraftAPI.errorMap) {
          await event.respond(MessageBuilder()..appendBold("${container.name} is shutting down..."));

          IMessage message = await event.getOriginalResponse();

          message.edit(await outputServerEmbed(container, await event.interaction.channel.getOrDownload(), message, (container) async { return !(await isServerOnline(container)); }));
        }else{
          event.respond(MessageBuilder()..append("Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
        }
      }

    }else{
      String response = "It Seems that [$severName] isn't a Server I know, did you type it in correctly?";

      if(id != null){
        response = "It Seems that [$id] isn't a Server I know, did you type it in correctly?";
      }

      event.respond(MessageBuilder()..replyBuilder = ReplyBuilder.fromMessage(await event.getOriginalResponse())..appendMention(event.interaction.userAuthor!)..appendBold(response));
    }
  });

  static final SlashCommandBuilder restartServer = SlashCommandBuilder("restartserver", "Restart a given server", [mainServerPar], defaultPermissions: false)
    ..registerHandler((event) async {
    var severName = event.args.isNotEmpty ? event.getArg("servername").value : null;
    var id = severName != null ? int.tryParse(severName) : null;

    ServerContainer? container = ServerContainer.getServer(severName, id);

    if(container != null){
      Map<String, dynamic> returnMap = await CommandHelper.restartServer(container);

      if(returnMap != MulticraftAPI.errorMap) {
        await event.respond(MessageBuilder()..appendBold("${container.name} is restarting..."));

        IMessage message = await event.getOriginalResponse();

        message.edit(await outputServerEmbed(container, await event.interaction.channel.getOrDownload(), message, (container) => isServerOnline(container)));
      }else{
        event.sendFollowup(MessageBuilder()..append("Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
      }
    }else{
      String response = "It Seems that [$severName] isn't a Server I know, did you type it in correctly?";

      if(id != null){
        response = "It Seems that [$id] isn't a Server I know, did you type it in correctly?";
      }

      event.respond(MessageBuilder()..replyBuilder = ReplyBuilder.fromMessage(await event.getOriginalResponse())..appendMention(event.interaction.userAuthor!)..appendBold(response));
    }
  });

  void registerBotCommands(){
    IInteractions.create(WebsocketInteractionBackend(bot!))
      ..registerSlashCommand(serverStatus..guild = guildSnowflake)
      ..registerSlashCommand(startServer..guild = guildSnowflake..addPermission(CommandPermissionBuilderAbstract.role(roleSnowflake)))
      ..registerSlashCommand(stopServer..guild = guildSnowflake..addPermission(CommandPermissionBuilderAbstract.role(roleSnowflake)))
      ..registerSlashCommand(restartServer..guild = guildSnowflake..addPermission(CommandPermissionBuilderAbstract.role(roleSnowflake)))
      ..events.onButtonEvent.listen((event) async {
        ITextChannel channel = await event.interaction.channel.getOrDownload();

        bool permCommandAlreadyRan = false;
        bool permCheckFailed = false;

        if (event.interaction.customId.startsWith("start_")) {
          if(await _checkIfHasPermission(event.interaction.memberAuthor!, event)) {
            permCommandAlreadyRan = true;
            startButton(channel, event);
          }else {
            permCheckFailed = true;
          }
        } else if (event.interaction.customId.startsWith("stop_")) {
          if(await _checkIfHasPermission(event.interaction.memberAuthor!, event)) {
            permCommandAlreadyRan = true;
            stopButton(channel, event);
          }else {
            permCheckFailed = true;
          }
        } else if (event.interaction.customId.startsWith("restart_")) {
          if(await _checkIfHasPermission(event.interaction.memberAuthor!, event)) {
            permCommandAlreadyRan = true;
            restartButton(channel, event);
          } else {
            permCheckFailed = true;
          }
        }

        if(permCheckFailed) {
          print("saadshkjasfhdsahsadlkjsadhbdskjvg");
          channel.sendMessage(MessageBuilder()
            ..appendMention(event.interaction.userAuthor!)
            ..appendBold(": You don't have permission to use this Command"));

          return;
        }

        if(!permCommandAlreadyRan) {
          if (event.interaction.customId.startsWith("refresh_")) {
            event.respond(MessageBuilder.empty());
            refreshButton(channel, event);
          } else {
            channel.sendMessage(MessageBuilder()
              ..appendMention(event.interaction.memberAuthor!)
              ..appendBold(": idk what you have done but you did it I guess?"));
          }
        }
      })
      ..syncOnReady();
  }

  static Future<bool> _checkIfHasPermission(IMember member, [IButtonInteractionEvent? event]) async{
    for(Cacheable cache in member.roles){
      SnowflakeEntity entity = await cache.getOrDownload();
      if(entity.id == roleSnowflake){
        if(event != null) {
          event.respond(MessageBuilder.empty());
        }

        return true;
      }
    }

    return false;
  }

  // static Pair<IMessage, IMessage>? responseMessageCache;
  //
  // static void _sendNewOrEditMessage(ITextChannel channel, IMessage embed, MessageBuilder builder) async {
  //   if(responseMessageCache != null && responseMessageCache!.first == embed){
  //     IMessage cachedMessage = responseMessageCache!.second;
  //
  //     IMessage firstMessage = await channel.downloadMessages(limit: 1).first;
  //
  //     if(firstMessage == cachedMessage) {
  //       responseMessageCache = Pair(embed, await cachedMessage.edit(builder));
  //     }else{
  //       responseMessageCache = Pair(embed, await channel.sendMessage(builder..replyBuilder = ReplyBuilder.fromMessage(embed)));
  //     }
  //   }else{
  //     responseMessageCache = Pair(embed, await channel.sendMessage(builder));
  //   }
  // }

  static IMessage? cacheAlreadyOnline;

  void startButton(ITextChannel channel, IButtonInteractionEvent event) async {
    String? serverName = event.interaction.customId.split("_").last;

    if(serverName == "null") {
      serverName = null;
    }

    ServerContainer? container = ServerContainer.getServer(serverName, null);

    if(container != null){
      bool isServerOn = await isServerOnline(container);

      if(isServerOn){
        String response = "1 : The Server is already online.";

        if(cacheAlreadyOnline != null) {
          List<String> textComp = _removeFormattingCodesDiscord(cacheAlreadyOnline!.content).split(":");

          response = "${int.parse(textComp[0]) + 1} : The Server is already online.";

          cacheAlreadyOnline = await cacheAlreadyOnline!.edit(MessageBuilder()
            ..appendBold(response));
        }else{
          cacheAlreadyOnline = await channel.sendMessage(MessageBuilder()
            ..appendBold(response));
        }
      }else{
        Map<String, dynamic> returnMap = await CommandHelper.startServer(container);

        if(returnMap != MulticraftAPI.errorMap) {
          IMessage orginalEmbed = event.interaction.message!;
          IMessage initResponse = await channel.sendMessage(MessageBuilder()..appendBold("${container.name} Starting up..."));

          orginalEmbed.edit(await outputServerEmbed(container, channel, null, (container) => isServerOnline(container), newEmbed: false));

          await initResponse.delete();
        }else{
          channel.sendMessage(MessageBuilder()..append("Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
        }
      }
    }else{
      String response = "It Seems that [$serverName] isn't a Server I know, did you type it in correctly?";

      channel.sendMessage(MessageBuilder()..appendMention(event.interaction.userAuthor!)..appendBold(response));
    }
  }

  void stopButton(ITextChannel channel, IButtonInteractionEvent event) async {
    String? serverName = event.interaction.customId.split("_").last;

    if(serverName == "null") {
      serverName = null;
    }

    ServerContainer? container = ServerContainer.getServer(serverName, null);

    if(container != null){
      bool isServerOn = await isServerOnline(container);

      IMessage orginalEmbed = event.interaction.message!;

      if(!isServerOn){
        channel.sendMessage(MessageBuilder()..appendBold("The Server is off!"));
      }else{
        Map<String, dynamic> returnMap = await CommandHelper.stopServer(container);

        if(returnMap != MulticraftAPI.errorMap) {
          IMessage initResponse = await channel.sendMessage(MessageBuilder()..appendBold("${container.name} is shutting down..."));

          orginalEmbed.edit(await outputServerEmbed(container, channel, null, (container) async {
            return !(await isServerOnline(container));
          }, newEmbed: false));

          await initResponse.delete();
        }else{
          channel.sendMessage(MessageBuilder()..append("Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
        }
      }
    }else{
      String response = "It Seems that [$serverName] isn't a Server I know, did you type it in correctly?";

      channel.sendMessage(MessageBuilder()..appendMention(event.interaction.userAuthor!)..appendBold(response));
    }
  }

  void restartButton(ITextChannel channel, IButtonInteractionEvent event) async {
    String? serverName = event.interaction.customId.split("_").last;

    if(serverName == "null") {
      serverName = null;
    }

    ServerContainer? container = ServerContainer.getServer(serverName, null);

    if(container != null){
      Map<String, dynamic> returnMap = await CommandHelper.restartServer(container);

      if(returnMap != MulticraftAPI.errorMap) {
        IMessage orginalEmbed = event.interaction.message!;
        IMessage initResponse = await channel.sendMessage(MessageBuilder()..appendBold("${container.name} is restarting..."));

        orginalEmbed.edit(await outputServerEmbed(container, channel, null, (container) => isServerOnline(container)));

        await initResponse.delete();

      }else{
        channel.sendMessage(MessageBuilder()..append("Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
      }

    }else{
      String response = "It Seems that [$serverName] isn't a Server I know, did you type it in correctly?";
      channel.sendMessage(MessageBuilder()..appendMention(event.interaction.userAuthor!)..appendBold(response));
    }
  }

  void refreshButton(ITextChannel channel, IButtonInteractionEvent event) async {
    String? serverName = event.interaction.customId.split("_").last;

    if(serverName == "null") {
      serverName = null;
    }

    ServerContainer? container = ServerContainer.getServer(serverName, null);

    if(container != null){


      Map<String, dynamic> returnMap = await CommandHelper.getStatus(container);

      if(returnMap != MulticraftAPI.errorMap) {
        IMessage orginalEmbed = event.interaction.message!;
        IMessage initResponse = await channel.sendMessage(MessageBuilder()..appendBold("Refreshing: One moment!"));

        orginalEmbed.edit(await outputServerEmbed(container, channel, null, (container) => Future.value(true), newEmbed: false));

        initResponse.delete();
      }else{
        channel.sendMessage(MessageBuilder()..append("Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
      }

    }else{
      String response = "It Seems that [$serverName] isn't a Server I know, did you type it in correctly?";
      channel.sendMessage(MessageBuilder()..appendMention(event.interaction.userAuthor!)..appendBold(response));
    }
  }

  static Future<MessageBuilder> outputServerEmbed(ServerContainer container, ITextChannel channel, IMessage? message, Future<bool> Function(ServerContainer)? predicate, {bool newEmbed = true, bool hasButtonPerms = true}) async{
    int totalPausedTime = 0;

    if(predicate != null) {
      print("Running while loop for updating embeds");
      while (!await predicate.call(container)) {
        if (totalPausedTime >= container.maxTimeOutTotal) {
          return MessageBuilder()
            ..appendBold(
                "Even after ${container.maxTimeOutTotal} seconds, I was unable to get the needed Server Info! May be good Idea to check your servers console");
        }

        await Future.delayed(Duration(seconds: 5));
        totalPausedTime += 5;
        print("Current time waiting: $totalPausedTime");
      }
      print("Ending Loop and running embed code.");
    }

    final server = await ping(container.address, port: container.port);

    Map<String, dynamic> statusMap = await CommandHelper.getStatus(container);
    Map<String, dynamic> resourceMap = await CommandHelper.getResources(
        container);

    String faviconData;
    int currentPlayerCount;
    var motd;

    bool attemptToCacheFavicon;
    File faviconDataFile = File("assets/servers/${container.name}_favicon_data.txt");;

    if (server == null) {
      attemptToCacheFavicon = false;

      if (faviconDataFile.existsSync()) {
        faviconData = faviconDataFile
            .readAsLinesSync()
            .first;
      } else {
        faviconData = _defaultFaviconData;
      }

      currentPlayerCount = statusMap["onlinePlayers"];
    } else {
      attemptToCacheFavicon = true;

      currentPlayerCount = server.response!.players.online;
      faviconData = server.response!.favicon;
      motd = _removeFormattingCodesMinecraft(server.response!.description.description);
    }

    if (statusMap != MulticraftAPI.errorMap ||
        resourceMap != MulticraftAPI.errorMap) {
      print(statusMap);
      print(resourceMap);
      print(faviconData);

      ComponentMessageBuilder builder = ComponentMessageBuilder()
        ..replyBuilder = message != null ? ReplyBuilder.fromMessage(message) : null
        ..embeds = [(EmbedBuilder()
          // ..addAuthor((author) {
          //   author.name = "Server Stats for ${container.name}";
          // })
          ..description = motd
          ..title = "${container.name} /-/ Status: ${(statusMap["status"] as String)
              .capitalizeOrFail()}"
          ..addField(name: "Current Player Count:",
              content: currentPlayerCount, inline: true)..addField(
              name: "CPU Load:",
              content: "${double.parse(resourceMap["cpu"]).roundToDouble()}%",
              inline: true)..addField(name: "Memory Load:",
              content: "${double.parse(resourceMap["memory"])
                  .roundToDouble()}%", inline: true)
          ..thumbnailUrl = "attachment://icon.png"
        )
        ];

      if(newEmbed){
        builder.addBytesAttachment(base64.decode(faviconData.split('data:image/png;base64,')[1]), "icon.png");
      }

      ComponentRowBuilder row = ComponentRowBuilder();

      if(hasButtonPerms){
        row..addComponent(ButtonBuilder("Start", "start_${container.name}", ButtonStyle.success))
          ..addComponent(ButtonBuilder("Stop", "stop_${container.name}", ButtonStyle.danger))
          ..addComponent(ButtonBuilder("Restart", "restart_${container.name}", ButtonStyle.primary));
      }

      builder.addComponentRow(row..addComponent(ButtonBuilder("Refresh", "refresh_${container.name}", ButtonStyle.secondary)));

      if(attemptToCacheFavicon){
        if(faviconData != _defaultFaviconData){
          faviconDataFile.writeAsString(faviconData);
        }
      }

      return builder;
    } else {
      return(MessageBuilder()
        ..append(
            "Hmm, I am Having a hard time getting any info about the Server, Either the API is down or something else has gone wrong"));
    }

  }

  static Future<bool> isServerOnline(ServerContainer serverContainer) async {
    Map<String, dynamic> statusMap = await CommandHelper.getStatus(serverContainer);

    print(statusMap);

    if(statusMap != MulticraftAPI.errorMap){
      if(statusMap["status"] == "online"){
        return true;
      }
    }

    return false;
  }

  static String _removeFormattingCodesDiscord(String text) {
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == "*" || char == "_" || char == "~" || char == "`" || char == ">") {
        i++;
        continue;
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  static String _removeFormattingCodesMinecraft(String text) {
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == "§") {
        i++;
        continue;
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }
}
