/*
 */

package;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import openfl.ui.Keyboard;
import openfl.events.KeyboardEvent;
import openfl.filters.DropShadowFilter;
import away3d.lights.PointLight;
import openfl.display.Sprite;
import openfl.net.URLRequest;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Vector3D;
import openfl.Vector;
import away3d.containers.View3D;
import away3d.lights.DirectionalLight;
import away3d.materials.lightpickers.StaticLightPicker;
import away3d.materials.methods.SoftShadowMapMethod;
import away3d.containers.ObjectContainer3D;
import away3d.controllers.HoverController;
import away3d.primitives.PlaneGeometry;
import away3d.primitives.CubeGeometry;
import away3d.primitives.SkyBox;
import away3d.library.Asset3DLibrary;
import away3d.loaders.parsers.DAEParser;
import away3d.loaders.misc.AssetLoaderContext;
import away3d.events.Asset3DEvent;
import away3d.entities.*;
import away3d.library.assets.IAsset;
import away3d.library.assets.Asset3DType;
import away3d.materials.SinglePassMaterialBase;
import away3d.utils.Cast;
import away3d.textures.BitmapCubeTexture;
import away3d.materials.TextureMaterial;
import openfl.display.BitmapData;
import openfl.Assets;
import openfl.Lib;
import openfl.text.*;
import openfl.net.SharedObject;
import hxSerial.Serial;

class Main extends Sprite {
	// engine variables
	var view:View3D;
	var _cameraController:HoverController;

	// light objects
	var _light:DirectionalLight;
	var _plight:PointLight;
	var _lightPicker:StaticLightPicker;
	var _direction:Vector3D;
	var _shadow:SoftShadowMapMethod;

	// scene objects and materials
	var skyBox:SkyBox;
	var target:ObjectContainer3D;
	var spaceShip:SpaceShip;
	var cubeTexture:BitmapCubeTexture;
	var shipMaterials:Map<String, SinglePassMaterialBase> = [];

	// animation vars
	var _counter:Float;
	var spaceshipPivot:Vector3D;

	// navigation variables
	var _move:Bool;
	var _lastPanAngle:Float;
	var _lastTiltAngle:Float;
	var _lastMouseX:Float;
	var _lastMouseY:Float;

	//
	var serialObj:hxSerial.Serial;
	var deviceList:Array<String> = [];
	var serialPortIndex:Int = 0;
	var serialBuffer:String = "";
	var sInput:String;
	var serialConnected:Bool = false;
	var text:TextField;

	// input from micro:bit
	var xSmooth:Array<Int> = [0, 0, 0, 0, 0, 0];
	var zSmooth:Array<Int> = [0, 0, 0, 0, 0, 0];
	var btnA:Bool;
	var btnB:Bool;
	var so:SharedObject;

	var shipSpeed:Int = 10;

	var storedPortPath:String;
	/**
	 * Constructor
	 */
	public function new() {
		super();
		init();
	}

	/**
	 * Global initialise function
	 */
	private function init():Void {
		initEngine();
		initText();
		initLights();
		initMaterials();
		initObjects();
		initListeners();
		
		storedPortPath = haxe.io.Path.join([lime.system.System.applicationStorageDirectory, "port.txt"]);
		connectSerialPortByIndex(readStoredPortIndex());
	}

	/**
	 * read stored portIndex from file
	 * @return Int
	 */
	function readStoredPortIndex():Int {
		#if sys
		if (FileSystem.exists(storedPortPath)) {
			serialPortIndex = Std.parseInt(sys.io.File.getContent(storedPortPath));
			return serialPortIndex;
		} else {
			return 0;
		}
		#end
		return 0;
	}

	/**
	 * save portIndex to file
	 */
	function saveStoredPortIndex() {
		#if sys
		File.saveContent(storedPortPath, '$serialPortIndex');
		#end
	}

