package tools;

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
}
