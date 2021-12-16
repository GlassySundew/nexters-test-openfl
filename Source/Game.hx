import openfl.geom.Point;
import openfl.display.Bitmap;
import openfl.utils.Assets;
import openfl.display.Sprite;

using tools.ReverseArrayKeyValueIterator;

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

	private var hero : Hero;

	public var stat : GameState;

	private var heroPath : Sprite;

	private var parentRoot : SpriteContainer;

	public function new( stat : GameState, parent : SpriteContainer ) {
		inst = this;
		parentRoot = parent;
		this.stat = stat;

		heroPath = new Sprite();

		maze = new Maze(stat.mazeSize);
		maze.x += 5;
		maze.generate();
		maze.addChild(heroPath);

		hero = new Hero(0, 0);
		hero.scaleX = maze.cellSize / hero.width;
		hero.scaleY = maze.cellSize / hero.height;
		hero.energy = stat.maxEnergy;
		hero.portals = 1;
		hero.sledgehammerUses = stat.maxSledgehammerUses;

		maze.addChild(hero);

		parent.sprite = maze;
	}
	/** calculates and draws path from hero position to point in maze **/
	public function getPathPreviewFromHero( to : Point ) {
		heroPath.graphics.clear();

		var path = new AStar(
			{ x : hero.cell.x, y : hero.cell.y },
			{ x : Std.int(to.x), y : Std.int(to.y) },
			stat.mazeSize,
			hero.energy,
			hero.sledgehammerUses,
			stat.teleportCost,
			stat.teleportRadius,
			maze.edges
		).findPath();

		var availableEnergy = hero.energy + 1;
		heroPath.graphics.lineStyle(4, 0x000000, 0.5);

		if ( path != null ) {
			for ( i => cell in path.reversedKeyValues() ) {
				if ( availableEnergy < 1 )
					heroPath.graphics.lineStyle(4, 0x9b0000, 0.5);
				availableEnergy--;
				try {
					heroPath.graphics.moveTo(cell.x * maze.cellSize + maze.cellSize / 2, cell.y * maze.cellSize + maze.cellSize / 2);
					heroPath.graphics.lineTo(path[i + 1].x * maze.cellSize + maze.cellSize / 2, path[i + 1].y * maze.cellSize + maze.cellSize / 2);
				} catch( e ) {}
				// heroPath.graphics.drawRect(path[i + 1].x * maze.cellSize, path[i + 1].y * maze.cellSize, maze.cellSize, maze.cellSize);
			}
		}

		heroPath.graphics.endFill();
	}

	public function removeHeroPath() {
		// heroPath.graphics.clear();
	}

	public function endTurn( _ ) {
		hero.energy = stat.maxEnergy;
		hero.sledgehammerUses = stat.maxSledgehammerUses;
		hero.portals = 1;
	}

	public function clearMap( _ ) {
		maze.edges.resize(0);
		maze.drawAll();
	}

	function dispose() {
		parentRoot.sprite.removeChildren();
		maze.graphics.clear();
		if ( heroPath != null ) heroPath.graphics.clear();
		maze = null;
		// hero = null;
	}
}
