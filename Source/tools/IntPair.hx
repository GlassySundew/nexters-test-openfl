package tools;

import AStar.Point;
import tools.KruskalMazeGen;
/**
 * Stores a pair of integers, where each one is a mapped coorinate of a cell in 2d array of cells
 */
class IntPair {
	public final val1 : Int;
	public final val2 : Int;

	public function new( val1 : Int, val2 : Int ) {
		this.val1 = val1;
		this.val2 = val2;
	}
	/**
	 * Maps a cell co-ordinate to a single value
	 */
	public static inline function mapCell( cx : Int, cy : Int, size : Int ) {
		return cx + (cy * size);
	}
	/**
	 * Unmaps a value back to cell co-ordinates
	 */
	public static inline function unmapCell( c : Int, size : Int ) {
		return new IntPair(c % size, Math.floor(c / size));
	}

	public static function findWallBetweenTwoCells( cell1 : Point, cell2 : Point, edges : js.lib.Set<IntPair>, size : Int ) : IntPair {
		for ( edge in edges ) {
			var c1 = IntPair.unmapCell(edge.val1, size); // cell 1
			var c2 = IntPair.unmapCell(edge.val2, size); // cell 2
			if ( (c1.val1 == cell1.x && c1.val2 == cell1.y && c2.val1 == cell2.x && c2.val2 == cell2.y)
				|| (c2.val1 == cell1.x && c2.val2 == cell1.y && c1.val1 == cell2.x && c1.val2 == cell2.y)
			) return edge;
		}
		return null;
	}
	/** 
		клетки должны быть смежными
	**/
	public static inline function wallExistsBetweenCells( cell1 : Point, cell2 : Point, edges : js.lib.Set<IntPair>, size : Int ) : Bool {
		return findWallBetweenTwoCells(cell1, cell2, edges, size) != null;
	}
}
