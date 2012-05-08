/++
	Heap Sort for Random-Access Ranges
	
	Written and tested for DMD 2.059 and Phobos
	
	Authors:  Xinok
	License:  Public Domain
++/

module heapsort;
import std.range, std.algorithm, std.functional, std.array;

/++
	Performs a heap sort on a random-access range according to predicate less.
	
	Returns: Sorted input as SortedRange
	
	Params:
	heapifyMethod = Set to true for sift-up, or false for sift-down
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	heapSort(array);
	heapSort!"a > b"(array); // Sorts array descending
	heapSort(array, true);   // Sorts array using sift-up method
	-----------------
++/

@trusted SortedRange!(R, less) heapSort(alias less = "a < b", R)(R range, bool heapifyMethod = false)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	
	alias ElementType!R T;
	alias binaryFun!less lessFun;
	
	static void siftDown(R range, size_t root, immutable size_t end)
	{
		size_t child = void;
		T value = range[root];
		while(root * 2 < end)
		{
			child = root * 2 + 1;
			if(child < end && lessFun(range[child], range[child + 1]))
			{
				++child;
			}
			if(lessFun(value, range[child]))
			{
				range[root] = range[child];
				root = child;
			}
			else break;
		}
		range[root] = value;
	}
	
	static void siftUp(R range, size_t child)
	{
		size_t parent = void;
		T value = range[child];
		while(child > 0)
		{
			parent = (child - 1) / 2;
			if(lessFun(range[parent], value))
			{
				range[child] = range[parent];
				child = parent;
			}
			else break;
		}
		range[child] = value;
	}
	
	if(range.length > 1)
	{
		size_t i = void;
		immutable end = range.length - 1;
		
		// Heapify
		if(heapifyMethod)
		{
			for(i = 1; i < range.length; ++i) siftUp(range, i);
		}
		else
		{
			i = range.length / 2;
			while(i > 0) siftDown(range, --i, end);
		}
		
		i = end;
		while(i > 0)
		{
			swap(range[i], range[0]);
			siftDown(range, 0, --i);
		}
	}
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Performs a heap sort using a ternary heap
@trusted SortedRange!(R, less) ternaryHeapSort(alias less = "a < b", R)(R range, bool heapifyMethod = false)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	
	alias ElementType!R T;
	alias binaryFun!less lessFun;
	
	static void siftDown(R range, size_t root, immutable size_t end)
	{
		size_t child = void;
		T value = range[root];
		while(root * 3 < end)
		{
			child = root * 3 + 1;
			if(child < end && lessFun(range[child], range[child + 1]))
			{
				++child;
				if(child < end && lessFun(range[child], range[child + 1])) ++child;
			}
			else if(child < end - 1 && lessFun(range[child], range[child + 2]))
			{
				child += 2;
			}
			if(lessFun(value, range[child]))
			{
				range[root] = range[child];
				root = child;
			}
			else break;
		}
		range[root] = value;
	}
	
	static void siftUp(R range, size_t child)
	{
		size_t parent = void;
		T value = range[child];
		while(child > 0)
		{
			parent = (child - 1) / 3;
			if(lessFun(range[parent], value))
			{
				range[child] = range[parent];
				child = parent;
			}
			else break;
		}
		range[child] = value;
	}
	
	if(range.length > 1)
	{
		size_t i = void;
		immutable end = range.length - 1;
		
		// Heapify
		if(heapifyMethod)
		{
			for(i = 1; i < range.length; ++i) siftUp(range, i);
		}
		else
		{
			i = range.length / 3;
			while(i > 0) siftDown(range, --i, end);
		}
		
		i = end;
		while(i > 0)
		{
			swap(range[i], range[0]);
			siftDown(range, 0, --i);
		}
	}

	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

unittest
{
	bool testSort(alias pred, R)(R range, bool siftMethod)
	{
		heapSort!(pred, R)(range, siftMethod);
		return isSorted!pred(range);
	}
	
	bool testSort2(alias pred, R)(R range, bool siftMethod)
	{
		ternaryHeapSort!(pred, R)(range, siftMethod);
		return isSorted!pred(range);
	}
	
	int testCall(T)(in T[] arr)
	{
		int failures = 0;
		
		if(!testSort!"a < b"(arr.dup, false)) ++failures;
		if(!testSort!"a > b"(arr.dup, false)) ++failures;
		
		if(!testSort!"a < b"(arr.dup, true)) ++failures;
		if(!testSort!"a > b"(arr.dup, true)) ++failures;
		
		if(!testSort2!"a < b"(arr.dup, false)) ++failures;
		if(!testSort2!"a > b"(arr.dup, false)) ++failures;
		
		if(!testSort2!"a < b"(arr.dup, true)) ++failures;
		if(!testSort2!"a > b"(arr.dup, true)) ++failures;
		
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
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: unstableSort CTFE unittest failed ", result, " of 8 tests");
	}
}