import haxe.ui.behaviours.Behaviour;
import haxe.ds.IntMap;
import haxe.CallStack;
import haxe.ds.GenericStack;
import tools.IntPair;
import js.lib.Set;

using tools.BinaryHeapPQ;
using tools.ReverseArrayKeyValueIterator;

typedef Point = {
	public var x : Int;
	public var y : Int;
}

enum RunMode {
	FirstRun;
	WallsMinimize;
	CostOptimize;
}

class Cell {
	public var x : Int;
	public var y : Int;
	public var g : Int;
	public var h : Int;
	public var f : Int;
	public var parent : Cell;
	public var wallsDestroyed : Int;
	public var wallbreakingParent : Cell;
	public var lastPathParent : Cell;

	public function new( x : Int, y : Int ) {
		this.x = x;
		this.y = y;
		this.g = 0;
		this.h = 0;
		this.f = 0;
		this.wallsDestroyed = 0;
	}
}

/**
	ключ - клетка, всегда ближайшая к выходу, занчение(сэт) это все клетки между которыми и у 
	клетки - ключа есть игнорируемая стена
**/
abstract IgnoredWallsMap( Map<Cell, Set<Cell>> ) {

	public function new( s ) this = s;

	@:arrayAccess
	function get( cell : Cell ) {
		if ( this.get(cell) == null )
			this[cell] = new Set();

		return this[cell];
	}
}

class AStar {

	/**list of available cells to enter**/
	public var edges : Set<tools.IntPair>;

	private var opened : tools.BinaryHeapPQ.ArrayPQ<Cell>;

	/**set of cells that can no longer be entered**/
	private var closed : Set<Cell>;

	/** mark all cells that are cut off with walls from the one we are in **/
	private var brokenWalls : Array<Cell>;
	private var cells : Array<Array<Cell>>;

	// private var ignoredBrokenCells : Set<Cell>;
	private var ignoredBrokenCells : IgnoredWallsMap;
	private var ignoredBrokenCell(default, set) : { cell : Cell, parent : Cell };

	function set_ignoredBrokenCell( brokenCell : { cell : Cell, parent : Cell } ) {

		if ( brokenCell == null ) {
			if ( ignoredBrokenCell != null )
				ignoredBrokenCells[ignoredBrokenCell.cell].delete(ignoredBrokenCell.parent);
		} else
			ignoredBrokenCells[brokenCell.cell].add(brokenCell.parent);

		return ignoredBrokenCell = brokenCell;
	}

	private var start : Cell;
	private var end : Cell;
	private var size : Int;

	private var energy : Int;
	private var sledgehammerUses : Int;
	private var teleportCost : Int;
	private var teleportRadius : Int;
	private var teleportUses : Int;

	/**
		@param edges must be either a set or an array of tools.IntPair
		@param doCompletePath will find the path to the exit even though the energy is out
	**/
	public function new(
		start : Point,
		end : Point,
		size : Int,
		energy : Int,
		sledgehammerUses : Int,
		teleportCost : Int,
		teleportRadius : Int,
		edges : Any,
		?closed : Set<Cell>,
		?brokenWalls : Array<Cell>
	) {

		this.energy = energy * 10;
		this.sledgehammerUses = sledgehammerUses;
		this.teleportCost = teleportCost;
		this.teleportRadius = teleportRadius;
		this.size = size;
		this.edges = new Set(edges);
		this.brokenWalls = brokenWalls == null ? [] : brokenWalls;
		this.closed = new Set(closed);

		// this.ignoredBrokenCells = new Set();

		cells = [for ( y in 0...size ) [for ( x in 0...size ) new Cell(x, y)]];

		this.start = cells[start.y][start.x];
		this.end = cells[end.y][end.x];

		this.start.h = Std.int(getHeuristic(this.start));

		opened = { data : [this.start] };
	}

	private function getAdjacentCells( cell : Cell ) {
		var result = [];
		if ( cell.y > 0 )
			result.push(cells[cell.y - 1][cell.x]);
		if ( cell.x < cells[0].length - 1 )
			result.push(cells[cell.y][cell.x + 1]);
		if ( cell.y < cells.length - 1 )
			result.push(cells[cell.y + 1][cell.x]);
		if ( cell.x > 0 )
			result.push(cells[cell.y][cell.x - 1]);
		return result;
	}

	private inline function getHeuristic( cell : Point )
		return 10 * (Math.abs(cell.x - end.x) + Math.abs(cell.y - end.y));

