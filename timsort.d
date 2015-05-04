/++
	Tim Sort for Random-Access Ranges
	
	Written and tested for DMD 2.060 and Phobos
	
	Authors:  Xinok
	License:  Public Domain
	
	Bugs: CTFE fails under DMD
++/

module timsort;
import std.range, std.algorithm, std.functional, std.array;

/++
	Performs a tim sort on a random-access range according to predicate less.
	
	Returns: Sorted input as SortedRange
	
	Params:
	temp = Optionally provide your own additional space for sorting
		
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	timSort(array);
	timSort!"a > b"(array); // Sorts array descending
	
	int[] temp;
	temp.length = 64;
	timSort(array, temp); // Sorts array using temporary memory provided by user
	-----------------
++/

@trusted SortedRange!(R, less) timSort(alias less = "a < b", R)(R range, ElementType!(R)[] temp = null)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
	
	TimSortImpl!(less, R).sort(range, temp);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Tim Sort implementation
template TimSortImpl(alias pred, R)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
		
	alias ElementType!R T;
	
	alias binaryFun!pred less;
	bool greater      (T a, T b){ return  less(b, a); }
	bool greaterEqual (T a, T b){ return !less(a, b); }
	bool lessEqual    (T a, T b){ return !less(b, a); }

	enum MIN_MERGE   = 64;
	enum MIN_GALLOP  = 7;
	enum MIN_STORAGE = 256;
	
	struct Slice{ size_t base, length; }
	
	/// Entry point for tim sort
	void sort(R range, scope T[] temp)
	{
		// Do insertion sort on small range
		if(range.length <= MIN_MERGE * 4)
		{
			binaryInsertionSort(range);
			return;
		}
		
		immutable minRun     = calcMinRun(range.length);
		immutable minTemp    = range.length / 2 < MIN_STORAGE ? range.length / 2 : MIN_STORAGE;
		size_t    minGallop  = MIN_GALLOP;
		Slice[40] stack      = void;
		size_t    stackLen   = 0;
		size_t    runLen     = 0;
        size_t    collapseAt = 0;
		
		// Allocate temporary memory if not enough provided by user
		if(temp.length < minTemp) temp = uninitializedArray!(T[])(minTemp);
		
		// Build and merge runs
		for(size_t i = 0; i < range.length; )
		{
			// Find length of first run in list
			runLen = firstRun(range[i .. range.length]);
			
			// If run has less than minRun elements, extend using insertion sort
			if(runLen < minRun)
			{
				// Do not run farther than the length of the range
				immutable force = range.length - i > minRun ? minRun : range.length - i;
				binaryInsertionSort(range[i .. i + force], runLen);
				runLen = force;
			}
			
			// Push run onto stack
			stack[stackLen++] = Slice(i, runLen);
			i += runLen;
            
            /+
                Collapse stack until the variant is established:
                r1 > r2 + r3 && r2 > r3
                where r1, r2, r3 are the lengths of adjacent runs on the stack
                
                Credit given for fix and code adapted from this article:
                http://envisage-project.eu/proving-android-java-and-python-sorting-algorithm-is-broken-and-how-to-fix-it/
            +/
            while(stackLen > 1)
            {
                immutable r1 = stackLen - 4, r2 = r1 + 1, r3 = r2 + 1, r4 = r3 + 1;
                
                if( stackLen > 2 && stack[r2].length <= stack[r3].length + stack[r4].length || 
                    stackLen > 3 && stack[r1].length <= stack[r3].length + stack[r2].length )
                {
                    if(stack[r2].length < stack[r4].length) collapseAt = r2;
                    else collapseAt = r3;
                }
                else if(stack[r3].length > stack[r4].length) break;
                else collapseAt = r3;
                
                mergeAt(range, stack[0 .. stackLen], collapseAt, minGallop, temp);
                stackLen -= 1;
            }
            
            // Assert that the code above established the invariant correctly
            version(unittest)
            {
                if(stackLen == 2) assert(stack[0].length > stack[1].length);
                else if(stackLen > 2) foreach(k; 2 .. stackLen)
                {
                    assert(stack[k - 2].length > stack[k - 1].length + stack[k].length);
                    assert(stack[k - 1].length > stack[k].length);
                }
            }
		}
		
		// Force collapse stack until there is only one run left
		while(stackLen > 1)
		{
			if(stackLen >= 3 && stack[stackLen - 3].length <= stack[stackLen - 1].length)
				collapseAt = stackLen - 3;
			else
				collapseAt = stackLen - 2;
			
			mergeAt(range, stack[0 .. stackLen--], collapseAt, minGallop, temp);
		}
	}
	
	/// Calculates optimal value for minRun
	pure size_t calcMinRun(size_t n)
	{
		size_t r = 0;
		while(n >= MIN_MERGE)
		{
			r |= n & 1;
			n >>= 1;
		}
		return n + r;
	}
	
	/// Returns length of first run in range
	size_t firstRun(R range)
	out(ret)
	{
		assert(ret <= range.length);
	}
	body
	{
		if(range.length < 2) return range.length;
		
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

	/// A binary insertion sort for building runs up to minRun length
	void binaryInsertionSort(R range, size_t i = 1)
	out
	{
		if(!__ctfe) assert(isSorted!pred(range));
	}
	body
	{
		size_t lower, upper, center;
		T o;
		for(; i < range.length; ++i)
		{
			o = range[i];
			lower = 0;
			upper = i;
			
			// Binary search
			while(upper != lower)
			{
				center = (lower + upper) / 2;
				if(less(o, range[center])) upper = center;
				else lower = center + 1;
			}
			
			// Insertion
			for(upper = i; upper > lower; --upper) range[upper] = range[upper - 1];
			range[upper] = o;
		}
	}
	
	/// Merge two runs in stack (at, at + 1)
	void mergeAt(R range, Slice[] stack, immutable size_t at, ref size_t minGallop, ref T[] temp)
	in
	{
		assert(stack.length >= 2);
        assert(stack.length - at == 2 || stack.length - at == 3);
	}
	body
	{
		// Calculate bounds of runs from stack
		size_t    firstElement = stack[at].base;
		size_t    midElement   = stack[at].length + firstElement;
		size_t    lastElement  = stack[at + 1].length + midElement;
		immutable maxCapacity  = range.length / 2;
		
		// Pop run from stack
		stack[at] = Slice(firstElement, lastElement - firstElement);
		if(stack.length - at == 3) stack[$ - 2] = stack[$ - 1];
		
		// Slice range to bounds to be merged
		range = range[firstElement .. lastElement];
		midElement -= firstElement;
		
		// Preliminary asserts and unittests
		assert(midElement < range.length);
		if(!__ctfe)
		{
			assert(isSorted!pred(range[0 .. midElement]));
			assert(isSorted!pred(range[midElement .. range.length]));
		}
		
		// Take the last element in the first run and find its position in the second run
		// Likewise, take the first element in the second run and find its position in the first run
		// Outside of this range, the elements are already in place, so there is no need to merge them.
		// Slice the range to exclude those elements.
		firstElement = gallopForwardUpper(range[0 .. midElement], range[midElement]);
		lastElement  = gallopReverseLower(range[midElement .. range.length], range[midElement - 1]) + midElement;
		range = range[firstElement .. lastElement];
		midElement -= firstElement;
		
		// If first or second range is empty, then exit as there is nothing to do.
		if(midElement == 0 || midElement == range.length) return;
		
		// Call merge function which will copy the smaller run into temporary memory
		if(midElement <= range.length / 2)
		{
			temp = ensureCapacity(midElement, maxCapacity, temp);
			minGallop = mergeLo(range, midElement, minGallop, temp);
		}
		else
		{
			temp = ensureCapacity(range.length - midElement, maxCapacity, temp);
			minGallop = mergeHi(range, midElement, minGallop, temp);
		}
	}
	
	/// Enlarge size of temporary space if needed.
	/// Temporary space is increased exponentially by powers of two.
	T[] ensureCapacity(size_t minCapacity, size_t maxCapacity, T[] temp)
	in
	{
		assert(minCapacity <= maxCapacity);
	}
	out(ret)
	{
		assert(ret.length >= minCapacity);
		assert(ret.length <= maxCapacity);
	}
	body
	{
		if(temp.length < minCapacity)
		{
			size_t newSize = MIN_STORAGE * 2;
			while(newSize < minCapacity) newSize *= 2;
			// If newSize exceeds half of maxCapacity, simply increase to maxCapacity
			// This will prevent a minor reallocation such as 1024 -> 1040
			if(newSize > maxCapacity / 2) newSize = maxCapacity;
			if(temp.length < newSize) temp.length = newSize;
		}
		return temp;
	}
	
	/// Merge front to back. Returns new value of minGallop.
	/// temp must be large enough to store range[0 .. mid]
	size_t mergeLo(R range, immutable size_t mid, size_t minGallop, T[] temp)
	out
	{
		if(!__ctfe) assert(isSorted!pred(range));
	}
	body
	{
		assert(mid <= range.length);
		assert(temp.length >= mid);
		
		// Copy run into temporary memory
		temp = temp[0 .. mid];
		copy(range[0 .. mid], temp);
		
		// Move first element into place
		range[0] = range[mid];
		
		size_t i = 1, lef = 0, rig = mid + 1;
		size_t count_lef, count_rig;
		immutable lef_end = temp.length - 1;
		
		if(lef < lef_end && rig < range.length)
		outer: while(true)
		{
			count_lef = 0;
			count_rig = 0;
			
			// Linear merge
			while((count_lef | count_rig) < minGallop)
			{
				if(lessEqual(temp[lef], range[rig]))
				{
					range[i++] = temp[lef++];
					if(lef >= lef_end) break outer;
					++count_lef;
					count_rig = 0;
				}
				else
				{
					range[i++] = range[rig++];
					if(rig >= range.length) break outer;
					count_lef = 0;
					++count_rig;
				}
			}
			
			// Gallop merge
			do
			{
				count_lef = gallopForwardUpper(temp[lef .. $], range[rig]);
				foreach(j; 0 .. count_lef) range[i++] = temp[lef++];
				if(lef >= temp.length) break outer;
				
				count_rig = gallopForwardLower(range[rig .. range.length], temp[lef]);
				foreach(j; 0 .. count_rig) range[i++] = range[rig++];
				if(rig >= range.length) while(true)
				{
					range[i++] = temp[lef++];
					if(lef >= temp.length) break outer;
				}
				
				if(minGallop > 0) --minGallop;
			}
			while(count_lef >= MIN_GALLOP || count_rig >= MIN_GALLOP);
			
			minGallop += 2;
		}
		
		// Move remaining elements from right
		while(rig < range.length) range[i++] = range[rig++];
		
		// Move remaining elements from left
		while(lef < temp.length) range[i++] = temp[lef++];
		
		return minGallop > 0 ? minGallop : 1;
	}
	
	/// Merge back to front. Returns new value of minGallop.
	/// temp must be large enough to store range[mid .. range.length]
	size_t mergeHi(R range, immutable size_t mid, size_t minGallop, T[] temp)
	out
	{
		if(!__ctfe) assert(isSorted!pred(range));
	}
	body
	{
		assert(mid <= range.length);
		assert(temp.length >= range.length - mid);
		
		// Copy run into temporary memory
		temp = temp[0 .. range.length - mid];
		copy(range[mid .. range.length], temp);
		
		// Move first element into place
		range[range.length - 1] = range[mid - 1];
		
		size_t i = range.length - 2, lef = mid - 2, rig = temp.length - 1;
		size_t count_lef, count_rig;
		
		outer:
		while(true)
		{
			count_lef = 0;
			count_rig = 0;
			
			// Linear merge
			while((count_lef | count_rig) < minGallop)
			{
				if(greaterEqual(temp[rig], range[lef]))
				{
					range[i--] = temp[rig];
					if(rig == 1)
					{
						// Move remaining elements from left
						while(true)
						{
							range[i--] = range[lef];
							if(lef == 0) break;
							--lef;
						}
						
						// Move last element into place
						range[i] = temp[0];
						
						break outer;
					}
					--rig;
					count_lef = 0;
					++count_rig;
				}
				else
				{
					range[i--] = range[lef];
					if(lef == 0) while(true)
					{
						range[i--] = temp[rig];
						if(rig == 0) break outer;
						--rig;
					}
					--lef;
					++count_lef;
					count_rig = 0;
				}
			}
			
			// Gallop merge
			do
			{
				count_rig = rig - gallopReverseLower(temp[0 .. rig], range[lef]);
				foreach(j; 0 .. count_rig)
				{
					range[i--] = temp[rig];
					if(rig == 0) break outer;
					--rig;
				}
				
				count_lef = lef - gallopReverseUpper(range[0 .. lef], temp[rig]);
				foreach(j; 0 .. count_lef)
				{
					range[i--] = range[lef];
					if(lef == 0) while(true)
					{
						range[i--] = temp[rig];
						if(rig == 0) break outer;
						--rig;
					}
					--lef;
				}
				
				if(minGallop > 0) --minGallop;
			}
			while(count_lef >= MIN_GALLOP || count_rig >= MIN_GALLOP);
			
			minGallop += 2;
		}
		
		return minGallop > 0 ? minGallop : 1;
	}
	
	alias gallopSearch!(false, false) gallopForwardLower;
	alias gallopSearch!(false, true)  gallopForwardUpper;
	alias gallopSearch!(true, false)  gallopReverseLower;
	alias gallopSearch!(true, true)   gallopReverseUpper;
	
	template gallopSearch(bool forwardReverse, bool lowerUpper)
	{
		/// Gallop search on range according to attributes forwardReverse and lowerUpper
		size_t gallopSearch(R)(R range, T value)
		out(ret)
		{
			assert(ret <= range.length);
		}
		body
		{
			size_t lower = 0, center = 1, upper = range.length;
			alias center gap;
			
			static if(forwardReverse)
			{
				static if(!lowerUpper) alias lessEqual comp; // reverse lower
				static if(lowerUpper)  alias less comp;      // reverse upper
				
				// Gallop Search Reverse
				while(gap <= upper)
				{
					if(comp(value, range[upper - gap]))
					{
						upper -= gap;
						gap *= 2;
					}
					else
					{
						lower = upper - gap;
						break;
					}
				}
				
				// Binary Search Reverse
				while(upper != lower)
				{
					center = lower + (upper - lower) / 2;
					if(comp(value, range[center])) upper = center;
					else lower = center + 1;
				}
			}
			else
			{
				static if(!lowerUpper) alias greater comp;      // forward lower
				static if(lowerUpper)  alias greaterEqual comp; // forward upper
				
				// Gallop Search Forward
				while(lower + gap < upper)
				{
					if(comp(value, range[lower + gap]))
					{
						lower += gap;
						gap *= 2;
					}
					else
					{
						upper = lower + gap;
						break;
					}
				}
				
				// Binary Search Forward
				while(lower != upper)
				{
					center = lower + (upper - lower) / 2;
					if(comp(value, range[center])) lower = center + 1;
					else upper = center;
				}
			}
			
			return lower;
		}
	}
	
	//@ Workaround for DMD issue 7898
	static if(__VERSION__ == 2059)
	void copy(R1, R2)(R1 src, R2 dst)
	{
		import std.traits;
		static if(isArray!R1 && isArray!R2) if(__ctfe)
		{
			dst[] = src[];
			return;
		}
		std.algorithm.copy(src, dst);
	}
}

