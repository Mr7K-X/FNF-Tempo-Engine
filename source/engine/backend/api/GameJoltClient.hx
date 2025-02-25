package engine.backend.api;

import engine.types.SaveTag;
#if FEATURE_GAMEJOLT_CLIENT
import flixel.FlxSubState;
import engine.ui.GameJoltNotification;
import engine.ui.RestartGameSubState;
import engine.backend.util.FileUtil;
import engine.backend.macro.GameJoltMacro;
import gamejolt.formats.User;
import gamejolt.types.DataUpdateType;
import gamejolt.formats.Response;
import gamejolt.GameJolt as Api;
import gamejolt.GameJolt.GJRequest as Request;
import openfl.utils.ByteArray;
import openfl.events.ErrorEvent;
import haxe.io.Path;
import haxe.Unserializer;
import haxe.Serializer;

#if (systools && cpp)
@:access(engine.backend.api.GJSystools)
#end
@:access(gamejolt.GameJolt)
@:access(engine.backend.macro.GameJoltMacro)
class GameJoltClient
{
	public static var instance(get, never):GameJoltClient;

	static var _instance:Null<GameJoltClient> = null;

	static var sessionOpened:Bool = false;
	static var sessionPinged:Bool = false;

	private function new():Void
	{
		print("Initializing client...");

		Api.gameID = GameJoltMacro.getData().ID;
		Api.gameKey = GameJoltMacro.getData().Key;

		if ((Save.gjData.userName == null || Save.gjData.userName == "") && (Save.gjData.userToken == null || Save.gjData.userToken == ""))
		{
			print('User data not exists!');
			return;
		}

		Api.userName = Save.gjData.userName;
		Api.userToken = Save.gjData.userToken;
	}

	static var pingTimer:FlxTimer;

	var imageURLLoader:URLLoader;

	public function initialize(?onComplete:Response->Void):Void
	{
		if (Api.gameID != 0 && Api.gameKey != "")
		{
			print("Game ID and KEY exists!");

			if (Api.userName != "" && Api.userToken != "")
			{
				print("User data exists!");

				openSession(onComplete);
				Sys.sleep(1); // for loading...
			}
		}
	}

	public function login(name:String, token:String, ?onComplete:Response->Void):Void
	{
		#if debug
		print('User - $name ($token)');
		#end

		Api.userName = name;
		Api.userToken = token;

		Save.gjData.userName = name;
		Save.gjData.userToken = token;
		Save.save([GAMEJOLT]);

		initialize(onComplete);
	}

	public function logout():Void
	{
		if (Api.userName == "" && Api.userToken == "")
			return;

		removeCloudFiles();
		stopSession();

		Api.userName = "";
		Api.userToken = "";

		Save.gjData.userName = null;
		Save.gjData.userToken = null;
		Save.save([GAMEJOLT]);

		Sys.sleep(1); // for loading...

		if (FlxG.state != null)
		{
			FlxG.state.persistentUpdate = false;
			FlxG.state.openSubState(new RestartGameSubState("You want to restart game for ending Log Out?", () -> {
				#if cpp
				new GJSystools();
				#else
				System.exit(1337);
				#end
			}));
		}
	}

	public function setCloudFiles(?isCheckingUser:Bool = false):Void
	{
		if (sessionOpened && !sessionPinged)
		{
			getKeysData(true, null, (r:Response) ->
			{
				for (i in 0...r.keys.length)
					fetchData(r.keys[i].key, true, (r2:Response) ->
					{
						FileUtil.createTJSON(Constants.GAMEJOLT_CLOUD_PATH + ".dat" + Std.string(i), {f: {k: r.keys[i].key, d: r2.data}});

						if (isCheckingUser)
							syncSaveWithCloud(r.keys[i].key, r2.data);
					});
			});
		}
	}

