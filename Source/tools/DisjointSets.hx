package tools;

import haxe.ds.Vector;

class DisjointSets {
	private var s : Vector<Int>;
	private var numSets : Int;

	public function new( numElements : Int ) {
		s = new Vector<Int>(numElements);
		numSets = numElements;
		for ( i in 0...s.length )
			s[i] = -1;
	}

	public function union( root1 : Int, root2 : Int ) {
		if ( s[root2] < s[root1] ) {
			s[root1] = root2;
		} else {
			if ( s[root1] == s[root2] )
				s[root1] -= 1;
			s[root2] = root1;
		}
		numSets--;
	}

	public function find( x : Int ) : Int {
		if ( s[x] < 0 )
			return x;
		else
			return s[x] = find(s[x]);
	}

	public function numberOfSets() : Int {
		return numSets;
	}
}
