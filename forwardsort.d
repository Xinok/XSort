/++
	Unstable Sort for Forward Ranges
	
	Written and tested for DMD 2.058 and Phobos
	
	Authors:  Xinok
	Date:     March 2012
	License:  Public Domain
++/

module forwardsort;

private import std.range       : isForwardRange, isInfinite, hasAssignableElements, ElementType, walkLength;
private import std.algorithm   : isSorted, swap;
private import std.functional  : binaryFun;
private import std.array       : save, front, popFront, empty;
// private import std.parallelism : task, taskPool, defaultPoolThreads;

/++
	Performs an unstable sort on a forward range according to predicate less.
	The algorithm is a quick sort which resorts to comb sort to avoid worst-case.
	
	Returns: Sorted input as SortedRange
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	forwardSort(array);
	forwardSort!"a > b"(array); // Sorts array descending
	-----------------
++/
void forwardSort(alias pred = "a < b", R)(R range)
{
	static assert(isForwardRange!R);
	static assert(!isInfinite!R);
	
	ForwardSortImpl!(pred, R).sort(range);
	if(!__ctfe) assert(isSorted!(pred)(range.save), "Range is not sorted");
}

/// Implementation of unstable sort for forward ranges
template ForwardSortImpl(alias pred, R)
{
	static assert(isForwardRange!R);
	static assert(!isInfinite!R);
	
	alias ElementType!R T;
	alias binaryFun!pred less;
	enum MAX_INSERT = 1024 / T.sizeof <= 32 ? 1024 / T.sizeof : 32;
	
	/// Entry sort function
	void sort(R range)
	{
		immutable len = walkLength(range.save);
		forwardQuickSort(range, len, len);
	}
	
	/// Performs a quick sort on a forward range
	void forwardQuickSort(R range, size_t len, real depth)
	{
		while(true)
		{
			if(len < MAX_INSERT)
			{
				binaryInsertionSort(range, len);
				return;
			}
			if(depth <= 1.0)
			{
				forwardCombSort(range, len);
				return;
			}
			
			depth /= 2.0;
			depth += depth / 2.0;
			
			size_t mid;
			R lef;
			partition(range, len, mid, lef);
			
			if(mid < len / 2)
			{
				forwardQuickSort(lef.save, len - mid - 1, depth);
				len = mid;
			}
			else
			{
				forwardQuickSort(range.save, mid, depth);
				range = lef.save;
				len = len - mid - 1;
			}
		}
	}
	
	void partition(R range, immutable size_t len, out size_t mid_out, out R range_out)
	{
		T pivot = range.front;
		R lef = range.save;
		R rig = range.save;
		rig.popFront();
		
		size_t mid = 0;
		for(size_t i = 1; i < len; ++i)
		{
			if(less(rig.front, pivot))
			{
				++mid;
				lef.popFront();
				swap(lef.front, rig.front);
			}
			rig.popFront();
		}
		
		swap(range.front, lef.front);
		lef.popFront();
		
		range_out = lef.save;
		mid_out = mid;
	}
	
	/// Performs a comb sort on a forward range; Used to avoid the worse-case of quick sort
	void forwardCombSort(R range, immutable size_t len)
	{
		size_t gap = len;
		bool swaps;
		while(gap > 1 || swaps)
		{
			if(gap > 1) gap /= 1.2473;
			swaps = false;
			
			R lef = range.save;
			R rig = range.save;
			
			foreach(i; 0..gap) rig.popFront();
			
			for(size_t i = gap; i < len; ++i)
			{
				if(less(rig.front, lef.front))
				{
					swap(lef.front, rig.front);
					swaps = true;
				}
				lef.popFront();
				rig.popFront();
			}
		}
	}

	/// An insertion sort used for sorting small sublists
	void binaryInsertionSort(R range, immutable size_t len)
	{
		assert(len <= MAX_INSERT);
		T[MAX_INSERT] arr;
		
		// Copy elements from range to array
		R temp = range.save;
		foreach(i; 0..len)
		{
			arr[i] = temp.front;
			temp.popFront();
		}
		
		// Begin insertion sort
		size_t lower, upper, center;
		T o;
		foreach(i; 1..len)
		{
			o = arr[i];
			lower = 0;
			upper = i;
			while(upper != lower)
			{
				center = (lower + upper) / 2;
				if(less(o, arr[center])) upper = center;
				else lower = center + 1;
			}
			for(upper = i; upper > lower; --upper) arr[upper] = arr[upper-1];
			arr[upper] = o;
		}
		// End insertion sort
		
		// Copy elements from array to range
		temp = range.save;
		foreach(i; 0..len)
		{
			temp.front = arr[i];
			temp.popFront();
		}
	}
}

unittest
{
	bool testSort(alias pred, R)(R range)
	{
		forwardSort!(pred, R)(range);
		return isSorted!pred(range);
	}
	
	int testCall(T)(in T[] arr)
	{
		int failures = 0;
		
		if(!testSort!"a < b"(arr.dup)) ++failures;
		if(!testSort!"a > b"(arr.dup)) ++failures;
		
		return failures;
	}
	
	// Array containing 256 random ints
	enum test = [
		10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70, 89, 94, 32, 46, 76, 43, 33, 62, 76, 
		37, 93, 45, 48, 49, 21, 67, 56, 58, 17, 15, 41, 91, 94, 95, 41, 38, 80, 37, 24, 
		26, 71, 87, 54, 72, 60, 29, 37, 41, 99, 31, 66, 75, 72, 86, 97, 37, 25, 98, 89, 
		53, 45, 52, 76, 51, 38, 59, 53, 74, 96, 94, 42, 68, 84, 65, 27, 49, 57, 53, 74, 
		39, 75, 39, 26, 46, 37, 68, 96, 19, 79, 73, 83, 36, 90, 11, 39, 48, 94, 97, 72, 
		37, 43, 69, 36, 41, 47, 31, 48, 33, 21, 20, 18, 45, 28, 47, 54, 41, 28, 47, 44, 
		51, 15, 21, 64, 82, 23, 41, 82, 30, 25, 78, 72, 50, 34, 45, 59, 14, 71, 50, 97, 
		39, 87, 74, 60, 52, 17, 87, 45, 69, 54, 91, 68, 46, 99, 78, 33, 27, 53, 41, 84, 
		82, 54, 29, 55, 53, 87, 13, 98, 55, 33, 73, 64, 19, 81, 57, 78, 23, 45, 94, 75, 
		55, 43, 93, 85, 96, 82, 44, 73, 22, 79, 89, 20, 36, 11, 12, 51, 86, 86, 75, 66, 
		81, 90, 80, 80, 36, 36, 47, 43, 86, 96, 45, 73, 70, 90, 57, 23, 86, 29, 12, 54, 
		37, 17, 87, 12, 36, 78, 26, 28, 30, 15, 10, 53, 76, 34, 23, 49, 65, 17, 37, 51, 
		26, 23, 66, 12, 26, 84, 60, 47, 30, 26, 78, 20, 42, 40, 63, 40
	];
	
	// Runtime test
	assert(testCall(test) == 0);
	
	// CTFE Test
	version(none)
	{
		enum result = testCall(test);
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: forwardSort CTFE unittest failed ", result, " of 2 tests");
	}
}