/++
	Merge Sort for Random-Access Ranges
	
	Written and tested for DMD 2.058 and Phobos
	
	Authors:  Xinok
	License:  Public Domain
++/

module mergesort;
import std.range, std.algorithm, std.functional, std.array;

/++
	Performs a merge sort on a random-access range according to predicate less.
	
	Returns: Sorted input as SortedRange
	
	Params:
	half = Set to true to merge using O(n/2) additional space
	temp = Optionally provide your own additional space for sorting
		
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	mergeSort(array);
	mergeSort!"a > b"(array); // Sorts array descending	
	-----------------
++/

@trusted SortedRange!(R, less) mergeSort(alias less = "a < b", R)(R range, bool half = false, ElementType!(R)[] temp = null)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
	
	MergeSortImpl!(less, R).sort(range, half, temp);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Merge Sort implementation
template MergeSortImpl(alias pred, R)
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

	/// Entry point for standard merge sort
	void sort(R range, bool half, T[] temp)
	{
		if(half)
		{
			if(temp.length < range.length / 2) temp.length = range.length / 2;
			splitHalf(range, temp);
		}
		else
		{
			if(temp.length < range.length) temp.length = range.length;
			split(range, temp);
		}
	}
	
	/// Recursively split range and merge halves
	void split(R range, T[] temp)
	{
		assert(temp.length >= range.length);
		
		if(range.length <= 32)
		{
			binaryInsertionSort(range);
			return;
		}
		immutable mid = range.length / 2;
		split(range[0 .. mid], temp[0 .. mid]);
		split(range[mid .. range.length], temp[mid .. temp.length]);
		merge(range, mid, temp);
	}
	
	/// Merge two halves using O(n) additional space
	void merge(R range, immutable size_t mid, T[] temp)
	{
		assert(mid <= range.length);
		
		size_t i = 0, lef = 0, rig = mid;
		while(true)
		{
			if(lessEqual(range[lef], range[rig]))
			{
				temp[i++] = range[lef++];
				if(lef >= mid) break;
			}
			else
			{
				temp[i++] = range[rig++];
				if(rig >= range.length)
				{
					while(lef < mid) temp[i++] = range[lef++];
					break;
				}
			}
		}
		copy(temp[0 .. i], range[0 .. i]);
	}
	
	/// Recursively split range and merge halves
	void splitHalf(R range, T[] temp)
	{
		if(range.length <= 32)
		{
			binaryInsertionSort(range);
			return;
		}
		immutable mid = range.length / 2;
		splitHalf(range[0 .. mid], temp[0 .. mid / 2]);
		splitHalf(range[mid .. range.length], temp[mid / 2 .. temp.length]);
		mergeHalf(range, mid, temp);
	}
	
	/// Merge two halves using O(n/2) additional space
	void mergeHalf(R range, immutable size_t mid, T[] temp)
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

	/// A simple insertion sort used for sorting small sublists
	void binaryInsertionSort(R range)
	{
		size_t lower, upper, center;
		T o;
		foreach(i; 0 .. range.length)
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
	bool testSort(alias pred, bool inPlace = false, R)(R range, bool half)
	{
		mergeSort!(pred, R)(range);
		return isSorted!pred(range);
	}
	
	int testCall(T)(in T[] arr)
	{
		int failures = 0;
		
		// Sort
		if(!testSort!"a < b"(arr.dup, false)) ++failures;
		if(!testSort!"a > b"(arr.dup, false)) ++failures;
		
		// Half Sort
		if(!testSort!("a < b")(arr.dup, true)) ++failures;
		if(!testSort!("a > b")(arr.dup, true)) ++failures;
		
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
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: mergeSort CTFE unittest failed ", result, " of 4 tests");
	}
	
	// Stability test
	bool icmp(ubyte a, ubyte b)
	{
		if(a >= 'a') a -= 'a' - 'A';
		if(b >= 'a') b -= 'a' - 'A';
		return a < b;
	}
	ubyte[] str = cast(ubyte[])"ksugnqtoyedwpvbmifaclrhjzxWELPGDVJIHBAMZCFUNORKSTYXQ".dup;
	mergeSort!icmp(str);
	assert(str == "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ");
}