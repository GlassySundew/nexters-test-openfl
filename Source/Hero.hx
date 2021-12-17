import tools.IntPair;
import AStar.Point;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.Assets;

using tools.ReverseArrayKeyValueIterator;

class Hero extends Sprite {
	/**
		порядковый номер ячейки по x и y, в которой стоит герой
	**/
	public var cellX(default, set) : Int;

	function set_cellX( cellX : Int ) : Int {
		x = cellX * Game.inst.maze.cellSize;
		return this.cellX = cellX;
	}

	public var cellY(default, set) : Int;

	function set_cellY( cellY : Int ) : Int {
		y = cellY * Game.inst.maze.cellSize;
		return this.cellY = cellY;
	}

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

	public var pathCache : Array<AStar.Cell>;

	public function new( cellX : Int, cellY : Int ) {
		super();

		var bitmapData = Assets.getBitmapData("assets/doomguy.png");
		var bitmap = new Bitmap(bitmapData);
		addChild(bitmap);

		this.cellX = cellX;
		this.cellY = cellY;
	}

	public function setCellPosition( cellX : Int, cellY : Int ) {
		this.cellX = cellX;
		this.cellY = cellY;
	}

	public function moveByPath() {
		if ( pathCache != null ) {
			energy++;
			for ( cellI => cell in pathCache ) {
				if ( energy != 0 ) {
					cellX = cell.x;
					cellY = cell.y;
				} else break;

				if ( cellI + 1 != pathCache.length ) {
					for ( edge in Game.inst.maze.edges ) {
						var c1 = IntPair.unmapCell(edge.val1, Game.inst.stat.mazeSize); // cell 1
						var c2 = IntPair.unmapCell(edge.val2, Game.inst.stat.mazeSize); // cell 2
						if ( (c1.val1 == cell.x && c1.val2 == pathCache[cellI + 1].y && c2.val1 == pathCache[cellI + 1].x && c2.val2 == cell.y)
							|| (c2.val1 == cell.x && c2.val2 == pathCache[cellI + 1].y && c1.val1 == pathCache[cellI + 1].x && c1.val2 == cell.y)
						) {
							sledgehammerUses--;
							Game.inst.maze.edges.remove(edge);
							break;
						}
					}
				}
				energy--;
			}

			Game.inst.maze.drawAll();
			Game.inst.removeHeroPath();
			pathCache = null;
		}
	}
}
