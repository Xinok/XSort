/++
	Stable Sort for Random-Access Ranges
	
	Written and tested for DMD 2.058 and Phobos
	
	Authors:  Xinok
	Date:     March 2012
	License:  Public Domain
++/

module stablesort;

private import std.range       : isRandomAccessRange, hasLength, hasSlicing, hasAssignableElements,
                                 SortedRange, assumeSorted, ElementType;
private import std.algorithm   : isSorted, copy, reverse;
private import std.functional  : binaryFun;
private import std.math        : log2;
private import std.array       : save;
private import std.c.stdlib    : alloca;
private import std.parallelism : task, taskPool, defaultPoolThreads;



/++
	Performs a stable sort on a random-access range according to predicate less.
	The algorithm is a natural merge sort using O(log n log n) additional space.
	
	Returns: Sorted input as SortedRange
	
	Params:
	range = Range to be sorted
	threaded = Set to true for concurrent sorting
	temp = Optionally provide your own additional space for sorting
	
	Params:
	less = Predicate (string, function, or delegate) used for comparing elements; Defaults to "a < b"
	inPlace = Set to true to perform an in-place sort using minimal additional space
	R = Type of range to be sorted; Must be a finite random-access range with slicing
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	stableSort(array);
	stableSort!"a > b"(array); // Sorts array descending
	-----------------
++/
@trusted SortedRange!(R, less) stableSort(alias less = "a < b", bool inPlace = false, R)(R range, bool threaded = false, ElementType!(R)[] temp = null)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
	
	if(temp is null || inPlace)
		StableSortImpl!(less, inPlace, R).sort(range, threaded);
	else
		StableSortImpl!(less, inPlace, R).sort(range, temp, threaded);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Stable Sort implemenation
