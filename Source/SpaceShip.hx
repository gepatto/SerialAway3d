package;

import away3d.materials.lightpickers.StaticLightPicker;
import away3d.containers.ObjectContainer3D;
import away3d.entities.Mesh;
import away3d.loaders.misc.AssetLoaderContext;
import away3d.materials.SinglePassMaterialBase;
import away3d.library.assets.IAsset;
import openfl.Assets;
import away3d.events.Asset3DEvent;
import away3d.loaders.parsers.DAEParser;
import away3d.library.Asset3DLibrary;
import away3d.core.base.Object3D;
import away3d.library.assets.Asset3DType;

class SpaceShip extends ObjectContainer3D {

	var materials:Map<String,SinglePassMaterialBase> = [];
	var _lightPicker:StaticLightPicker;

    /**
	 * Constructor
	 */
	public function new( _lp:StaticLightPicker) {
		super();

		_lightPicker = _lp;

		init();
	}

    private function init(){
		var assetLoaderContext:AssetLoaderContext = new AssetLoaderContext();
		// assetLoaderContext.mapUrlToData("../images/someImage.jpg", Assets.getBitmapData("assets/someImage.jpg"));

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
				var mesh = cast(asset, Mesh);
				this.addChild(mesh);

			case Asset3DType.MATERIAL:
				var material:SinglePassMaterialBase = cast(asset, SinglePassMaterialBase);
				materials.set(material.name, material);
				material.ambientColor = 0xffffff;
				material.lightPicker = _lightPicker;
		}
	}

	public function setShipEngine( on:Bool){
		if (materials.exists('fireMaterial-material')) {
			if (on) {
				materials.get('fireMaterial-material').gloss = Math.random();
				materials.get('fireMaterial-material').colorTransform.blueMultiplier = .6 + Math.random();
				materials.get('fireMaterial-material').colorTransform.greenMultiplier = .3 + Math.random();
			} else {
				materials.get('fireMaterial-material').colorTransform.blueMultiplier = .2;
				materials.get('fireMaterial-material').colorTransform.redMultiplier = .1;
				materials.get('fireMaterial-material').colorTransform.greenMultiplier = 0;
			}
		}
	}
}