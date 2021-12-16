import openfl.geom.ColorTransform;
import openfl.events.MouseEvent;
import js.html.Event;
import openfl.geom.Point;
import openfl.display.InteractiveObject;
import openfl.display.Sprite;
import openfl.display.Tilemap;
import tools.KruskalMazeGen;

private class InteractiveCell extends Sprite {
	public var coord : Point;

	public function new( cellX : Int, cellY : Int, size : Int ) {
		super();
		x = cellX * size;
		y = cellY * size;

		coord = new Point(cellX, cellY);

		graphics.beginFill(0x000000, 0);
		graphics.drawRect(0 - 1, 0 - 1, size + 1, size + 1);
		graphics.endFill();

		this.addEventListener(MouseEvent.MOUSE_OVER, ( e ) -> {
			Game.inst.getPathPreviewFromHero(coord);
		});

		this.addEventListener(MouseEvent.MOUSE_OUT, ( e ) -> {
			Game.inst.removeHeroPath();
		});
	}

	function drawPath() {}

	function removePath() {}
}

class Maze extends Sprite {
	public var edges(get, never) : Array<tools.IntPair>;
	function get_edges() {
		return kruskal.edges;
	}
	public final cellSize = 20;

	private var wallsSprite : Sprite;

	private var tilemap : Tilemap;
	private var kruskal : KruskalMazeGen;

	private var size : Int;

	private var backgroundColor = 0x999999;
	private var cellGridColor = 0x707070;
	private var wallColor = 0xececec;

	public function new( m : Int ) {
		super();
		size = m;
	}

	public function generate() {
		// Kruskal's maze gen algorithm http://weblog.jamisbuck.org/2011/1/3/maze-generation-kruskal-s-algorithm
		kruskal = new KruskalMazeGen(size, cellSize);
		kruskal.generate();
		addChild(kruskal);

		drawAll();

		for ( y in 0...size ) {
			for ( x in 0...size ) {
				var interactiveCell = new InteractiveCell(x, y, cellSize);
				this.addChild(interactiveCell);
			}
		}
	}

	public function drawAll() {

		graphics.clear();
		kruskal.graphics.clear();

		// one piece ground background
		graphics.beginFill(backgroundColor);
		graphics.drawRect(0, 0, size * cellSize, size * cellSize);
		graphics.endFill();

		// cell grid
		graphics.lineStyle(2, cellGridColor, 0.75);
		for ( y in 0...size ) {
			for ( x in 0...size ) {
				drawBorderSquare(x * cellSize, y * cellSize, cellSize, cellSize);
			}
		}
		graphics.endFill();

		// drawing walls
		redrawWalls();
	}

	private function redrawWalls() {
		kruskal.drawWalls(wallColor);

		// border walls
		graphics.lineStyle(4, wallColor);
		drawBorderSquare(0, 0, size * cellSize, size * cellSize);
	}
	/**
		must lineStyle before doing this, used for making border tiles
	**/
	function drawBorderSquare( x : Int, y : Int, width : Int, height : Int ) {
		graphics.moveTo(x, y);
		graphics.lineTo(x + width, y);
		graphics.lineTo(x + width, y + height);
		graphics.lineTo(x, y + height);
		graphics.lineTo(x, y);
	}
}
