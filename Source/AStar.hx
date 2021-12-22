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
	public var potentialF : Int;
	public var parent : Cell;
	public var wallsDestroyed : Int;
	public var wallbreakingParent : Cell;

	public function new( x : Int, y : Int ) {
		this.x = x;
		this.y = y;
		this.g = 0;
		this.h = 0;
		this.f = 0;
		this.potentialF = 0;
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
	private var behindWalls : Array<Cell>;
	private var cells : Array<Array<Cell>>;
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
		?behindWalls : Array<Cell>
	) {

		this.energy = energy * 10;
		this.sledgehammerUses = sledgehammerUses;
		this.teleportCost = teleportCost;
		this.teleportRadius = teleportRadius;
		this.size = size;
		this.edges = new Set(edges);
		this.behindWalls = behindWalls == null ? [] : behindWalls;
		this.closed = new Set(closed);

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
		линкует adjCell на cell 
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
		trace(end.wallsDestroyed, behindWalls.length);

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

	private inline function endWasReached() return end.parent != null;
	/**
		comparator for storing cell with lowest f higher
	**/
	private inline function cellComparator( cell1 : Cell, cell2 : Cell ) : Int return cell2.f - cell1.f;
	/** 
		should only be called once per AStar instance

		Моё решение: мы обходим граф лабиринта по A*, и во все клетки, находящиеся
		за стеной, пишем их потенциальное F, чтобы потом, когда закончатся клетки в opened, 
		мы начали ломать стены с наименьшим potentialF, 
		при этом перерасчитывая все клетки, даже те, что уже в closed,
		с тем условием, если g стоимость выше в соседней клетке

		путь иногда находится криво и может не считать стены
	**/
	public function findPath() {

		// "behindWalls.length > 0" чтобы сломать стены, даже если персонаж замурован в 1 клетке
		while( !(opened.isEmpty() && behindWalls.length == 0) ) {

			var cell = opened.deleteTop(cellComparator);

			closed.add(cell);

			var cellBehindWall = null;

			if ( endWasReached() ) {
				while( cellBehindWall == null && behindWalls.length > 0 ) {
					for ( wall in behindWalls.copy() ) {
						// ждём пока opened не обработает эту клетку, либо ломаем, потому что opened закончился
						// if ( wall.f == 0
						// 	&& (opened.size() > 0 || (wall.wallbreakingParent == start))
						// 	&& !endWasReached() )
						// 	continue;

						if ( (
							wall.f != 0
							&& (wall.f - wall.potentialF < 10 || wall.g < wall.wallbreakingParent.g - 10)
							&& opened.size() > 0
						)
							|| wall.wallbreakingParent.wallsDestroyed > sledgehammerUses - 1
						) {
							behindWalls.remove(wall);
							continue;
						}
						if ( cellBehindWall == null ) {
							cellBehindWall = wall;
							continue;
						}
						// if ( cellBehindWall.f - cellBehindWall.potentialF < wall.f - wall.potentialF ) {
						if ( cellBehindWall.potentialF > wall.potentialF ) {
							cellBehindWall = wall;
						}
					}

					if ( cellBehindWall != null && !ensureThereWillBeNoLoops(cellBehindWall, cellBehindWall.wallbreakingParent) ) {
						behindWalls.remove(cellBehindWall);
						cellBehindWall = null;
					}

					if ( cellBehindWall != null && !behindWalls.remove(cellBehindWall) ) break;
				}

				if ( cellBehindWall != null ) {
					trace("breaking wall " + cellBehindWall.x, cellBehindWall.y, "from ", cellBehindWall.wallbreakingParent.x, cellBehindWall.wallbreakingParent.y);

					if ( cell != null ) {
						opened.insert(cellComparator, cell);
						closed.delete(cell);
					}

					cell = cellBehindWall;
					opened.insert(cellComparator, cell);

					updateCell(cell, cell.wallbreakingParent);
					cell.g += 1;
					cell.f += 1;
					cell.wallsDestroyed++;
					// cell.potentialF = 0;
					// cell.wallbreakingParent = null;

					var parent = cell.parent;
					while( parent != null ) {
						parent.wallsDestroyed = cell.wallsDestroyed;
						parent = parent.parent;
					}
				}
			}

			if ( behindWalls.length == 0 && endWasReached() ) {
				return displayPath();
			}

			if ( cell == null ) return null;

			var adjCells = getAdjacentCells(cell);

			for ( adjCell in adjCells ) {

				// "cell.g < adjCell.g - 10" - чтобы снова проходить тот же путь, но уже через сломанную стену
				if ( (!closed.has(adjCell) || cell.g < adjCell.g - 10)
					&& ensureThereWillBeNoLoops(adjCell, cell) ) {

					if ( !IntPair.wallExistsBetweenCells(
						{ x : adjCell.x, y : adjCell.y },
						{ x : cell.x, y : cell.y },
						edges,
						size) ) {

						if ( opened.data.contains(adjCell) ) {
							if ( cell.g < adjCell.g - 10 )
								updateCell(adjCell, cell);
						} else {
							updateCell(adjCell, cell);
							opened.insert(cellComparator, adjCell);
						}
					} else {
						// the adjCell is located over the wall
						// we wont break walls after our energy runs out

						if ( cell.g < energy && cell.wallsDestroyed < sledgehammerUses ) {
							// we mark cells that are behind walls to crush them later if needed
							var potentialF = Std.int(getHeuristic(adjCell)) + cell.g + 10;
							if ( adjCell.potentialF == 0 || adjCell.potentialF > potentialF ) {
								adjCell.potentialF = potentialF;
								adjCell.wallbreakingParent = cell;
								behindWalls.push(adjCell);
							}
						}

						// if ( cell.g < energy && cell.wallsDestroyed < sledgehammerUses ) {
						// 	updateCell(adjCell, cell);
						// 	adjCell.g += 20;
						// 	adjCell.f += 20;

						// 	adjCell.wallsDestroyed++;
						// 	opened.insert(cellComparator, adjCell);
						// }
					}
				}
			}
		}
		trace("leaving loop");
		return displayPath();
	}
}
