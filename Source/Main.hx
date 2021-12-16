package;

import openfl.display.Bitmap;
import openfl.Assets;
import haxe.ui.components.Label;
import haxe.ui.events.MouseEvent;
import haxe.ui.components.Button;
import haxe.ui.core.ItemRenderer;
import haxe.ui.containers.VBox;
import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;
import haxe.ui.components.TextArea;
import haxe.ui.containers.ListView;
import haxe.ui.core.Component;
import haxe.ui.macros.ComponentMacros;
import openfl.Lib;
import openfl.display.Sprite;

class Main extends Sprite {
	public static var inst : Main;

	public var uiManager : UiManager;

	public function new() {
		super();
		inst = this;

		Lib.current.stage.color = 0x25292e;

		Toolkit.init();
		Toolkit.theme = "dark";

		var app = new HaxeUIApp();
		app.ready(function () {
			var uiRoot = ComponentMacros.buildComponent("Assets/main.xml");

			uiManager = new UiManager(uiRoot);
			uiManager.initConfig();

			function newGame( e : MouseEvent ) {
				new Game(
					uiManager.getGameConfig(),
					uiManager.mazeSpriteContainer
				);
			}

			newGame(null);

			uiManager.refresherButton.onClick = newGame;
			uiManager.mazeClearButton.onClick = Game.inst.clearMap;

			uiManager.setEnergyDisplay(Game.inst.stat.maxEnergy);
			uiManager.setSledgehammerUsesDisplay(Game.inst.stat.maxSledgehammerUses);
			uiManager.setPortalsUsesDisplay(1);

			app.addComponent(uiRoot);
			app.start();
		});
	}
}

private class UiManager {
	@:allow(Main)
	private var mazeSpriteContainer : SpriteContainer;

	@:allow(Main)
	private var refresherButton : Button;
	@:allow(Main)
	private var mazeClearButton : Button;
	private var uiRoot : Component;
	private var energyDisplayLabel : Label;
	private var sledgehammerDisplayLabel : Label;
	private var portalsDisplayLabel : Label;
	private var mConfig : TextArea;
	private var eConfig : TextArea;
	private var wConfig : TextArea;
	private var rConfig : TextArea;
	private var tConfig : TextArea;

	public function new( uiRoot : Component ) {
		this.uiRoot = uiRoot;
	}

	public function initConfig() {
		mazeSpriteContainer = new SpriteContainer();
		var mazeBoxContainer : ItemRenderer = uiRoot.findComponent("mazeBoxContainer");
		mazeBoxContainer.addChild(mazeSpriteContainer);

		refresherButton = uiRoot.findComponent("refresher");
		mazeClearButton = uiRoot.findComponent("mazeClear");
		mConfig = uiRoot.findComponent("mConfig");
		eConfig = uiRoot.findComponent("eConfig");
		wConfig = uiRoot.findComponent("wConfig");
		rConfig = uiRoot.findComponent("rConfig");
		tConfig = uiRoot.findComponent("tConfig");

		energyDisplayLabel = uiRoot.findComponent("energyDisplayLabel");
		sledgehammerDisplayLabel = uiRoot.findComponent("sledgehammerDisplayLabel");
		portalsDisplayLabel = uiRoot.findComponent("portalsDisplayLabel");
	}

	public function getGameConfig() : GameState {
		return {
			mazeSize : Std.parseInt(mConfig.text),
			maxEnergy : Std.parseInt(eConfig.text),
			maxSledgehammerUses : Std.parseInt(wConfig.text),
			teleportCost : Std.parseInt(tConfig.text),
			teleportRadius : Std.parseInt(rConfig.text),
		}
	}

	public function setEnergyDisplay( e : Int ) {
		energyDisplayLabel.text = '$e / ${Game.inst.stat.maxEnergy}';
	}

	public function setSledgehammerUsesDisplay( s : Int ) {
		sledgehammerDisplayLabel.text = '$s / ${Game.inst.stat.maxSledgehammerUses}';
	}

	public function setPortalsUsesDisplay( p : Int ) {
		portalsDisplayLabel.text = '$p / 1';
	}
}