	/**
	 * Connect to the a SerialPort by Index
	 * @param i PortIndex
	 */
	function connectSerialPortByIndex(i:Int) {
		if (serialObj != null) {
			if (serialObj.isSetup) {
				serialObj.close();
			}
		}

		deviceList = Serial.getDeviceList();

		if (i >= 0 && i < deviceList.length) {
			serialObj = new hxSerial.Serial(deviceList[i], 115200, true);
			text.text = 'connected to ${serialObj.portName}';
			serialConnected = true;
			serialPortIndex = i;
		} else {
			text.text = 'SerialPort index $i is not available';
		}
	}

	/**
	 * Connect to the next SerialPort if available
	 */
	function nextPort() {
		if (deviceList != null) {
			if (serialPortIndex < deviceList.length - 2) {
				connectSerialPortByIndex(serialPortIndex + 1);
			}
		}
	}

	/**
	 * Connect to the previous SerialPort if available
	 */
	function previousPort() {
		if (deviceList != null) {
			if (serialPortIndex < 0) {
				connectSerialPortByIndex(serialPortIndex - 1);
			}
		}
	}

	/**
	 * Initialise the engine
	 */
	private function initEngine():Void {
		_counter = 0;

		view = new View3D();
		view.camera.z = 1000;
		this.addChild(view);

		// set the background of the view to something suitable
		view.backgroundColor = 0x1e2125;

		target = new ObjectContainer3D();
		target.y = 250;

		// setup controller to be used on the camera
		_cameraController = new HoverController(view.camera, target);
		_cameraController.distance = 1000;
		_cameraController.minTiltAngle = -35;
		_cameraController.maxTiltAngle = 35;
		_cameraController.panAngle = 15;
		_cameraController.tiltAngle = 10;

		// stats
		// this.addChild(new away3d.debug.AwayFPS(view, 10, 10, 0xffffff, 3));
	}

	/**
	 * Create an instructions overlay
	 */
	private function initText():Void {
		text = new TextField();
		text.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF);
		text.embedFonts = true;
		text.antiAliasType = AntiAliasType.ADVANCED;
		text.gridFitType = GridFitType.PIXEL;
		text.width = 240;
		text.height = 100;
		text.selectable = false;
		text.mouseEnabled = false;
		text.text = "";

		text.filters = [new DropShadowFilter(1, 45, 0x0, 1, 0, 0)];