	// for deleting a unused files, or a game directory will trashed with cloud data files((
	public function removeCloudFiles():Void
	{
		if (FileSystem.isDirectory(Path.directory(Constants.GAMEJOLT_CLOUD_PATH)))
		{
			for (i in 0...FileSystem.readDirectory(Path.directory(Constants.GAMEJOLT_CLOUD_PATH)).length)
			{
				if (FileSystem.exists(Constants.GAMEJOLT_CLOUD_PATH + '.dat$i'))
					FileSystem.deleteFile(Constants.GAMEJOLT_CLOUD_PATH + '.dat$i');
			}
		}
	}

	public function syncSaveWithCloud(tag:String, data:String):Void
	{
		if (sessionOpened && !sessionPinged)
		{
			switch (tag)
			{
				case "flixel_save":
					Save.mergeData({tag: FLIXEL, value: Unserializer.run(data)});
					Save.save([FLIXEL]);
				case "main_save":
					Save.mergeData({tag: MAIN, value: Unserializer.run(data)});
					Save.save([MAIN]);
				case "options_save":
					Save.mergeData({tag: OPTIONS, value: Unserializer.run(data)});
					Save.save([OPTIONS]);
			}
		}
	}

	public function syncCloudFiles(?isExit:Bool = false, ?list:Array<SaveTag> = null):Void
	{
		if (sessionOpened && !sessionPinged)
		{
			if (!isExit && FlxG.state != null)
			{
				FlxG.state.persistentUpdate = false;
				FlxG.state.openSubState(new WaitingSubState("GameJolt Cloud Data", "Wait, new save data's for cloud loading..."));
			}

			var allData:Array<String> = [];
			var allJson:Array<{f:{k:String, d:String}}> = [];

			if (FileSystem.isDirectory(Path.directory(Constants.GAMEJOLT_CLOUD_PATH)))
			{
				for (i in 0...FileSystem.readDirectory(Path.directory(Constants.GAMEJOLT_CLOUD_PATH)).length)
				{
					if (FileSystem.exists(Constants.GAMEJOLT_CLOUD_PATH + '.dat$i'))
						allData.push(File.getContent(Constants.GAMEJOLT_CLOUD_PATH + '.dat$i'));
				}
			}

			var syncing:Void->Void = () ->
			{
				if (list == null)
				{
					setData('main_save', Serializer.run(Save.mainData));
					setData('options_save', Serializer.run(Save.optionsData));
					setData('flixel_save', Serializer.run(Save.flixelData));
				}
				else
				{
					for (s in list)
						switch (s)
						{
							case MAIN:
								setData('main_save', Serializer.run(Save.mainData));
							case OPTIONS:
								setData('options_save', Serializer.run(Save.optionsData));
							case FLIXEL:
								setData('flixel_save', Serializer.run(Save.flixelData));
							default: // nothing
						}
				}

				removeCloudFiles();
			};

			if (!isExit)
			{
				new FlxTimer().start(1, (_) ->
				{
					if (FlxG.state != null && FlxG.state.subState != null)
						FlxG.state.closeSubState();
				});
			}
			else
				syncing();
		}
	}

	public function pingSession():Void
	{
		sessionPinged = true;

		var request = new Request(SESSION_PING(true));
		request.onProgress = onProgress;
		request.onError = onError;
		request.send();

		print('Ping!');
	}