unittest
{
	import std.random;
	
	// Element type with two fields
	static struct E
	{
		size_t value, index;
	}
	
	// Generates data especially for testing sorting with Timsort
	static E[] genSampleData(uint seed)
	{
		auto rnd = Random(seed);
		
		E[] arr;
		arr.length = 64 * 64;
		
		// We want duplicate values for testing stability
		foreach(i, ref v; arr) v.value = i / 64;
		
		// Swap ranges at random middle point (test large merge operation)
		immutable mid = uniform(arr.length / 4, arr.length / 4 * 3, rnd);
		swapRanges(arr[0 .. mid], arr[mid .. $]);
		
		// Shuffle last 1/8 of the array (test insertion sort and linear merge)
		randomShuffle(arr[$ / 8 * 7 .. $], rnd);
		
		// Swap few random elements (test galloping mode)
		foreach(i; 0 .. arr.length / 64)
		{
			immutable a = uniform(0, arr.length, rnd), b = uniform(0, arr.length, rnd);
			swap(arr[a], arr[b]);
		}
		
		// Now that our test array is prepped, store original index value
		// This will allow us to confirm the array was sorted stably
		foreach(i, ref v; arr) v.index = i;
		
		return arr;
	}
	
	// Tests the Timsort function for correctness and stability
	static bool testSort(uint seed)
	{
		auto arr = genSampleData(seed);
	
		// Now sort the array!
		static bool comp(E a, E b)
		{
			return a.value < b.value;
		}
		
		timSort!comp(arr);
		
		// Test that the array was sorted correctly
		assert(isSorted!comp(arr));
		
		// Test that the array was sorted stably
		foreach(i; 0 .. arr.length - 1)
		{
			if(arr[i].value == arr[i + 1].value) assert(arr[i].index < arr[i + 1].index);
		}
		
		return true;
	}
	
	enum seed = 310614065;
	testSort(seed);
	
	enum result = testSort(seed);
}

unittest
{
    // Test case for the following issue:
    // http://envisage-project.eu/proving-android-java-and-python-sorting-algorithm-is-broken-and-how-to-fix-it/
    
    import std.array, std.range;
    auto arr = chain(iota(0, 384), iota(0, 256), iota(0, 80), iota(0, 64), iota(0, 96)).array;
    timSort(arr);
}