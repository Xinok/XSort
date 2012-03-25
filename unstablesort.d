/++
	Unstable Sort for Random-Access Ranges
	
	Written and tested for DMD 2.058 and Phobos
	
	Authors:  Xinok
	Date:     March 2012
	License:  Public Domain
++/

module unstablesort;

private import std.range       : isRandomAccessRange, hasLength, hasSlicing, hasAssignableElements,
                                 SortedRange, assumeSorted, ElementType;
private import std.algorithm   : isSorted, swap;
private import std.functional  : binaryFun;
private import std.array       : save;
private import std.parallelism : task, taskPool, defaultPoolThreads;
private import std.math;       // pow


/++
	Performs an unstable sort on a random-access range according to predicate less.
	The algorithm is a quick sort which resorts to shell sort to avoid worst-case.
	
	Returns: Sorted input as SortedRange
	
	Params:
	range = Range to be sorted
	threaded = Set to true for concurrent sorting
	
	Params:
	less = Predicate (string, function, or delegate) used for comparing elements; Defaults to "a < b"
	R = Type of range to be sorted; Must be a finite random-access range with slicing
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	unstableSort(array);
	unstableSort!"a > b"(array); // Sorts array descending
	-----------------
++/
@trusted SortedRange!(R, less) unstableSort(alias less = "a < b", R)(R range, bool threaded = false)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
	
	// UnstableSortImpl!(less, R).sort(range, threaded);
	UnstableSortImpl!(less, R).sort(range, threaded);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Unstable sort implementation
template UnstableSortImpl(alias pred, R)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
		
	alias ElementType!R T;
	
	alias binaryFun!pred less;
	bool greater(T a, T b){ return less(b, a); }
	bool greaterEqual(T a, T b){ return !less(a, b); }
	bool lessEqual(T a, T b){ return !less(b, a); }

	enum MAX_INSERT = 32;        // Maximum length for an insertion sort
	enum MIN_THREAD = 1024 * 64; // Minimum length of a sublist to initiate new thread
	
	/// Entry sort function
	void sort(R range, bool threaded = false)
	{
		if(threaded) concSort(range, range.length);
		else sort(range, range.length);
	}
	
	/// Recursively partition list
	void sort(R range, real depth)
	{
		while(true)
		{
			if(range.length <= MAX_INSERT)
			{
				binaryInsertionSort(range);
				return;
			}
			if(depth < 1.0)
			{
				shellSort(range);
				return;
			}
			
			depth /= 2.0;
			depth += depth / 2.0;
			
			immutable mid = partition(range);
			
			if(mid <= range.length / 2)
			{
				sort(range[0 .. mid - 1], depth);
				range = range[mid .. range.length];
			}
			else
			{
				sort(range[mid .. range.length], depth);
				range = range[0 .. mid - 1];
			}
		}
	}
	
	/// Concurrently sorts range
	void concSort(R range, real depth)
	{
		if(range.length <= MIN_THREAD)
		{
			sort(range, depth);
			return;
		}
		if(depth < 1.0)
		{
			shellSort(range);
			return;
		}
		
		depth /= 2.0;
		depth += depth / 2.0;
		
		immutable mid = partition(range);
		
		auto th = task!(concSort)(range[0 .. mid - 1], depth);
		taskPool.put(th);
		concSort(range[mid .. range.length], depth);
		th.workForce();
	}
	
	/// Partitions range, returns starting index of second range excluding pivot
	size_t partition(R range)
	{
		T o;
		
		// Median of Three
		{
			immutable low = 0, med = 1, hig = range.length - 1;
			swap(range[range.length / 2], range[med]);
			if(greater(range[low], range[med])) swap(range[low], range[med]);
			if(greater(range[med], range[hig])){
				swap(range[med], range[hig]);
				if(greater(range[low], range[med])) swap(range[low], range[med]);
			}
		}
		
		T piv = range[1];
		size_t lef = 2, rig = range.length - 2;
		
		// Partition range
		while(lef < rig)
		{
			if(lessEqual(range[lef], piv)) ++lef;
			else
			{
				o = range[lef];
				range[lef] = range[rig];
				range[rig] = o;
				--rig;
			}
			if(greaterEqual(range[rig], piv)) --rig;
			else
			{
				o = range[lef];
				range[lef] = range[rig];
				range[rig] = o;
				++lef;
			}
		}
		
		// Move pivot into place
		if(lessEqual(range[lef], piv)) ++lef; // This step is necessary and I'm not sure why
		swap(range[lef - 1], range[1]);
		
		return lef;
	}
	
	/// Generate gap sequence for shell sort
	pure immutable(size_t)[] shellGaps(size_t max){
		immutable(size_t)[] gaps = [1, 4, 10, 23, 57, 132, 301, 701, 1750];
		real k = 10;
		real gap;
		if(gaps[0] < max) while(true)
		{
			gap = (9 ^^ k - 4 ^^ k) / (5 * 4 ^^ (k - 1));
			if(gap > max) break;
			gaps ~= cast(size_t)gap;
			++k;
		}
		return gaps;
	}
	
	/// Shell sort is used to avoid the worst-case of quick sort
	void shellSort(R range)
	{
		immutable gaps = shellGaps(range.length);
		T o; size_t i;
		
		foreach_reverse(gap; gaps) if(gap < range.length)
		{
			foreach(start; gap .. range.length) if(less(range[start], range[start - gap]))
			{
				i = start;
				o = range[i];
				do
				{
					range[i] = range[i - gap];
					i -= gap;
				}
				while(i >= gap && less(o, range[i - gap]));
				range[i] = o;
			}
		}
	}
	
	/// A simple insertion sort used for sorting small sublists
	void binaryInsertionSort(R range)
	{
		size_t lower, upper, center;
		T o;
		for(size_t i = 1; i < range.length; ++i)
		{
			o = range[i];
			lower = 0;
			upper = i;
			while(upper != lower)
			{
				center = (lower + upper) / 2;
				if(less(o, range[center])) upper = center;
				else lower = center + 1;
			}
			for(upper = i; upper > lower; --upper) range[upper] = range[upper-1];
			range[upper] = o;
		}
	}
}

unittest
{
	bool testSort(alias pred, R)(R range)
	{
		unstableSort!(pred, R)(range);
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
	{
		enum result = testCall(test);
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: unstableSort CTFE unittest failed ", result, " of 2 tests");
	}
}