	public function openSession(?onComplete:Response->Void):Void
	{
		var request = new Request(SESSION_OPEN);
		request.onProgress = onProgress;
		request.onError = onError;
		request.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			if (pingTimer != null)
				pingTimer.cancel();

			sessionOpened = true;
			sessionPinged = false;

			print('Session opened!');

			checkUserData();

			Lib.application.onExit.add((_) -> stopSession());
		};
		request.send();
	}

	public function stopSession():Void
	{
		if (sessionOpened && !sessionPinged)
		{
			if (pingTimer != null)
				pingTimer.cancel();

			syncCloudFiles(true);
			print("Session Closed!");

			var request = new Request(SESSION_CLOSE);
			request.onError = onError;
			request.onProgress = onProgress;
			request.send();
		}
	}

	public function setTrophy(ID:Int, ?onComplete:Response->Void):Void
	{
		var trophyRequest = new Request(TROPHIES_ADD(ID));
		trophyRequest.onError = onError;
		trophyRequest.onProgress = onProgress;
		trophyRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		trophyRequest.send();
	}

	public function fetchTrophy(Achieved:Bool = false, ID:Int, ?onComplete:Response->Void):Void
	{
		var trophyRequest = new Request(TROPHIES_FETCH(Achieved, ID));
		trophyRequest.onError = onError;
		trophyRequest.onProgress = onProgress;
		trophyRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		trophyRequest.send();
	}

	public function removeTrophy(ID:Int, ?onComplete:Response->Void):Void
	{
		var trophyRequest = new Request(TROPHIES_REMOVE(ID));
		trophyRequest.onError = onError;
		trophyRequest.onProgress = onProgress;
		trophyRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		trophyRequest.send();
	}

	public function setScore(score:String, ID:Int, ?onComplete:Response->Void):Void
	{
		var scoreRequest = new Request(SCORES_ADD(score, 1, null, ID));
		scoreRequest.onError = onError;
		scoreRequest.onProgress = onProgress;
		scoreRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		scoreRequest.send();
	}

	public function fetchScore(limit:Int, ID:Int, betterThan:Int, ?onComplete:Response->Void):Void
	{
		var scoreRequest = new Request(SCORES_FETCH(true, ID, limit, betterThan));
		scoreRequest.onError = onError;
		scoreRequest.onProgress = onProgress;
		scoreRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		scoreRequest.send();
	}

	public function getScore(ID:Int, ?onComplete:Response->Void):Void
	{
		var scoreRequest = new Request(SCORES_GETRANK(1, ID));
		scoreRequest.onError = onError;
		scoreRequest.onProgress = onProgress;
		scoreRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		scoreRequest.send();
	}

	public function getScoreTable(?onComplete:Response->Void)
	{
		var scoreRequest = new Request(SCORES_TABLES);
		scoreRequest.onError = onError;
		scoreRequest.onProgress = onProgress;
		scoreRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		scoreRequest.send();
	}

	public function setData(key:String, data:String, isPrivate:Bool = true, ?onComplete:Response->Void):Void
	{
		var dataRequest = new Request(DATA_SET(key, data, isPrivate));
		dataRequest.onError = onError;
		dataRequest.onProgress = onProgress;
		dataRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		dataRequest.send();
	}

	public function fetchData(key:String, isPrivate:Bool = true, ?onComplete:Response->Void):Void
	{
		var dataRequest = new Request(DATA_FETCH(key, isPrivate));
		dataRequest.onError = onError;
		dataRequest.onProgress = onProgress;
		dataRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		dataRequest.send();
	}

	public function removeData(key:String, isPrivate:Bool = true, ?onComplete:Response->Void):Void
	{
		var dataRequest = new Request(DATA_REMOVE(key, isPrivate));
		dataRequest.onError = onError;
		dataRequest.onProgress = onProgress;
		dataRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		dataRequest.send();
	}

	public function updateData(key:String, operation:DataUpdateType, isPrivate:Bool = true, ?onComplete:Response->Void):Void
	{
		var dataRequest = new Request(DATA_UPDATE(key, operation, isPrivate));
		dataRequest.onError = onError;
		dataRequest.onProgress = onProgress;
		dataRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		dataRequest.send();
	}

	public function getKeysData(isPrivate:Bool = true, ?pattern:Null<String>, ?onComplete:Response->Void):Void
	{
		FileUtil.createFolderIfNotExist(Constants.GAMEJOLT_CLOUD_PATH);

		var keyRequest = new Request(DATA_GETKEYS(isPrivate, pattern));
		keyRequest.onError = onError;
		keyRequest.onProgress = onProgress;
		keyRequest.onComplete = (r:Response) ->
		{
			if (onComplete != null)
				onComplete(r);

			trace('Completed! (${Std.string(r)})');
		};
		keyRequest.send();
	}

	static final GRAVATAR_START_URL:String = 'https://secure.gravatar.com/';
	static final NO_AVATAR_URL:String = 'https://s.gjcdn.net/img/no-avatar-3.png';

	function checkUserData():Void
	{
		if (Api.userName == "" && Api.userToken == "")
			return;

		#if sys
		var userRequest = new Request(USER_FETCH(['${Api.userName}']));
		userRequest.onComplete = (r:Response) ->
		{
			FileUtil.createTJSON(Constants.GAMEJOLT_DATA_FILE_PATH, r);

			print("Connected! (User: " + getUser(r).username + " [" + getUser(r).id + "]");

			setCloudFiles(true);

			if (getUser(r).avatar_url != null)
			{
				imageURLLoader = new URLLoader();
				imageURLLoader.dataFormat = BINARY;
				imageURLLoader.addEventListener(Event.COMPLETE, onCompleteImage);
				imageURLLoader.addEventListener(ErrorEvent.ERROR, onErrorImage);
				imageURLLoader.addEventListener(Event.CANCEL, onCancelImage);
				imageURLLoader.addEventListener(Event.UNLOAD, onUnloadImage);

				if (getUser(r).avatar_url.startsWith(GRAVATAR_START_URL))
					imageURLLoader.load(new URLRequest(NO_AVATAR_URL));
				else
					imageURLLoader.load(new URLRequest(getUser(r).avatar_url));
			}
		};
		userRequest.send();
		#end
	}

	function getUser(res:Response):User
	{
		if (res != null && res.users != null && res.users[0] != null)
			return res.users[0];

		return null;
	}

	function onProgress(fe:Float, tt:Float):Void
		print("Progress: " + fe + ' / ' + tt);

	function onError(msg:String):Void
	{
		if (pingTimer != null)
			pingTimer.cancel();

		print('ERROR: ' + msg);
	}

	function onCompleteImage(e:Event):Void
	{
		FileUtil.writeBytesToPath(Constants.GAMEJOLT_AVATAR_PATH, getURLByteArray(), Force);

		FlxG.game.addChild(new GameJoltNotification(BitmapData.fromFile(Constants.GAMEJOLT_AVATAR_PATH)));
	}

	function onErrorImage(e:ErrorEvent):Void
	{
		print("IMAGE ERROR: " + e.text);
	}

	function onCancelImage(e:Event):Void
	{
		print("IMAGE CANCELLED!");
	}

	function onUnloadImage(e:Event):Void
	{
		print("IMAGE UNLOADED!"); // PICO UNLOADED REFERENCE!!! :OOOOOOO
	}

	function getURLByteArray():ByteArray
	{
		var data:ByteArray;
		if ((imageURLLoader.data is ByteArrayData))
			data = imageURLLoader.data;
		else
		{
			data = new ByteArray();
			data.writeUTFBytes(Std.string(imageURLLoader.data));
		}

		return data;
	}

	static function print(data:String)
	{
		#if debug
		#if sys
		Sys.println('GameJolt Client: $data');
		#else
		trace('GameJolt Client: $data');
		#end
		#end
	}

	static function get_instance():GameJoltClient
	{
		if (GameJoltClient._instance == null)
			_instance = new GameJoltClient();
		if (GameJoltClient._instance == null)
			throw "Could not initialize singleton GameJoltClient!";
		return GameJoltClient._instance;
	}
}

class WaitingSubState extends FlxSubState
{
	public function new(name:String, desc:String):Void
	{
		super(FlxColor.fromRGB(0, 0, 0, 200));

		var mainText:FlxText = new FlxText(0, 125, FlxG.width, name, 32);
		mainText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, OUTLINE);
		mainText.screenCenter(X);
		mainText.scrollFactor.set();
		add(mainText);

		var descText:FlxText = new FlxText(0, 300, FlxG.width - 300, desc, 28);
		descText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER, OUTLINE);
		descText.screenCenter(X);
		descText.scrollFactor.set();
		add(descText);
	}
}
#end
