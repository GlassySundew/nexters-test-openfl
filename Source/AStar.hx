import haxe.ds.GenericStack;
import tools.IntPair;
import js.lib.Set;

typedef Point = {
	public var x : Int;
	public var y : Int;
}

private class Cell {
	public var x : Int;
	public var y : Int;
	public var g : Int;
	public var h : Int;
	public var f : Int;
	public var potentialF : Int;
	public var parent : Cell;
	public var destroyedWalls : Int;
	public var wallbreakingParent : Cell;

	public function new( x : Int, y : Int ) {
		this.x = x;
		this.y = y;
		this.g = 0;
		this.h = 0;
		this.f = 0;
		this.potentialF = 0;
		this.destroyedWalls = 0;
	}

	// public function clone() : Cell {
	// 	var cell = new Cell(x, y);
	// 	cell.g = g;
	// 	cell.h = h;
	// 	cell.f = f;
	// 	cell.destroyedWalls = destroyedWalls;
	// 	return cell;
	// }
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
	private var doCompletePath : Bool;
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
		?behindWalls : Array<Cell>,
		?doCompletePath : Bool = true
	) {

		this.doCompletePath = doCompletePath;
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
	private function wallExistsBetweenCells( cell1 : Cell, cell2 : Cell, ?edges : Set<IntPair> ) : Bool {
		edges = edges == null ? this.edges : edges;
		for ( edge in edges ) {
			var c1 = unmapCell(edge.val1); // cell 1
			var c2 = unmapCell(edge.val2); // cell 2
			if ( (c1.x == cell1.x && c1.y == cell1.y && c2.x == cell2.x && c2.y == cell2.y)
				|| (c2.x == cell1.x && c2.y == cell1.y && c1.x == cell2.x && c1.y == cell2.y)
			) return true;
		}
		return false;
	}
	/**
		* Unmaps a value back to cell co-ordinates, 
			@return serial x and y of tile in array 
	 */
	private inline function unmapCell( c : Int ) : Point {
		return { x : c % size, y : Math.floor(c / size) };
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
		adjCell.destroyedWalls = cell.destroyedWalls;
	}
	/** 
		if false, will not use abilities to surpass walls and 
		will find path that will be marked as impossible to travel 
	**/
	private inline function isAnyAbilityLeft() : Bool {
		return teleportUses > 0 || sledgehammerUses > 0 || energy > 0;
	}

	private function displayPath() {
		var resultPath : Array<Cell> = [end];
		var cell = end;

		@:privateAccess
		for ( i in behindWalls ) {
			Game.inst.heroPath.graphics.beginFill(0x2626b7, 0.3);
			Game.inst.heroPath.graphics.drawRect(i.x * Game.inst.maze.cellSize + 5, i.y * Game.inst.maze.cellSize + 5, 10, 10);
		}

		while( cell.parent != start ) {
			cell = cell.parent;
			resultPath.push(cell);
			trace("displayign ", cell.x, cell.y);
		}
		resultPath.push(start);
		return resultPath;
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
	/** should only be called once per AStar instance **/
	public function findPath() {
		trace("zhopa");

		opened.push(start);
		while( opened.length > 0 ) {

			// heapify opened array
			{
				var size = opened.length;
				var start = 0;
				while( start < size ) {
					heapify(opened, size, start);
					start++;
				}
			}

			var cell = opened.pop();
			closed.add(cell);

			if ( cell == end ) {
				return displayPath();
			}

			while( cell.g >= energy && behindWalls.length > 0 ) {
				var cellBehindWall = null;

				while( // sledgehammerUses > 0
					// &&
					behindWalls.length > 0
					&& (
						cellBehindWall == null
						|| cellBehindWall.g >= energy
						|| cellBehindWall.destroyedWalls >= sledgehammerUses
					) ) {

						// // heapify behindwalls array
						// var size = behindWalls.length;
						// var start = 0;
						// while( start < size ) {
						// 	heapify(behindWalls, size, start);
						// 	start++;
						// }

						if (
							cellBehindWall != null
							&& cellBehindWall.wallbreakingParent.parent == cellBehindWall

						)
							cellBehindWall = null;

						// получаем стену, которую будет выгоднее всего будет сломать
						for ( wall in behindWalls ) {
							if ( cellBehindWall == null ) {
								cellBehindWall = wall;
								continue;
							}
							trace(cellBehindWall.g - cellBehindWall.wallbreakingParent.g, wall.g - wall.wallbreakingParent.g);

							if ( cellBehindWall.g - cellBehindWall.wallbreakingParent.g < wall.g - wall.wallbreakingParent.g )
								cellBehindWall = wall;
						}
						// trace("anuss", behindWalls.length, behindWalls.remove(cellBehindWall), bak == cellBehindWall, cellBehindWall.g >= energy);
						if ( !behindWalls.remove(cellBehindWall) ) break;
				}

				// if ( cellBehindWall.wallbreakingParent.parent != null && cellBehindWall.wallbreakingParent.parent == cellBehindWall ) {
				// 	trace(cell.x, cell.y, cell.parent == cell, "amogus");
				// }

				if ( cellBehindWall != null ) {
					opened.push(cell);
					closed.delete(cell);

					cell = cellBehindWall;

					updateCell(cell, cell.wallbreakingParent);

					if ( cell.parent != null && cell.parent.parent != null && cell.parent.parent.parent == cell ) {
						trace(cell.x, cell.y, cell.parent == cell, "amogus");
					}

					@:privateAccess {
						Game.inst.heroPath.graphics.beginFill(0x373737, 0.8);
						Game.inst.heroPath.graphics.drawRect(cell.x * Game.inst.maze.cellSize + 10,
							cell.y * Game.inst.maze.cellSize + 10, 5, 5);
					}
					sledgehammerUses--;
				}
			}

			if ( cell == end ) {
				return displayPath();
			}

			var adjCells = getAdjacentCells(cell);

			for ( adjCell in adjCells ) {

				if ( (!closed.has(adjCell) || (cell.g < adjCell.g - 20)) ) {
					if ( !wallExistsBetweenCells(adjCell, cell) ) {
						if ( opened.contains(adjCell) ) {
							// if adj cell is in open list, check if current path is
							// better than the one previously found for this adj
							updateCell(adjCell, cell);
						} else {
							updateCell(adjCell, cell);
							opened.push(adjCell);
						}
						if ( adjCell.parent != null && adjCell.parent.parent != null && adjCell.parent.parent.parent == adjCell ) {
							trace(adjCell.x, adjCell.y, cell.parent == cell);
						}
					} else {
						// we wont break walls after our energy runs out
						if ( cell.g + 10 < energy ) {
							// we mark cells that are behind walls to crush them later if needed

							var potentialF = Std.int(getHeuristic(adjCell)) + cell.g + 10;
							if ( adjCell.potentialF == 0 || adjCell.potentialF > potentialF ) {
								adjCell.destroyedWalls = cell.destroyedWalls;
								adjCell.wallbreakingParent = cell;
								behindWalls.push(adjCell);
							}
						}
					}
				}
			}
		}

		trace("No path was found");
		return null;
	}
}