		addChild(text);
	}

	/**
	 * Initialise the lights
	 */
	private function initLights():Void {
		// create the light for the scene

		_plight = new PointLight();
		_plight.color = 0x808080;
		_plight.ambient = 8;
		_plight.ambientColor = 0x567a8a;
		_plight.diffuse = 2.2;
		_plight.specular = 0.8;

		_light = new DirectionalLight();
		_light.color = 0x808080;
		_light.direction = new Vector3D(0.4, -0.3, -0.4);
		_light.ambient = 2;
		_light.ambientColor = 0x567a8a;
		_light.diffuse = 2.2;
		_light.specular = 0.8;
		view.scene.addChild(this._light);
		view.scene.addChild(this._plight);

		// create the lightppicker for the material
		_lightPicker = new StaticLightPicker([this._light, this._plight]);
	}

	/**
	 * Initialise the materials
	 */
	private function initMaterials():Void {
		#if !ios
		_shadow = new SoftShadowMapMethod(_light, 15, 10);
		_shadow.epsilon = 0.2;
		#end

		cubeTexture = new BitmapCubeTexture(Cast.bitmapData("assets/skybox/space_posX.jpg"), Cast.bitmapData("assets/skybox/space_negX.jpg"),
			Cast.bitmapData("assets/skybox/space_posY.jpg"), Cast.bitmapData("assets/skybox/space_negY.jpg"), Cast.bitmapData("assets/skybox/space_posZ.jpg"),
			Cast.bitmapData("assets/skybox/space_negZ.jpg"));
	}

	/**
	 * Initialise the scene objects
	 */
	private function initObjects():Void {
	
		spaceShip = new SpaceShip(_lightPicker);
		spaceShip.scale(50);
		spaceShip.y = 150;
		spaceShip.z = 150;

		// create a skybox
		skyBox = new SkyBox(cubeTexture);
		view.scene.addChild(skyBox);
		view.scene.addChild(spaceShip);
	}

	/**
	 * Initialise the listeners
	 */
	private function initListeners():Void {
		// setup render loop
		addEventListener(Event.ENTER_FRAME, onEnterFrame);

		// add mouse and resize events
		stage.addEventListener(Event.RESIZE, onResize);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		onResize();
	}

	/**
	 * parse serial data
	 */
	private function parseSerial() {
		if (serialConnected) {
			var bytesAvailable = serialObj.available();

			if (bytesAvailable > 0) {
				serialBuffer += serialObj.readBytes(bytesAvailable);

				// if there's a line feed?
				if (serialBuffer.indexOf('\n') != -1) {
					
					// remove any \r characters
					StringTools.replace(serialBuffer, "\r","");

					// is the newline at the end of the buffer?
					var noBytesAfterNewline = serialBuffer.lastIndexOf('\n') == serialBuffer.length - 1;
					
					// split lines
					var lines:Array<String> = serialBuffer.split("\n");
					
					// TODO: handle All Lines, not just the first
					sInput = lines[0];
					var temp = sInput.split(',');
					
					if (temp.length > 2) {
						zSmooth.unshift(Std.parseInt(temp[0]));
						zSmooth.pop();
						xSmooth.unshift(Std.parseInt(temp[1]));
						xSmooth.pop();
					}
					if (temp.length == 4) {
						btnA = temp[2] == "1";
						btnB = temp[3] == "1";
					}

					if (noBytesAfterNewline) {
						serialBuffer = "";
					} else {
						serialBuffer = lines[lines.length - 1];
					}
				}
			}
		}
	}

	/**
	 * Navigation and render loop
	 */
	private function onEnterFrame(e:Event):Void {
		parseSerial();

		_counter = Lib.getTimer() / 500;

		spaceShip.setShipEngine(btnA);

		if (spaceShip != null) {
			spaceShip.rotationX = Math.min(45, Math.max(-45, arrayAverage(xSmooth)));
			spaceShip.rotationZ = Math.min(89, Math.max(-89, arrayAverage(zSmooth)));
			if (_move) {
				_cameraController.panAngle = 0.3 * (stage.mouseX - _lastMouseX) + _lastPanAngle;
				_cameraController.tiltAngle = 0.3 * (stage.mouseY - _lastMouseY) + _lastTiltAngle;
			} else {
				_cameraController.panAngle = _lastPanAngle + arrayAverage(zSmooth) * .25;
				_cameraController.tiltAngle = _lastTiltAngle - arrayAverage(xSmooth) * .25;
			}
		}
		skyBox.lookAt(target.position);
		view.render();
	}

	/**
	 * Calculate array Average
	 * @param a 
	 */
	private function arrayAverage(a:Array<Int>) {
		var asum = 0;
		for (index in 0...a.length) {
			asum += a[index];
		}
		return asum / a.length;
	}

	/**
	 * Mouse down listener for navigation
	 */
	private function onMouseDown(event:MouseEvent):Void {
		_lastPanAngle = _cameraController.panAngle;
		_lastTiltAngle = _cameraController.tiltAngle;
		_lastMouseX = stage.mouseX;
		_lastMouseY = stage.mouseY;
		_move = true;
		stage.addEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
	}

	/**
	 * KeyUp listener for stage
	 */
	private function onKeyUp(event:KeyboardEvent) {
		switch (event.keyCode) {
			case Keyboard.RIGHTBRACKET:
				nextPort();

			case Keyboard.LEFTBRACKET:
				previousPort();

			case Keyboard.S:
				saveStoredPortIndex();
		}
	}

	/**
	 * Mouse up listener for navigation
	 */
	private function onMouseUp(event:MouseEvent):Void {
		_move = false;
		_lastPanAngle = _cameraController.panAngle;
		_lastTiltAngle = _cameraController.tiltAngle;
		stage.removeEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
	}

	/**
	 * Mouse stage leave listener for navigation
	 */
	private function onStageMouseLeave(event:Event):Void {
		_move = false;
		stage.removeEventListener(Event.MOUSE_LEAVE, onStageMouseLeave);
	}

	/**
	 * stage listener for resize events
	 */
	private function onResize(event:Event = null):Void {
		view.width = stage.stageWidth;
		view.height = stage.stageHeight;
	}
}
