import openfl.ui.Keyboard;
import openfl.events.KeyboardEvent;
import openfl.display.Graphics;
import openfl.geom.Point;
import openfl.display.Bitmap;
import openfl.utils.Assets;
import openfl.display.Sprite;

using tools.ReverseArrayKeyValueIterator;

enum ControlStatus {
	Pathfinder;
	HeroTransfer;
	WallEdit;
}

class Game {
	private static var _inst : Game;

	public static var inst(get, set) : Game;

	static function get_inst() : Game {
		return _inst;
	}

	static function set_inst( inst : Game ) : Game {
		if ( _inst != null ) _inst.dispose();
		return _inst = inst;
	}

	public var maze : Maze;

	public var hero : Hero;

	public var stat : GameState;

	public var controlStatus : ControlStatus;

	private var heroPath : Sprite;

	private var parentRoot : SpriteContainer;

	public function new( stat : GameState, parent : SpriteContainer ) {
		inst = this;
		parentRoot = parent;
		this.stat = stat;
		controlStatus = Pathfinder;

		heroPath = new Sprite();

		maze = new Maze(stat.mazeSize);
		maze.x += 5;
		maze.generate();
		maze.addChild(heroPath);
		heroPath.mouseEnabled = false;

		hero = new Hero(0, 0);
		hero.scaleX = maze.cellSize / hero.width;
		hero.scaleY = maze.cellSize / hero.height;
		hero.energy = stat.maxEnergy;
		hero.portals = 1;
		hero.sledgehammerUses = stat.maxSledgehammerUses;

		maze.addChild(hero);

		parent.sprite = maze;

		Main.inst.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
		Main.inst.stage.addEventListener(KeyboardEvent.KEY_UP, keyUp);
	}

	private function keyDown( e : KeyboardEvent ) {
		switch e.keyCode {
			case Keyboard.SHIFT:
				controlStatus = HeroTransfer;
			case Keyboard.CONTROL:
				trace("zhopa");

				controlStatus = WallEdit;
			default:
		}
	}

	private function keyUp( e : KeyboardEvent ) {
		switch e.keyCode {
			case Keyboard.SHIFT | Keyboard.CONTROL:
				controlStatus = Pathfinder;
			default:
		}
	}
	/** calculates and draws path from hero position to point in maze **/
	public function getPathPreviewFromHero( toX : Int, toY : Int ) {
		heroPath.graphics.clear();

		var astar = new AStar(
			{ x : hero.cellX, y : hero.cellY },
			{ x : toX, y : toY },
			stat.mazeSize,
			hero.energy,
			hero.sledgehammerUses,
			stat.teleportCost,
			stat.teleportRadius,
			maze.edges
		);

		var path = astar.findPath();

		if ( path != null ) {
			var availableEnergy = hero.energy;
			path.reverse();

			for ( i => cell in path ) {
				if ( i + 1 == path.length )
					continue;
				availableEnergy--;

				if ( astar.wallExistsBetweenCells(cell, path[i + 1]) ) {
					drawCross(
						(cell.x + Math.abs((path[i + 1].y - cell.y) / 2) + Math.max((path[i + 1].x - cell.x), 0)) * maze.cellSize,
						(cell.y + Math.abs((path[i + 1].x - cell.x) / 2) + Math.max((path[i + 1].y - cell.y), 0)) * maze.cellSize,
						heroPath.graphics);
				}

				if ( availableEnergy < 0 ) {
					heroPath.graphics.lineStyle(4, 0x9b0000, 0.5);
				} else
					heroPath.graphics.lineStyle(4, 0x000000, 0.5);

				heroPath.graphics.moveTo(cell.x * maze.cellSize + maze.cellSize / 2, cell.y * maze.cellSize + maze.cellSize / 2);
				heroPath.graphics.lineTo(path[i + 1].x * maze.cellSize + maze.cellSize / 2, path[i + 1].y * maze.cellSize + maze.cellSize / 2);
			}
			hero.pathCache = path;

			maze.displayTooltip(
				(path[path.length - 1].x + 2) * maze.cellSize,
				path[path.length - 1].y * maze.cellSize,
				'cost: ${path.length - 1}');
		}

		heroPath.graphics.endFill();
	}

	private function drawCross( x : Float, y : Float, graphics : Graphics ) {
		graphics.lineStyle(4, 0x69077e, 0.7);
		graphics.moveTo(x - 5, y - 5);
		graphics.lineTo(x + 5, y + 5);

		graphics.moveTo(x - 5, y + 5);
		graphics.lineTo(x + 5, y - 5);
	}

	public function removeHeroPath() {
		heroPath.graphics.clear();
		maze.hideToolTip();
	}

	public function endTurn( _ ) {
		hero.energy = stat.maxEnergy;
		hero.sledgehammerUses = stat.maxSledgehammerUses;
		hero.portals = 1;
	}

	public function clearMap( _ ) {
		untyped maze.edges.length = 0;
		maze.drawAll();
	}

	function dispose() {
		parentRoot.sprite.removeChildren();
		maze.graphics.clear();
		if ( heroPath != null ) heroPath.graphics.clear();
		maze = null;

		Main.inst.removeEventListener(KeyboardEvent.KEY_DOWN, keyDown);
		Main.inst.removeEventListener(KeyboardEvent.KEY_UP, keyUp);
	}
}
