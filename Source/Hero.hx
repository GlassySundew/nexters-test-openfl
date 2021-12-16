import AStar.Point;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.Assets;

class Hero extends Sprite {
	/**
		порядковый номер ячейки по x и y, в которой стоит герой
	**/
	public var cell : Point;

	public var energy(default, set) : Int;

	function set_energy( v : Int ) {
		Main.inst.uiManager.setEnergyDisplay(v);
		return energy = v;
	}

	public var sledgehammerUses(default, set) : Int;

	function set_sledgehammerUses( e : Int ) {
		Main.inst.uiManager.setSledgehammerUsesDisplay(e);
		return sledgehammerUses = e;
	}

	public var portals(default, set) : Int;

	function set_portals( e : Int ) {
		Main.inst.uiManager.setPortalsUsesDisplay(e);
		return portals = e;
	}

	public function new( cellX : Int, cellY : Int ) {
		super();

		// почему-то перестало работать
		var bitmapData = Assets.getBitmapData("assets/doomguy.png");
		var bitmap = new Bitmap(bitmapData);
		addChild(bitmap);

		cell = { x : cellX, y : cellY };

	}
}