template StableSortImpl(alias pred, bool inPlace = false, R)
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
	
	enum MIN_RUN    = 32;        // Maximum length for an insertion sort
	enum MAX_STACK  = 1024;      // Maximum number of bytes to allocate on stack
	enum MIN_THREAD = 1024 * 64; // Minimum length of a sublist to initiate new thread
	
	/// Entry sort function
	void sort(R range, bool threaded = false)
	{
		if(range.length <= MIN_RUN)
		{
			binaryInsertionSort(range);
			return;
		}
		
		// Allocate temporary memory
		T[] temp;
		
		static if(!inPlace)
		{
			if(__ctfe) temp = new T[1024 / T.sizeof];
			else
			{
				// Cannot use log2 or alloca at compile time
				immutable len = cast(size_t)(log2(range.length) * log2(range.length));
				if(T.sizeof * len > MAX_STACK) temp = new T[len];
				else temp = (cast(T*)alloca(T.sizeof * len))[0 .. len];
			}
		}
		
		sort(range, temp, threaded);
	}
	
	void sort(R range, T[] temp, bool threaded = false)
	{
		if(threaded && !__ctfe) concSort(range, defaultPoolThreads + 1, temp);
		else buildRun(range, range.length, temp);
	}
	
	/// Concurrently sorts range
	void concSort(R range, size_t threadCount, T[] temp)
	{
		if(threadCount < 2 || range.length < MIN_THREAD)
		{
			sort(range, temp);
			return;
		}
		
		immutable mid = (range.length / threadCount) * (threadCount / 2);
		immutable tempMid = (temp.length / threadCount) * (threadCount / 2);
		
		debug
		{
			//@ Threading code currently does not compile in debug builds
			sort(range, temp);
		}
		else
		{
			auto th = task!(concSort)(range[0 .. mid], threadCount / 2, temp[0 .. tempMid]);
			taskPool.put(th);
			concSort(range[mid .. range.length], threadCount - (threadCount / 2), temp[tempMid .. temp.length]);
			th.workForce();
			merge(range, mid, temp);
		}
	}
	
	/// Build run containing minLength elements
	size_t buildRun(R range, size_t minLength, T[] temp)
	{
		if(range.length <= MIN_RUN)
		{
			binaryInsertionSort(range);
			return range.length;
		}
		
		if(minLength >= range.length / 2) minLength = range.length;
		
		// Length of current run
		size_t curr = firstRun(range);
		
		if(curr < MIN_RUN)
		{
			binaryInsertionSort(range[0 .. MIN_RUN], curr);
			curr = MIN_RUN;
		}
		
		while(curr < minLength)
		{
			immutable next = curr + buildRun(range[curr .. range.length], curr, temp);
			merge(range[0 .. next], curr, temp);
			curr = next;
		}
		
		return curr;
	}
	
	/// Return length of first run in range
	size_t firstRun(R range)
	{
		assert(range.length >= 2);
		
		size_t i = 2;
		if(lessEqual(range[0], range[1]))
		{
			while(i < range.length && lessEqual(range[i-1], range[i])) ++i;
		}
		else
		{
			while(i < range.length && greater(range[i-1], range[i])) ++i;
			reverse(range[0..i]);
		}
		return i;
	}
	
	/// Merge two runs
	void merge(R range, size_t mid, T[] temp)
	{
		while(true)
		{
			assert(mid <= range.length);
			
			if(mid == 0 || mid == range.length) return;
			
			static if(inPlace)
			{
				// Calculate max number of insertions for in-place merge
				enum IN_PLACE = (MIN_RUN * (MIN_RUN - 1)) / 2;
				if(range.length <= IN_PLACE && mid * (range.length - mid) <= IN_PLACE)
				{
					mergeInsertion(range, mid);
					return;
				}
			}
			else
			{
				if(mid <= temp.length)
				{
					mergeSmall(range, mid, temp);
					return;
				}
				else if(range.length - mid <= temp.length)
				{
					mergeSmallReverse(range, mid, temp);
					return;
				}
			}
			
			R lef = range[0 .. mid], rig = range[mid .. range.length];
			
			if(lessEqual(range[mid-1], range[mid])) return;
			immutable split = mergeBig(lef, rig);
			
			if(lef.length <= rig.length)
			{
				merge(lef, split, temp);
				range = rig;
				mid = lef.length - split;
			}
			else
			{
				merge(rig, lef.length - split, temp);
				range = lef;
				mid = split;
			}
		}
	}
	
	/// Merge two small runs from front to back
	static if(!inPlace) void mergeSmall(R range, immutable size_t mid, T[] temp)
	{
		assert(mid <= range.length);
		
		temp = temp[0 .. mid];
		copy(range[0..mid], temp);
		
		size_t i = 0, lef = 0, rig = mid;
		
		while(true)
		{
			if(lessEqual(temp[lef], range[rig]))
			{
				range[i++] = temp[lef++];
				if(lef >= temp.length) return;
			}
			else
			{
				range[i++] = range[rig++];
				if(rig >= range.length) while(true)
				{
					range[i++] = temp[lef++];
					if(lef >= temp.length) return;
				}
			}
		}
	}
	
	/// Merge two small runs from back to front
	static if(!inPlace) void mergeSmallReverse(R range, immutable size_t mid, T[] temp)
	{
		assert(mid <= range.length);
		
		temp = temp[0 .. range.length - mid];
		copy(range[mid .. range.length], temp);
		
		size_t i = range.length - 1, lef = mid - 1, rig = temp.length - 1;
		
		while(true)
		{
			if(greaterEqual(temp[rig], range[lef]))
			{
				range[i--] = temp[rig];
				if(rig == 0) return;
				--rig;
			}
			else
			{
				range[i--] = range[lef];
				if(lef == 0) while(true)
				{
					range[i--] = temp[rig];
					if(rig == 0) return;
					--rig;
				}
				--lef;
			}
		}
	}
	
	/// Use insertion to merge two runs in-place
	static if(inPlace) void mergeInsertion(R range, immutable size_t mid){
		size_t lef = 0, rig = mid, i;
		T o;
		
		while(true){
			if(lessEqual(range[lef], range[rig])){
				++lef;
				if(lef >= rig) break;
			}
			else{
				o = range[rig];
				for(i = rig; i > lef; --i) range[i] = range[i-1];
				range[i] = o;
				++lef; ++rig;
				if(rig >= range.length) break;
			}
		}
	}
	
	/// Reduce two large runs into four smaller runs
	size_t mergeBig(R lef, R rig)
	{
		assert(lef.length > 0 && rig.length > 0);
		
		size_t lower = lef.length <= rig.length ? 0 : lef.length - rig.length;
		size_t center, upper = lef.length - 1;
		immutable off = lef.length - 1;
		while(upper != lower)
		{
			// This expression is written as to avoid integer overflow
			center = (upper - lower) / 2 + lower;
			if(greater(lef[center], rig[off - center])) upper = center;
			else lower = center + 1;
		}
		
		swapBlocks(lef[lower .. lef.length], rig[0 .. off-lower + 1]);
		
		return lower;
	}
	
	/// Swap two (adjacent) ranges of elements
	void swapBlocks(R lef, R rig)
	{
		assert(lef.length == rig.length);
		T o;
		foreach(i; 0 .. lef.length)
		{
			o = lef[i];
			lef[i] = rig[i];
			rig[i] = o;
		}
	}
	
	/// A simple insertion sort used for sorting small sublists
	void binaryInsertionSort(R range, size_t i = 1)
	{
		size_t lower, upper, center;
		T o;
		for(; i < range.length; ++i)
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
	bool testSort(alias pred, bool inPlace = false, R)(R range)
	{
		stableSort!(pred, inPlace, R)(range);
		return isSorted!pred(range);
	}
	
	int testCall(T)(in T[] arr)
	{
		int failures = 0;
		
		// Sort
		if(!testSort!"a < b"(arr.dup)) ++failures;
		if(!testSort!"a > b"(arr.dup)) ++failures;
		
		// In-place sort
		if(!testSort!("a < b", true)(arr.dup)) ++failures;
		if(!testSort!("a > b", true)(arr.dup)) ++failures;
		
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
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: stableSort CTFE unittest failed ", result, " of 4 tests");
	}
	
	// Stability test
	bool icmp(ubyte a, ubyte b)
	{
		if(a >= 'a') a -= 'a' - 'A';
		if(b >= 'a') b -= 'a' - 'A';
		return a < b;
	}
	ubyte[] str = cast(ubyte[])"ksugnqtoyedwpvbmifaclrhjzxWELPGDVJIHBAMZCFUNORKSTYXQ".dup;
	stableSort!icmp(str);
	assert(str == "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ");
}