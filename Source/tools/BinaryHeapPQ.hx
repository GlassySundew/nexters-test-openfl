package tools;

typedef ArrayPQ<T> = {
	var data : Array<T>;
}
/**
	https://github.com/bguiz/hxstruct/blob/develop/src/bguiz/struct/pq/BinaryHeapPriorityQueue.hx

**/
class BinaryHeapPQ<T> {
	/**
		~logN
	**/
	public static function insert<T>(
		pq : ArrayPQ<T>, comparator : T -> T -> Int,
		value : T ) : Void {

		pq.data.push(value);
		promote(pq, comparator, pq.data.length - 1);
	}
	/**
		~logN
	**/
	public static function deleteTop<T>(
		pq : ArrayPQ<T>, comparator : T -> T -> Int ) : T {
		var topVal : T = pq.data[0];

		if ( pq.data.length > 1 )
			pq.data[0] = pq.data.pop();
		else pq.data = [];

		demote(pq, comparator, 0);
		return topVal;
	}

	public static function isEmpty<T>(
		pq : ArrayPQ<T> ) : Bool {
		return pq.data.length == 0;
	}
	/**
		~1
	**/
	public static function top<T>(
		pq : ArrayPQ<T>) : T {
		// First index - the root node - is always the top
		return pq.data[0];
	}

	public static function size<T>(
		pq : ArrayPQ<T> ) : Int {
		return pq.data.length;
	}

	private static function promote<T>(
		pq : ArrayPQ<T>, comparator : T -> T -> Int,
		index : Int ) : Void {
		while( index > 0 &&
			(comparator(pq.data[Std.int(index / 2)], pq.data[index]) < 0) ) {
			SortUtil.arraySwapIndices(pq.data, Std.int(index / 2), index);
			index = Std.int(index / 2);
		}
	}

	private static function demote<T>(
		pq : ArrayPQ<T>, comparator : T -> T -> Int,
		index : Int ) : Void {
		var len : Int = pq.data.length - 1;
		while( index * 2 <= len ) {
			var childIndex = index * 2;
			if ( childIndex < len &&
				comparator(pq.data[childIndex], pq.data[childIndex + 1]) < 0 ) {
				++childIndex;
			}
			if ( comparator(pq.data[index], pq.data[childIndex]) >= 0 ) {
				break;
			}
			SortUtil.arraySwapIndices(pq.data, index, childIndex);
			index = childIndex;
		}
	}
}
