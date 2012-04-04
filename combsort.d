/++
	Comb Sort for Random-Access Ranges
	
	Written and tested for DMD 2.058 and Phobos
	
	Bugs:
	CTFE results in out of memory error
	
	Authors:  Xinok
	License:  Public Domain
++/

module combsort;
import std.range, std.algorithm, std.functional, std.math;

/++
	Performs a comb sort on a random-access range according to predicate less.
	
	Returns: Sorted input as SortedRange
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	combSort(array);
	combSort!"a > b"(array); // Sorts array descending
	-----------------
++/

@trusted SortedRange!(R, less) combSort(alias less = "a < b", R)(R range, immutable real shrinkFactor = 1.2473)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	alias ElementType!R T;
	alias binaryFun!less lessFun;
	
	size_t gap = range.length;
	bool swapped;
	
	while(gap > 1 || swapped)
	{
		if(gap > 1) gap /= shrinkFactor;
		swapped = false;
		
		foreach(i; gap .. range.length) if(lessFun(range[i], range[i - gap]))
		{
			swap(range[i], range[i - gap]);
			swapped = true;
		}
	}
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Performs a comb sort ending with an insertion sort using linear search
@trusted SortedRange!(R, less) combSortLinear(alias less = "a < b", R)(R range, immutable real shrinkFactor = 1.375)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	alias ElementType!R T;
	alias binaryFun!less lessFun;
	
	size_t gap = range.length;
	
	// Comb sort
	while(true)
	{
		gap /= shrinkFactor;
		if(gap <= 1) break;
		
		foreach(i; gap .. range.length) if(lessFun(range[i], range[i - gap]))
		{
			swap(range[i], range[i - gap]);
		}
	}
	
	// Insertion sort
	T o; size_t j;
	for(size_t i = 1; i < range.length; ++i) if(lessFun(range[i], range[i-1]))
	{
		j = i; o = range[j];
		do
		{
			range[j] = range[j-1];
			--j;
		}
		while(j >= 1 && lessFun(o, range[j-1]));
		range[j] = o;
	}
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Performs a comb sort ending with an insertion sort using gallop search
@trusted SortedRange!(R, less) combSortGallop(alias less = "a < b", R)(R range, immutable real shrinkFactor = 1.44)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	alias ElementType!R T;
	alias binaryFun!less lessFun;
	
	size_t gap = range.length;
	
	// Comb sort
	while(true)
	{
		gap /= shrinkFactor;
		if(gap <= 1) break;
		
		foreach(i; gap .. range.length) if(lessFun(range[i], range[i - gap]))
		{
			swap(range[i], range[i - gap]);
		}
	}
	
	// Gallop insertion sort
	size_t lower, center, upper;
	T o;
	foreach(i; 1 .. range.length)
	{
		o = range[i];
		lower = 0;
		upper = i;
		gap = 1;
		
		// Gallop search
		while(gap <= upper)
		{
			if(lessFun(o, range[upper - gap]))
			{
				upper -= gap;
				gap *= 2;
				// ++gap;
			}
			else
			{
				lower = upper - gap + 1;
				break;
			}
		}
		
		// Binary search
		while(upper != lower)
		{
			center = (lower + upper) / 2;
			if(lessFun(o, range[center])) upper = center;
			else lower = center + 1;
		}
		
		// Insertion
		for(upper = i; upper > lower; --upper) range[upper] = range[upper-1];
		range[upper] = o;
	}
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

unittest
{
	bool testSort(alias pred, R)(R range)
	{
		combSort!(pred, R)(range);
		return isSorted!pred(range);
	}
	
	bool testSort2(alias pred, R)(R range)
	{
		combSortLinear!(pred, R)(range);
		return isSorted!pred(range);
	}
	
	bool testSort3(alias pred, R)(R range)
	{
		combSortGallop!(pred, R)(range);
		return isSorted!pred(range);
	}
	
	int testCall(T)(in T[] arr)
	{
		int failures = 0;
		
		if(!testSort!"a < b"(arr.dup)) ++failures;
		if(!testSort!"a > b"(arr.dup)) ++failures;
		if(!testSort2!"a < b"(arr.dup)) ++failures;
		if(!testSort2!"a > b"(arr.dup)) ++failures;
		if(!testSort3!"a < b"(arr.dup)) ++failures;
		if(!testSort3!"a > b"(arr.dup)) ++failures;
		
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
	//@ Disabled as it results in an out-of-memory error
	version(none)
	{
		enum result = testCall(test);
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: combSort CTFE unittest failed ", result, " of 6 tests");
	}
}