import haxe.ds.IntMap;
import haxe.CallStack;
import haxe.ds.GenericStack;
import tools.IntPair;
import js.lib.Set;

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
	private var opened : Array<Cell>;
	/**set of cells that can no longer be entered**/
	private var closed : Set<Cell>;
	/** mark all cells that are cut off with walls from the one we are in **/
	private var behindWalls : Array<Cell>;
	private var cells : Array<Array<Cell>>;
	private var edges : Set<tools.IntPair>;
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

		opened = [];

		cells = [for ( y in 0...size ) [for ( x in 0...size ) new Cell(x, y)]];

		this.start = cells[start.y][start.x];
		this.end = cells[end.y][end.x];
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
	/** 
		клетки должны быть смежными
	**/
	public function wallExistsBetweenCells( cell1 : Cell, cell2 : Cell, ?edges : Set<IntPair> ) : Bool {
		edges = edges == null ? this.edges : edges;
		for ( edge in edges ) {
			var c1 = IntPair.unmapCell(edge.val1, size); // cell 1
			var c2 = IntPair.unmapCell(edge.val2, size); // cell 2
			if ( (c1.val1 == cell1.x && c1.val2 == cell1.y && c2.val1 == cell2.x && c2.val2 == cell2.y)
				|| (c2.val1 == cell1.x && c2.val2 == cell1.y && c1.val1 == cell2.x && c1.val2 == cell2.y)
			) return true;
		}
		return false;
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
			// trace(parent.x, parent.y);
			parent = parent.parent;
		}
		// trace("leaving");

		return true;
	}
	/**
		heapify opened array by f param from bottom to top for faster performance with opened.pop()
	**/
	private function heapify( array : Array<Cell>, size : Int, rootIndex : Int ) {
		var lowest = rootIndex;
		var leftChild = (rootIndex >> 1) - 1;
		var rightChild = (rootIndex >> 1) - 2;

		if ( leftChild > -1 && array[leftChild].f < array[lowest].f )
			lowest = leftChild;

		if ( rightChild > -1 && array[rightChild].f < array[lowest].f )
			lowest = rightChild;

		if ( lowest != rootIndex ) {
			var temp = array[rootIndex];
			array[rootIndex] = array[lowest];
			array[lowest] = temp;
			heapify(array, size, lowest);
		}
	}
	/** 
		should only be called once per AStar instance

		Моё решение: мы обходим граф лабиринта по A*, и во все клетки, находящиеся
		за стеной, пишем их потенциальное F, чтобы потом, когда закончатся клетки в opened, 
		мы начали ломать стены, образующие самые выгодные срезы, таким образом, чтобы их разница
		между f и potentialF была наивысшей, при этом перерасчитывая все клетки, даже те, что уже в closed,
		с тем условием, чтобы g стоимость была выше в соседней клетке

		моё решение не работает: количество сломанных стен 
	**/
	public function findPath() {
		indexAllMap();

		opened.push(start);
		// "behindWalls.length > 0" чтобы сломать стены, даже если персонаж замурован в 1 клетке
		while( opened.length > 0 || behindWalls.length > 0 ) {

			var cell = null;
			// heapify opened array
			{
				// var size = opened.length;
				// var start = 0;
				// while( start < size ) {
				// 	heapify(opened, size, start);
				// 	start++;
				// }

				for ( openedCell in opened ) {
					if ( cell == null ) {
						cell = openedCell;
						continue;
					}
					if ( cell.f > openedCell.f )
						cell = openedCell;
				}
			}

			// var cell = opened.pop();

			if ( cell == end ) {
				return displayPath();
			}

			opened.remove(cell);
			closed.add(cell);

			// если клетка null, то до выхода нельзя добраться, не сломав стену
			while( (cell == null || cell.g >= energy)
				&& behindWalls.length > 0
			) {

				var cellBehindWall = null;

				// возвращает самую выгодную ячейку, в которую можно перейти, сломав стену
				while(
					behindWalls.length > 0
					&& (
						cellBehindWall == null
						|| cellBehindWall.g > energy
					) ) {

						for ( wall in behindWalls.copy() ) {
							if ( wall.f < wall.potentialF && opened.length > 0 ) {
								behindWalls.remove(wall);
								continue;
							}
							if ( cellBehindWall == null ) {
								cellBehindWall = wall;
								continue;
							}
							if (
								wall.f - wall.potentialF > 0
								&& wall.potentialF < wall.f
								&& wall.f - wall.potentialF > cellBehindWall.f - cellBehindWall.potentialF
							)
								cellBehindWall = wall;
						}

						if ( cellBehindWall != null && !ensureThereWillBeNoLoops(cellBehindWall, cellBehindWall.wallbreakingParent) ) {
							behindWalls.remove(cellBehindWall);
							cellBehindWall = null;
						}

						if ( cellBehindWall != null && !behindWalls.remove(cellBehindWall) ) break;
				}

				if ( cellBehindWall != null ) {
					trace("breaking wall in cell " + cellBehindWall.x,
						cellBehindWall.y, "from " + cellBehindWall.wallbreakingParent.x,
						cellBehindWall.wallbreakingParent.y,
						"with differ: ", cellBehindWall.f - cellBehindWall.potentialF);

					opened.push(cell);
					cell = cellBehindWall;
					updateCell(cell, cell.wallbreakingParent);
					cell.wallsDestroyed++;

					break;
				}
			}

			if ( cell == end ) {
				return displayPath();
			}

			var adjCells = getAdjacentCells(cell);

			for ( adjCell in adjCells ) {

				// "cell.g < adjCell.g - 20" - чтобы снова проходить тот же путь, но уже через сломанную стену
				if ( (!closed.has(adjCell) || cell.g < adjCell.g - 20)
					&& ensureThereWillBeNoLoops(adjCell, cell) ) {

					if ( !wallExistsBetweenCells(adjCell, cell) ) {
						if ( opened.contains(adjCell) ) {
							// if ( adjCell.g > cell.g + 10 )
							updateCell(adjCell, cell);
						} else {
							// if ( cell.g < energy + 10 || behindWalls.length <= 1 )
							opened.push(adjCell);
							updateCell(adjCell, cell);
						}
					} else {
						// the adjCell is located over the wall
						// we wont break walls after our energy runs out

						if ( cell.g + 10 < energy && cell.wallsDestroyed < sledgehammerUses - 1 ) {
							// we mark cells that are behind walls to crush them later if needed
							var potentialF = Std.int(getHeuristic(adjCell)) + cell.g + 10;
							if ( adjCell.potentialF == 0 || adjCell.potentialF > potentialF ) {
								adjCell.potentialF = potentialF;
								adjCell.wallbreakingParent = cell;
								adjCell.wallsDestroyed = cell.wallsDestroyed;
								behindWalls.push(adjCell);
							}
						}
					}
				}
			}
		}

		return null;
	}

	function indexAllMap() {
		// opened.push(start);


	}
}
