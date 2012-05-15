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
	ternary       = Set to true for ternary heap, or false for binary heap
	heapifyMethod = Set to true for sift-up, or false for sift-down
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	heapSort(array);
	heapSort!"a > b"(array);          // Sorts array descending
	heapSort!("a < b", false)(array); // Sorts array using binary heap
	heapSort(array, true);            // Sorts array using sift-up method
	-----------------
++/

@trusted SortedRange!(R, less) heapSort(alias less = "a < b", bool ternary = true, R)(R range, bool heapifyMethod = false)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	
	HeapSortImpl!(less, ternary, R).sort(range, heapifyMethod);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

template HeapSortImpl(alias pred, bool ternary, R)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	
	alias ElementType!R T;
	alias binaryFun!pred less;
	
	enum base = ternary ? 3 : 2;
	
	void sort(R range, bool heapifyMethod)
	{
		// Nothing to do
		if(range.length < 2) return;
		
		size_t i = void;
		immutable end = range.length - 1;
		
		// Heapify
		if(heapifyMethod)
		{
			for(i = 1; i < range.length; ++i) siftUp(range, i);
		}
		else
		{
			i = (range.length - 2) / base + 1;
			while(i > 0) siftDown(range, --i, end);
		}
		
		// Sort
		i = end;
		while(i > 0)
		{
			swap(range[i], range[0]);
			siftDown(range, 0, --i);
		}
	}
	
	static void siftDown(R range, size_t root, immutable size_t end)
	{
		size_t child = void;
		T value = range[root];
		while(root * base < end)
		{
			child = root * base + 1;
			
			if(child < end && less(range[child], range[child + 1]))
			{
				++child;
				static if(ternary) if(child < end && less(range[child], range[child + 1])) ++child;
			}
			else static if(ternary) if(child < end - 1 && less(range[child], range[child + 2]))
			{
				child += 2;
			}
			
			if(less(value, range[child]))
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
			parent = (child - 1) / base;
			if(less(range[parent], value))
			{
				range[child] = range[parent];
				child = parent;
			}
			else break;
		}
		range[child] = value;
	}
}

/++
	Performs a variation of heap sort as described by Bahlul Haider
	Web: $(LINK http://www.csd.uwo.ca/People/gradstudents/mhaider5/)
++/

@trusted SortedRange!(R, less) haiderHeapSort(alias less = "a < b", R)(R range)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	
	HaiderImpl!(less, R).sort(range);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

template HaiderImpl(alias pred, R)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
		
	alias ElementType!R T;
	
	alias binaryFun!pred less;
	bool greater(T a, T b){ return less(b, a); }
	bool greaterEqual(T a, T b){ return !less(a, b); }
	bool lessEqual(T a, T b){ return !less(b, a); }
	
	void sort(R range)
	{
		size_t[48] sp = void; // Pass to heapify
		
		// Build Heap
		foreach_reverse(i; 0 .. (range.length - 2) / 3 + 1)
			heapify(range, sp, range[i], i, range.length);
		
		// Sort Heap
		T temp;
		foreach_reverse(i; 1 .. range.length)
		{
			temp = range[i];
			range[i] = range[0];
			heapify(range, sp, temp, 0, i);
		}
	}
	
	void heapify(R range, size_t[] sp, T temp, size_t root, immutable size_t end)
	{
		size_t highest = root, child = 0, sl = 0;
		sp[0] = root;
		
		while(true)
		{
			child = 3 * highest + 1;
			
			if(child >= end) break;
			
			if(child + 1 == end)
			{
				highest = child;
				sp[++sl] = child;
				break;
			}
			
			if(child + 2 == end)
			{
				if(greater(range[child], range[child + 1]))
					highest = child;
				else
					highest = child + 1;
				
				sp[++sl] = highest;
				break;
			}
			
			if(greaterEqual(range[child + 2], range[child + 1]))
				highest = child + 2;
			else
				highest = child + 1;
			
			if(greater(range[child], range[highest]))
				highest = child;
			
			sp[++sl] = highest;
		}
		
		while(less(range[sp[sl]], temp) && sl > 0) --sl;
		foreach(j; 0 .. sl) range[sp[j]] = range[sp[j + 1]];
		range[sp[sl]] = temp;
	}
}

