package tools;

import openfl.display.Sprite;

class KruskalMazeGen extends Sprite {
	@:allow(Maze)
	private var edges : Array<IntPair>;
	private var cells : DisjointSets;

	private var mazeSize : Int;
	private var cellSize : Int;

	public function new( mazeSize : Int, cellSize : Int ) {
		super();
		this.mazeSize = mazeSize;
		this.cellSize = cellSize;
	}

	public function generate() : Array<IntPair> {
		edges = new Array<IntPair>();
		cells = new DisjointSets(mazeSize * mazeSize);

		var currentCell : Int;
		for ( i in 0...mazeSize ) {
			for ( j in 0...mazeSize ) {
				currentCell = IntPair.mapCell(i, j, mazeSize);
				// Add an edge between every cell adjacent cell pair
				if ( i > 0 ) edges.push(new IntPair(currentCell, IntPair.mapCell(i - 1, j, mazeSize)));
				if ( j > 0 ) edges.push(new IntPair(currentCell, IntPair.mapCell(i, j - 1, mazeSize)));
			}
		}

		var e : IntPair;
		var findA : Int, findB : Int;

		// Iterate until only one set
		while( cells.numberOfSets() > 1 ) {
			// Choose a random edge
			e = edges[Std.random(edges.length)];

			findA = cells.find(e.val1);
			findB = cells.find(e.val2);
			if ( findA != findB ) {
				// Cells between chosen edge belong to different sets, so remove edge and union sets
				edges.remove(e);
				cells.union(findA, findB);
			}
		}

		return edges;
	}
	/**
	 * Rotates a point (cx, cy) 90 degrees about a point (px, py)
	 */
	private inline function rotate( cx : Int, cy : Int, px : Int, py : Int ) : IntPair {
		return new IntPair(cy - py + px, -cx + px + py);
	}

	public function drawWalls( color : Int ) {
		graphics.clear();
		graphics.lineStyle(4, color);

		var c1 : IntPair, c2 : IntPair;
		var px : Int, py : Int;
		for ( e in edges ) {
			// Get the two cells separated by an edge
			c1 = IntPair.unmapCell(e.val1, mazeSize);
			c2 = IntPair.unmapCell(e.val2, mazeSize);

			// Midpoint of two cells
			px = Std.int((c1.val1 * cellSize) + ((c2.val1 - c1.val1) * cellSize * 0.5));
			py = Std.int((c1.val2 * cellSize) + ((c2.val2 - c1.val2) * cellSize * 0.5));

			// Rotate a line between two cells by 90 degrees about the midpoint
			c1 = rotate(c1.val1 * cellSize, c1.val2 * cellSize, px, py);
			c2 = rotate(c2.val1 * cellSize, c2.val2 * cellSize, px, py);

			// Draw new line
			graphics.moveTo(c1.val1 + cellSize / 2, c1.val2 + cellSize / 2);
			graphics.lineTo(c2.val1 + cellSize / 2, c2.val2 + cellSize / 2);
		}
	}
}
