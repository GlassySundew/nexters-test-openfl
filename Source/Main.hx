package;

import tools.BinaryHeapPQ;
import mazePreset.Presets;
import haxe.ui.events.MouseEvent;
import openfl.Lib;
import haxe.ui.HaxeUIApp;
import haxe.ui.Toolkit;
import haxe.ui.containers.VBox;
import openfl.display.Sprite;
import openfl.text.TextField;

using tools.BinaryHeapPQ;

class Main extends Sprite {
	public static var inst : Main;

	public var uiManager : UiManager;

	public function new() {
		super();
		inst = this;

		Lib.current.stage.color = 0x25292e;

		Toolkit.theme = "dark";

		var app = new HaxeUIApp();
		app.ready(function () {
			uiManager = new UiManager();

			app.addComponent(uiManager);
			uiManager.initConfig();
			newGame(null);
			app.start();
		});
	}

	@:allow(Game)
	private function newGame( e : MouseEvent ) {
		new Game(
			uiManager.getGameConfig(),
			uiManager.mazeSpriteContainer
		);
	}
}

@:build(haxe.ui.ComponentBuilder.build("Assets/main.xml"))
private class UiManager extends VBox {
	@:allow(Main)
	private var mazeSpriteContainer : SpriteContainer;

	public function new() {
		super();
	}

	public function initConfig() {
		mazeSpriteContainer = new SpriteContainer();
		mazeBoxContainer.addChild(mazeSpriteContainer);

		isolationTestPresetButton.onClick = ( e ) -> {
			Game.inst.maze.applyPreset(Presets.isolationPreset);
		};

		costOptimalityTestPresetButton.onClick = (e) -> {
			Game.inst.maze.applyPreset(Presets.costOptimalityPreset);
		}
	}

	public function getGameConfig() : GameState {
		function maxWith0( text : String )
			return Std.int(Math.max(Std.parseInt(text), 0));

		return {
			mazeSize : maxWith0(mConfig.text),
			maxEnergy : maxWith0(eConfig.text),
			maxSledgehammerUses : maxWith0(wConfig.text),
			teleportCost : maxWith0(tConfig.text),
			teleportRadius : maxWith0(rConfig.text),
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
