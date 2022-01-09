package mazePreset;

typedef UnmappedWall = {
	var x1 : Int;
	var y1 : Int;
	var x2 : Int;
	var y2 : Int;
}

typedef Preset = {
	var walls : Array<UnmappedWall>;
	var heroCoord : { x : Int, y : Int };
}

class Presets {
	public static var isolationPreset : Preset = {
		walls : [
         // @formatter:off
         // top box
			{ x1 : 2, y1 : 1, x2 : 2, y2 : 0 },
			{ x1 : 3, y1 : 1, x2 : 3, y2 : 0 },
			{ x1 : 4, y1 : 1, x2 : 4, y2 : 0 },
			{ x1 : 2, y1 : 1, x2 : 1, y2 : 1 },
			{ x1 : 2, y1 : 2, x2 : 1, y2 : 2 },
			{ x1 : 2, y1 : 3, x2 : 1, y2 : 3 },
			{ x1 : 2, y1 : 4, x2 : 2, y2 : 3 },
			{ x1 : 3, y1 : 4, x2 : 3, y2 : 3 },
			{ x1 : 4, y1 : 4, x2 : 4, y2 : 3 },
			{ x1 : 4, y1 : 4, x2 : 4, y2 : 3 },
			{ x1 : 5, y1 : 1, x2 : 4, y2 : 1 },
			{ x1 : 5, y1 : 2, x2 : 4, y2 : 2 },
			{ x1 : 5, y1 : 3, x2 : 4, y2 : 3 },

         // walls 
			{ x1 : 1, y1 : 5, x2 : 1, y2 : 4 },
			{ x1 : 2, y1 : 5, x2 : 2, y2 : 4 },
			{ x1 : 3, y1 : 5, x2 : 3, y2 : 4 },
			{ x1 : 4, y1 : 5, x2 : 4, y2 : 4 },
			{ x1 : 5, y1 : 5, x2 : 5, y2 : 4 },

			{ x1 : 1, y1 : 5, x2 : 1, y2 : 6 },
			{ x1 : 2, y1 : 5, x2 : 2, y2 : 6 },
			{ x1 : 3, y1 : 5, x2 : 3, y2 : 6 },
			{ x1 : 4, y1 : 5, x2 : 4, y2 : 6 },
			{ x1 : 5, y1 : 5, x2 : 5, y2 : 6 },

         { x1 : 1, y1 : 7, x2 : 1, y2 : 6 },
			{ x1 : 2, y1 : 7, x2 : 2, y2 : 6 },
			{ x1 : 3, y1 : 7, x2 : 3, y2 : 6 },
			{ x1 : 4, y1 : 7, x2 : 4, y2 : 6 },
			{ x1 : 5, y1 : 7, x2 : 5, y2 : 6 },
         
         { x1 : 1, y1 : 7, x2 : 1, y2 : 8 },
			{ x1 : 2, y1 : 7, x2 : 2, y2 : 8 },
			{ x1 : 3, y1 : 7, x2 : 3, y2 : 8 },
			{ x1 : 4, y1 : 7, x2 : 4, y2 : 8 },
			{ x1 : 5, y1 : 7, x2 : 5, y2 : 8 },
         
         // bottom box
			{ x1 : 2, y1 : 9,  x2 : 2, y2 : 8 },
			{ x1 : 3, y1 : 9,  x2 : 3, y2 : 8 },
			{ x1 : 4, y1 : 9,  x2 : 4, y2 : 8 },
			{ x1 : 2, y1 : 9,  x2 : 1, y2 : 9 },
			{ x1 : 2, y1 : 10, x2 : 1, y2 : 10 },
			{ x1 : 2, y1 : 11, x2 : 1, y2 : 11 },
			{ x1 : 2, y1 : 12, x2 : 2, y2 : 11 },
			{ x1 : 3, y1 : 12, x2 : 3, y2 : 11 },
			{ x1 : 4, y1 : 12, x2 : 4, y2 : 11 },
			{ x1 : 4, y1 : 12, x2 : 4, y2 : 11 },
			{ x1 : 5, y1 : 9,  x2 : 4, y2 : 9 },
			{ x1 : 5, y1 : 10, x2 : 4, y2 : 10 },
			{ x1 : 5, y1 : 11, x2 : 4, y2 : 11 },
         // @formatter:on
		],
		heroCoord : {
			x : 3,
			y : 2
		}
	};

	public static var costOptimalityPreset : Preset = {
		walls : [
			{ x1 : 0, y1 : 1, x2 : 0, y2 : 2 },
			{ x1 : 1, y1 : 1, x2 : 1, y2 : 0 },
			{ x1 : 1, y1 : 1, x2 : 0, y2 : 1 },
			{ x1 : 1, y1 : 1, x2 : 1, y2 : 2 },
			{ x1 : 1, y1 : 1, x2 : 2, y2 : 1 },
			//
			{ x1 : 0, y1 : 3, x2 : 0, y2 : 4 },
			{ x1 : 1, y1 : 4, x2 : 0, y2 : 4 },
			//
			{ x1 : 1, y1 : 5, x2 : 1, y2 : 6 },
			{ x1 : 0, y1 : 6, x2 : 1, y2 : 6 },
			{ x1 : 1, y1 : 7, x2 : 1, y2 : 6 },
		],
		heroCoord : {
			x : 0,
			y : 0
		}
	};
}
