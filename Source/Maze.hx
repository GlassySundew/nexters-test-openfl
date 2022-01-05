import mazePreset.Presets.Preset;
import js.lib.Set;
import tools.IntPair;
import openfl.text.TextField;
import openfl.geom.ColorTransform;
import openfl.events.MouseEvent;
import js.html.Event;
import openfl.geom.Point;
import openfl.display.InteractiveObject;
import openfl.display.Sprite;
import openfl.display.Tilemap;
import tools.KruskalMazeGen;

private class InteractiveCell extends Sprite {
	public var cellX : Int;
	public var cellY : Int;

	public function new( cellX : Int, cellY : Int, size : Int ) {
		super();
		x = cellX * size;
		y = cellY * size;

		this.cellX = cellX;
		this.cellY = cellY;

		graphics.beginFill(0x000000, 0);
		graphics.drawRect(0 - 1, 0 - 1, size + 1, size + 1);
		graphics.endFill();

		this.addEventListener(MouseEvent.MOUSE_OVER, cellOnOver);
		this.addEventListener(MouseEvent.MOUSE_OUT, cellOnOut);
		this.addEventListener(MouseEvent.CLICK, cellOnClick);
	}

	private function cellOnOver( _ ) {
		switch Game.inst.controlStatus {
			case Pathfinder:
				Game.inst.getPathPreviewFromHero(cellX, cellY);
			default:
		}
	}

	private function cellOnOut( _ ) {
		Game.inst.removeHeroPath();
	}

	private function cellOnClick( e ) {

		switch Game.inst.controlStatus {
			case HeroTransfer:
				Game.inst.hero.setCellPosition(cellX, cellY);
			case WallEdit:
				Game.inst.maze.toggleWallsInCell(cellX, cellY, e);
			case Pathfinder:
				Game.inst.hero.moveByPath();
			default:
		}
	}
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
	private var toolTip : Sprite;

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

	public function displayTooltip( x : Int, y : Int, string : String ) {
		if ( toolTip == null ) {
			toolTip = new Sprite();
			addChild(toolTip);
		}
		var text = new TextField();
		text.text = string;
		text.textColor = 0xffffff;
		text.invalidate();

		toolTip.visible = true;
		toolTip.x = x;
		toolTip.y = y;
		toolTip.removeChildren();
		toolTip.graphics.clear();
		toolTip.graphics.beginFill(0x000000, 0.55);
		toolTip.graphics.drawRoundRect(-5, 0, text.textWidth + 15, text.textHeight + 10, 6, 6);
		toolTip.addChild(text);
		toolTip.mouseEnabled = false;
		text.mouseEnabled = false;
		toolTip.scaleX = toolTip.scaleY = 1.2;
	}

	public function hideToolTip() {
		if ( toolTip != null )
			toolTip.visible = false;
	}

	/** 
		if any cell present, will remove everything, if no cells present, will place 4 walls around
	**/
	public function toggleWallsInCell( x : Int, y : Int, e : MouseEvent ) {

		var secondCell : { x : Int, y : Int } = null;

		if ( e.localX < e.localY ) {
			if ( e.localY < -e.localX + cellSize ) {
				// left
				if ( x > 0 ) secondCell = { x : x - 1, y : y };
			} else {
				// bottom
				if ( y < size - 1 ) secondCell = { x : x, y : y + 1 };
			}
		}
		else {
			if ( e.localY < -e.localX + cellSize ) {
				// top
				if ( y > 0 ) secondCell = { x : x, y : y - 1 };
			} else {
				// right
				if ( x < size - 1 ) secondCell = { x : x + 1, y : y };
			}
		}

		if ( secondCell != null ) {
			var wallRemoved = false;

			var edge = IntPair.findWallBetweenTwoCells(
				{ x : x, y : y },
				{ x : secondCell.x, y : secondCell.y },
				new Set(edges), size
			);

			if ( edge != null ) {
				edges.remove(edge);
				wallRemoved = true;
			}

			if ( !wallRemoved ) {
				edges.push(new IntPair(IntPair.mapCell(x, y, size), IntPair.mapCell(secondCell.x, secondCell.y, size)));
			}

			drawAll();
		}
	}

	public function addRandomWalls( amount : Int ) {
		var walls = [];
		trace(amount);

		var edgesSet = new Set(edges);
		var coordinateOffset = [{ x : 1, y : 0 }, { x : 0, y : 1 }];

		for ( y in 0...size - 2 ) {
			for ( x in 0...size - 2 ) {
				for ( offset in coordinateOffset ) {
					if ( !IntPair.wallExistsBetweenCells(
						{ x : x, y : y },
						{ x : x + offset.x, y : y + offset.y },
						edgesSet,
						size) ) {
						walls.push(
							new IntPair(
								IntPair.mapCell(x, y, size),
								IntPair.mapCell(x + offset.x, y + offset.y, size))
						);
					}
				}
			}
		}

		for ( i in 0...amount - 1 ) {
			var wall = walls[Std.random(walls.length - 1)];

			edges.push(wall);
			walls.remove(wall);
		}

		redrawWalls();
	}

	public function applyPreset( preset : Preset ) {
		untyped edges.length = 0;

		for ( wall in preset.walls ) {
			edges.push(
				new IntPair(
					IntPair.mapCell(wall.x1, wall.y1, size),
					IntPair.mapCell(wall.x2, wall.y2, size)
				)
			);
		}
		drawAll();

		Game.inst.hero.setCellPosition(preset.heroCoord.x, preset.heroCoord.y);
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
	private function drawBorderSquare( x : Int, y : Int, width : Int, height : Int ) {
		graphics.moveTo(x, y);
		graphics.lineTo(x + width, y);
		graphics.lineTo(x + width, y + height);
		graphics.lineTo(x, y + height);
		graphics.lineTo(x, y);
	}
}
