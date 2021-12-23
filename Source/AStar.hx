import haxe.ds.IntMap;
import haxe.CallStack;
import haxe.ds.GenericStack;
import tools.IntPair;
import js.lib.Set;

using tools.BinaryHeapPQ;

typedef Point = {
	public var x : Int;
	public var y : Int;
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

	public function new( x : Int, y : Int ) {
		this.x = x;
		this.y = y;
		this.g = 0;
		this.h = 0;
		this.f = 0;
		this.wallsDestroyed = 0;
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
	private var ignoredBrokenCells : Set<Cell>;

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
		this.ignoredBrokenCells = new Set();

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

	private function displayPath() {
		var resultPath : Array<Cell> = [end];
		var cell = end;

		if ( cell.parent == null ) return null;
		while( cell.parent != start ) {
			cell = cell.parent;
			resultPath.push(cell);
		}
		resultPath.push(start);

		trace(end.g, "=============================================");

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

	/**
		comparator for storing cell with lowest f higher
	**/
	private inline function cellComparator( cell1 : Cell, cell2 : Cell ) : Int return cell2.f - cell1.f;
	/** 
		should only be called once per AStar instance

		обходим по A*, ломая все стены подряд, добавляя 1 к стоимости перехода, 
		как только нашёлся выход, начинаем обходить граф сначала, 
		игнорируя по порядку ломание каждой из стены по пути к выходу,
		если есть путь оптимальнее, он найдётся и игнорируемая на этой итерации
		стена будет занесена в Set ignoredBrokenCell для того, чтобы игнорировать её
		дальше и до конца поиска.
	**/
	public function findPath() {
		// если true, то с конца в начало будет произведена проверка на все 
		// действующие в пути сломанные стены
		var brokenWallsArePurged = true;
		var ignoredBrokenCell : Cell = null;
		ignoredBrokenCells = new Set();

		// если true, то в этой итерации цикла будут собраны все стены в действующем пути до выхода 
		// и проверены на более оптимальный путь путём игнорирования при обходе со start
		var endWasReached = false; 

		// используется для проверки нахождения лучшего пути, если при повторном обходе была 
		// найдена в соседних ячейках adjCell ячейка из действующего самого оптимального пути 
		// со стоимостью ниже, чем в данной клетке, то данный обход дропается и игнорируемая 
		// стена не сохраняется, делается попытка проигнорировать следующую стену и обойти граф снова
		var currentBestPath : Set<Cell> = new Set();

		while( !(opened.isEmpty()) ) {

			var cell = null;

			cell = opened.deleteTop(cellComparator);
			closed.add(cell);
			// trace("moving to " + cell.x, cell.y);

			if ( cell == end ) {
				endWasReached = true;
				brokenWallsArePurged = false;
				if ( ignoredBrokenCell != null ) ignoredBrokenCells.add(ignoredBrokenCell);
				ignoredBrokenCell = null;
			}

			if ( !brokenWallsArePurged ) {
				brokenWallsArePurged = true;
				brokenWalls = [];
				var pathCell = end;
				currentBestPath = new Set();
				while( pathCell != null ) {
					currentBestPath.add(pathCell);
					if ( pathCell.parent != null && IntPair.wallExistsBetweenCells(
						{ x : pathCell.x, y : pathCell.y },
						{ x : pathCell.parent.x, y : pathCell.parent.y },
						edges,
						size) ) {
						brokenWalls.push(pathCell);
					}
					pathCell = pathCell.parent;
				}
			}

			if ( endWasReached
				&& brokenWalls.length == 0
			) {
				return displayPath();
			}

			if ( endWasReached && brokenWalls.length > 0 ) {
				var brokenWall = brokenWalls.pop();
				ignoredBrokenCell = brokenWall;
				// trace("popping " + brokenWall.x + " " + brokenWall.y + " wbp: " + brokenWall.wallbreakingParent.x + " " + brokenWall.wallbreakingParent.y);
				opened.data = [];
				opened.insert(cellComparator, start);

				endWasReached = false;
				continue;
			}

			if ( cell == null ) return null;

			var adjCells = getAdjacentCells(cell);

			for ( adjCell in adjCells ) {

				// прверка в повторном обходе на оптимальность пути по сравнению с действующим путём,;
				// если провалена - текущий обход дропается и начинается сначала, занеся в игнор 
				// переменную следующую стену
				if ( currentBestPath.has(adjCell) && cell.g > adjCell.g ) {
					ignoredBrokenCell = null;
					endWasReached = true;
					opened.data = [];
					opened.insert(cellComparator, start);

					continue;
				}
				// "cell.g <= adjCell.g - 10" - чтобы снова проходить тот же путь, но уже через сломанную стену
				if ( (!closed.has(adjCell) || cell.g <= adjCell.g - 10)
					&& ensureThereWillBeNoLoops(adjCell, cell) ) {

					if ( !IntPair.wallExistsBetweenCells(
						{ x : adjCell.x, y : adjCell.y },
						{ x : cell.x, y : cell.y },
						edges,
						size) ) {

						if ( opened.data.contains(adjCell) ) {
							if ( cell.g <= adjCell.g - 10 )
								updateCell(adjCell, cell);
						} else {
							updateCell(adjCell, cell);
							opened.insert(cellComparator, adjCell);
						}
					} else {
						if ( adjCell.g == 0 || adjCell.g > cell.g + 10 ) {
							// adjCell is located over the wall
							// we wont break walls after our energy runs out

							if ( cell.g < energy
								&& cell.wallsDestroyed < sledgehammerUses
								&&
								((ignoredBrokenCell == null
									|| (adjCell != ignoredBrokenCell
										&& cell != ignoredBrokenCell.wallbreakingParent))

									&& ((!ignoredBrokenCells.has(adjCell)
										|| (adjCell.wallbreakingParent != cell))
									)
								) ) {

									// we mark cells that are behind walls to crush them later if needed
									updateCell(adjCell, cell);
									adjCell.g += 1;
									adjCell.f += 1;
									opened.insert(cellComparator, adjCell);
									adjCell.wallsDestroyed++;
									adjCell.wallbreakingParent = cell;
							}
						}
					}
				}
			}
		}

		trace("leaving the loop");

		return displayPath();
	}
}
