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
	public var potentialG : Int;
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
		this.potentialG = 0;
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
		за стеной, пишем их потенциальное G, чтобы потом, когда закончатся клетки в opened, 
		мы начали ломать стены, образующие самые выгодные срезы, таким образом, чтобы из разница
		между f и potentialF была наивысшей, при этом перерасчитывая все клетки, даже те, что уже в closed,
		с тем условием, чтобы g стоимость была выше в соседней клетке

		p.s. совсем недавно понял, что надо приступать к ломанию стен только тогда, когда в opened уже не 
		осталось клеток 
	**/
	public function findPath() {
		opened.push(start);
		while( opened.length > 0 ) {

			var cell = null;
			// heapify opened array
			{
				// var size = opened.length;
				// var start = 0;
				// while( start < size ) {
				// 	heapify(opened, size, start);
				// 	start++;
				// }

				for ( i in opened ) {
					if ( cell == null ) {
						cell = i;
						continue;
					}
					if ( cell.f > i.f )
						cell = i;
				}
				opened.remove(cell);
			}

			// var cell = opened.pop();
			closed.add(cell);

			if ( cell == end ) {
				return displayPath();
			}

			while( (cell.g >= energy + 10 || opened.length == 0) && behindWalls.length > 0 && cell.wallsDestroyed < sledgehammerUses ) {
				var cellBehindWall = null;

				// возвращает самую выгодную ячейку, в которую можно перейти, сломав стену
				while(
					behindWalls.length > 0
					&& (
						cellBehindWall == null
						|| cellBehindWall.g >= energy
					) ) {

						// получаем стену, которую будет выгоднее всего будет сломать
						for ( wall in behindWalls ) {
							if ( cellBehindWall == null ) {
								cellBehindWall = wall;
								continue;
							}
							if (
								wall.potentialF < wall.f
								&& wall.wallsDestroyed < sledgehammerUses
								&& wall.wallbreakingParent.wallsDestroyed < sledgehammerUses
								&& wall.f - wall.potentialF > cellBehindWall.f - cellBehindWall.potentialF )

								cellBehindWall = wall;
						}

						if ( (cellBehindWall.wallbreakingParent.parent != null
							&& !ensureThereWillBeNoLoops(cellBehindWall, cellBehindWall.wallbreakingParent))
							|| (cellBehindWall.wallbreakingParent.wallsDestroyed >= sledgehammerUses
								|| cellBehindWall.wallsDestroyed >= sledgehammerUses) ) {

							behindWalls.remove(cellBehindWall);
							cellBehindWall = null;
						}

						if ( cellBehindWall != null && !behindWalls.remove(cellBehindWall) ) break;
				}

				if ( cellBehindWall != null
					&& cellBehindWall.wallbreakingParent.wallsDestroyed < sledgehammerUses
					&& cellBehindWall.wallsDestroyed < sledgehammerUses ) {

					opened.push(cell);
					closed.delete(cell);

					cell = cellBehindWall;

					updateCell(cell, cell.wallbreakingParent);
					cell.wallsDestroyed++;

					var parent = cell.parent;
					while( parent != null ) {
						parent.wallsDestroyed = cell.wallsDestroyed;
						parent = parent.parent;
					}
				}
			}

			if ( cell == end ) {
				return displayPath();
			}

			var adjCells = getAdjacentCells(cell);

			for ( adjCell in adjCells ) {
				if ( (!closed.has(adjCell)
					|| cell.g < adjCell.g - 30)
					&& ensureThereWillBeNoLoops(adjCell, cell) ) {

					if ( !wallExistsBetweenCells(adjCell, cell) ) {
						if ( !opened.contains(adjCell) ) {
							opened.push(adjCell);
							updateCell(adjCell, cell);
						}
						else {
							if ( adjCell.g > cell.g + 10 )
								updateCell(adjCell, cell);
						}
					} else {
						// the adjCell is located over the wall
						// we wont break walls after our energy runs out

						if ( cell.g + 10 < energy ) {
							// we mark cells that are behind walls to crush them later if needed
							var potentialF = Std.int(getHeuristic(adjCell)) + cell.g + 10;
							if ( adjCell.potentialF == 0 ) {
								adjCell.potentialG = cell.g + 10;
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
}
