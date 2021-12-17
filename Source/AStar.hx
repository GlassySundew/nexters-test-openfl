import haxe.CallStack;
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
		adjCell.wallsDestroyed = cell.wallsDestroyed;
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
	/** should only be called once per AStar instance **/
	public function findPath() {
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
				trace(end.wallsDestroyed);

				return displayPath();
			}

			while( cell.g >= energy && behindWalls.length > 0 && cell.wallsDestroyed < sledgehammerUses ) {
				var cellBehindWall = null;

				// возвращает самую выгодную ячейку, в которую можно перейти, сломав стену
				while( // sledgehammerUses > 0
					// &&
					behindWalls.length > 0
					&& (
						cellBehindWall == null
						|| cellBehindWall.g >= energy
					) ) {

						// // heapify behindwalls array
						// var size = behindWalls.length;
						// var start = 0;
						// while( start < size ) {
						// 	heapify(behindWalls, size, start);
						// 	start++;
						// }

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
						// trace(ensureThereWillBeNoLoops(cellBehindWall, cellBehindWall.wallbreakingParent),
						// 	cellBehindWall.wallbreakingParent.parent != null && cellBehindWall.wallbreakingParent.parent == cellBehindWall
						// );
						// if ( cellBehindWall.wallbreakingParent.parent != null
						// 	&& !ensureThereWillBeNoLoops(cellBehindWall, cellBehindWall.wallbreakingParent) )
						// 	cellBehindWall = null;

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

					trace("breaking wall in ", cellBehindWall.x, cellBehindWall.y, cellBehindWall.wallsDestroyed, cellBehindWall.wallbreakingParent.wallsDestroyed);

					opened.push(cell);
					closed.delete(cell);

					cell = cellBehindWall;

					// cell.wallbreakingParent.wallsDestroyed = cell.wallsDestroyed;
					// var bakWallsBroken = cell.wallsDestroyed;
					updateCell(cell, cell.wallbreakingParent);
					cell.wallsDestroyed++;

					// for ( i in behindWalls )
					// 	if ( i.wallbreakingParent == cell || i.parent == cell)
					// 		i.wallsDestroyed = cell.wallsDestroyed;

					if ( cell.parent != null && cell.parent.parent != null && cell.parent.parent.parent == cell ) {
						trace(cell.x, cell.y, cell.parent == cell, "amogus");
					}

					@:privateAccess {
						Game.inst.heroPath.graphics.beginFill(0x373737, 0.8);
						Game.inst.heroPath.graphics.drawRect(cell.x * Game.inst.maze.cellSize + 10,
							cell.y * Game.inst.maze.cellSize + 10, 5, 5);
					}

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
				if ( (!closed.has(adjCell) || cell.f < adjCell.f - 20) && ensureThereWillBeNoLoops(adjCell, cell) ) {
					if ( !wallExistsBetweenCells(adjCell, cell) ) {
						if ( opened.contains(adjCell) ) {
							// if adj cell is in open list, check if current path is
							// better than the one previously found for this adj
							// if ( adjCell.g > cell.g + 10 )
							updateCell(adjCell, cell);
						} else {
							updateCell(adjCell, cell);
							opened.push(adjCell);
						}
						if ( adjCell.parent != null && adjCell.parent.parent == adjCell ) {
							trace(adjCell.x, adjCell.y, cell.parent == cell);
						}

						if ( adjCell.parent != null && adjCell.parent.parent != null && adjCell.parent.parent.parent == adjCell ) {
							trace(adjCell.x, adjCell.y, cell.parent == cell);
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

								// var textField = new openfl.text.TextField();
								// // all your stuff on the textField
								// textField.text = "ZHOPA";

								// var textFieldBitmapData = new openfl.display.BitmapData(Std.int(textField.width), Std.int(textField.height), true, 0x000000);
								// textFieldBitmapData.draw(textField);

								// var textFieldBitmap = new openfl.display.Bitmap(textFieldBitmapData);
								// textFieldBitmap.smoothing = true;
								// textFieldBitmap.x = adjCell.x * Game.inst.maze.cellSize;
								// textFieldBitmap.y = adjCell.y * Game.inst.maze.cellSize;

								// @:privateAccess {
								// 	Game.inst.heroPath.addChild(textFieldBitmap);
								// }
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
