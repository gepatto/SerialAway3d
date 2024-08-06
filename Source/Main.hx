/*
 */

package;

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
	var spaceShip:ObjectContainer3D;
	var target:ObjectContainer3D;
	var skyBox:SkyBox;
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
	var deviceList:Array<String> = [];
	var serialObj:hxSerial.Serial;
	var serialBuffer:String = "";

	var sInputArray:Array<String> = [];
	var sInput:String;
	var serialConnected:Bool = false;
	var text:TextField;

	// input from micro:bit
	var xSmooth:Array<Int> = [0, 0, 0, 0, 0, 0];
	var zSmooth:Array<Int> = [0, 0, 0, 0, 0, 0];
	var btnA:Bool;
	var btnB:Bool;

	var shipSpeed:Int = 10;

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

		deviceList = Serial.getDeviceList();
		trace(deviceList);
		
		if (deviceList.length > 0) {
			serialObj = new hxSerial.Serial(deviceList[deviceList.length - 1], 115200, true);
			serialConnected = true;
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
		spaceShip = new ObjectContainer3D();
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
		onResize();

		// setup the url map for textures in the 3ds file
		var assetLoaderContext:AssetLoaderContext = new AssetLoaderContext();
		// assetLoaderContext.mapUrlToData("../images/Material1noCulling.jpg", Assets.getBitmapData("assets/Material1noCulling.jpg"));
		// assetLoaderContext.mapUrlToData("../images/Color_009noCulling.jpg", Assets.getBitmapData("assets/Color_009noCulling.jpg"));

		Asset3DLibrary.enableParser(DAEParser);
		Asset3DLibrary.addEventListener(Asset3DEvent.ASSET_COMPLETE, onAssetComplete);
		Asset3DLibrary.loadData(Assets.getBytes('assets/spaceship_lowpoly.dae'), assetLoaderContext);
	}

	/**
	 * Listener function for asset complete event on loader
	 */
	private function onAssetComplete(event:Asset3DEvent) {
		var asset:IAsset = event.asset;

		switch (asset.assetType) {
			case Asset3DType.MESH:
				var spaceShipMesh = cast(asset, Mesh);
				spaceShip.addChild(spaceShipMesh);

			case Asset3DType.MATERIAL:
				var material:SinglePassMaterialBase = cast(asset, SinglePassMaterialBase);
				shipMaterials.set(material.name, material);
				material.ambientColor = 0xffffff;
				material.lightPicker = _lightPicker;
		}
	}

	private function parseSerial() {
		if (serialConnected) {
			var bytesAvailable = serialObj.available();

			if (bytesAvailable > 0) {
				serialBuffer += serialObj.readBytes(bytesAvailable);

				// if there's a line feed?
				if (serialBuffer.indexOf('\n') != -1) {
					// is the newline at the end of the buffer?
					var noBytesAfterNewline = serialBuffer.lastIndexOf('\n') == serialBuffer.length - 1;

					// split lines
					var lines:Array<String> = serialBuffer.split("\n");

					var lastCompleteLine = 0;
					if (lines.length > 2) {
						// nummber of lines depends on the speed the microcontroller sends its data
						// if the newline was at the end of the buffer, the last item will be empty, so get the secondlast item
						lastCompleteLine = noBytesAfterNewline ? lines.length - 2 : 0;
					}
					sInput = lines[lastCompleteLine];

					var temp = sInput.split(',');
					if (temp.length > 2) {
						sInputArray = temp;
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

		if (shipMaterials.exists('fireMaterial-material')) {
			if (btnA) {
				shipMaterials.get('fireMaterial-material').gloss = Math.random();
				shipMaterials.get('fireMaterial-material').colorTransform.blueMultiplier = .6 + Math.random();
				shipMaterials.get('fireMaterial-material').colorTransform.greenMultiplier = .3  + Math.random();
			}else{
				shipMaterials.get('fireMaterial-material').colorTransform.blueMultiplier = .2;
				shipMaterials.get('fireMaterial-material').colorTransform.redMultiplier = .1;
				shipMaterials.get('fireMaterial-material').colorTransform.greenMultiplier = 0;
			}
		}

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