	/** 
		линкует cell на adjCell, стандартная стоимость перехода - 10
	**/
	private function updateCell( adjCell : Cell, cell : Cell ) {
		adjCell.g = cell.g + 10;
		adjCell.h = Std.int(getHeuristic(adjCell));
		adjCell.parent = cell;
		adjCell.f = adjCell.h + adjCell.g;
		adjCell.wallsDestroyed = cell.wallsDestroyed;
	}

	private function updateWall( adjCell : Cell, cell : Cell ) {
		updateCell(adjCell, cell);
		adjCell.f += 1;
		adjCell.g += 1;
		adjCell.wallsDestroyed++;
		adjCell.wallbreakingParent = cell;
	}

	private function displayPath() {
		var resultPath : Array<Cell> = [end];
		var cell = end;

		if ( cell.parent == null ) return null;
		while( cell.parent != start ) {
			cell = cell.parent;
			resultPath.push(cell);
		}
		resultPath.push(start);

		trace("=============================================");

		return resultPath;
	}

	/**
		@return true, if it is safe and will be no loops added
	**/
	private function ensureThereWillBeNoLoops( adjCell : Cell, cell : Cell ) : Bool {
		var parent = cell.parent;
		while( parent != null ) {
			if ( parent == adjCell ) {
				return false;
			}
			parent = parent.parent;
		}

		return true;
	}

	private function endWasEverReached() : Bool
		return end.parent != null;

	/**
		comparator for storing cell with lowest f higher
	**/
	private inline function cellComparator( cell1 : Cell, cell2 : Cell ) : Int return cell2.f - cell1.f;

	/** 
		should only be called once per AStar instance

		простой A* но с возможностью входить в ячейки снова для оптимизации стоимости
	**/
	public function findPath() {

		// если true, то в этой итерации цикла будут собраны все стены в действующем пути до выхода
		// и проверены на более оптимальный путь путём игнорирования при обходе со start
		var startIgnoringWallsFlag = false;
		// если true, то с конца в начало будет произведена проверка на все
		// действующие в пути сломанные стены
		var refreshBrokenWallsFlag = false;

		// используется для проверки нахождения лучшего пути, если при повторном обходе была
		// найдена в соседних ячейках adjCell ячейка из действующего самого оптимального пути
		// со стоимостью ниже, чем в данной клетке, то данный обход дропается и игнорируемая
		// стена не сохраняется, делается попытка проигнорировать следующую стену и обойти граф снова
		var currentBestPath : Map<Cell, { oldG : Int, oldWallsBroken : Int }> = new Map();

		ignoredBrokenCells = new IgnoredWallsMap(new Map());

		while( !opened.isEmpty() ) {
			var cell = null;

			cell = opened.deleteTop(cellComparator);
			closed.add(cell);

			#if debug
			trace("moving to " + cell.x, cell.y, "wb: " + cell.wallsDestroyed,
				cell.parent != null ? "p " + cell.parent.x + " " + cell.parent.y : "",
				"walls destroyed in the last path: " + end.wallsDestroyed);
			#end

			if ( cell == end )
				break;

			if ( cell == null ) return null;

			var adjCells = getAdjacentCells(cell);

			for ( adjCell in adjCells ) {
				var isWallPresent = IntPair.wallExistsBetweenCells(
					{ x : adjCell.x, y : adjCell.y },
					{ x : cell.x, y : cell.y },
					edges,
					size);

				if ( (
					!closed.has(adjCell)
					|| (cell.wallsDestroyed < adjCell.wallsDestroyed))
					&& ensureThereWillBeNoLoops(adjCell, cell)
				) {

					if ( !isWallPresent ) {

						if ( opened.data.contains(adjCell) ) {
							if ( adjCell.g > cell.g + 10 )
								updateCell(adjCell, cell);
						} else {
							updateCell(adjCell, cell);
							opened.insert(cellComparator, adjCell);
						}
					} else {
						// adjCell is located over the wall
						if ( adjCell.g == 0 || adjCell.g >= cell.g + 11 ) {
							if ( cell.wallsDestroyed < sledgehammerUses ) {
								if ( opened.data.contains(adjCell) ) {
									if ( adjCell.g >= cell.g + 10 ) {
										updateWall(adjCell, cell);
									}
								} else {
									updateWall(adjCell, cell);
									opened.insert(cellComparator, adjCell);
								}
							}
						}
					}
				}
			}
		}

		return displayPath();
	}
}