/++
	Performs a bottom-up heap sort on a random-access range according to predicate less.
	
	Returns: Sorted input as SortedRange
	
	Params:
	ternary = Set to true for ternary heap, or false for binary heap
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	bottomUpHeapSort(array);
	bottomUpHeapSort!"a > b"(array);         // Sorts array descending
	bottomUpHeapSort!("a < b", true)(array); // Sorts array using binary heap
	-----------------
++/

@trusted SortedRange!(R, less) bottomUpHeapSort(alias less = "a < b", bool ternary = false, R)(R range)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	
	BottomUpHeapSortImpl!(less, ternary, R).sort(range);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

template BottomUpHeapSortImpl(alias pred, bool ternary, R)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasAssignableElements!R);
	
	alias ElementType!R T;
	alias binaryFun!pred less;
	
	enum base = ternary ? 3 : 2;
	
	void sort(R range)
	{
		if(range.length < 2) return;
		
		// Heapify
		size_t i = (range.length - 2) / base + 1;
		while(i > 0) sift(range, --i, range.length);
		
		// Sort
		i = range.length - 1;
		while(i > 0)
		{
			swap(range[0], range[i]);
			sift(range, 0, i);
			--i;
		}
	}
	
	void sift(R range, size_t parent, immutable size_t end)
	{
		immutable root = parent;
		T value = range[parent];
		size_t child = void;
		
		// Sift down
		while(true)
		{
			child = parent * base + 1;
			
			if(child >= end) break;
			
			if(child + 1 < end && less(range[child], range[child + 1]))
			{
				if(ternary && child + 2 < end && less(range[child + 1], range[child + 2]))
					child += 2;
				else
					child += 1;
			}
			else if(ternary && child + 2 < end && less(range[child], range[child + 2]))
				child += 2;
			
			range[parent] = range[child];
			parent = child;
		}
		
		child = parent;
		
		// Sift up
		while(child > root)
		{
			parent = (child - 1) / base;
			if(less(range[parent], value))
			{
				range[child] = range[parent];
				child = parent;
			}
			else break;
		}
		
		range[child] = value;
	}
}

unittest
{
	bool testSort(alias pred, bool ternary, R)(R range, bool siftMethod)
	{
		heapSort!(pred, ternary, R)(range, siftMethod);
		return isSorted!pred(range);
	}
	
	bool testSort2(alias pred, R)(R range)
	{
		haiderHeapSort!(pred, R)(range);
		return isSorted!pred(range);
	}
	
	bool testSort3(alias pred, bool ternary, R)(R range)
	{
		bottomUpHeapSort!(pred, ternary, R)(range);
		return isSorted!pred(range);
	}
	
	int testCall(T)(in T[] arr)
	{
		int failures = 0;
		
		if(!testSort!("a < b", false)(arr.dup, false)) ++failures;
		if(!testSort!("a > b", false)(arr.dup, false)) ++failures;
		
		if(!testSort!("a < b", false)(arr.dup, true)) ++failures;
		if(!testSort!("a > b", false)(arr.dup, true)) ++failures;
		
		if(!testSort!("a < b", true)(arr.dup, false)) ++failures;
		if(!testSort!("a > b", true)(arr.dup, false)) ++failures;
		
		if(!testSort!("a < b", true)(arr.dup, true)) ++failures;
		if(!testSort!("a > b", true)(arr.dup, true)) ++failures;
		
		if(!testSort2!"a < b"(arr.dup)) ++failures;
		if(!testSort2!"a > b"(arr.dup)) ++failures;
		
		if(!testSort3!("a < b", false)(arr.dup)) ++failures;
		if(!testSort3!("a > b", false)(arr.dup)) ++failures;
		
		if(!testSort3!("a < b", true)(arr.dup)) ++failures;
		if(!testSort3!("a > b", true)(arr.dup)) ++failures;
		
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
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: heap sort CTFE unittest failed ", result, " of 14 tests");
	}
}