/++
	Tim Sort Variant for Random-Access Ranges

	Authors:  Xinok
	License:  Public Domain
	
	Bugs: CTFE fails under DMD
++/

module timsortlow;
import std.range, std.algorithm, std.functional, std.array;

/++
	Stably sorts a random-access range according to predicate less.
	The algorithm is a variant of tim sort with lower space complexity and no reallocations.
	
	Returns: Sorted input as SortedRange
	
	Params:
	temp = Optionally provide your own additional space for sorting
		
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	timSortLow(array);
	timSortLow!"a > b"(array); // Sorts array descending
	
	int[] temp;
	temp.length = 64;
	timSortLow(array, temp); // Sorts array using temporary memory provided by user
	-----------------
++/

@trusted SortedRange!(R, less) timSortLow(alias less = "a < b", R)(R range, ElementType!(R)[] temp = null)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
	
	TimSortLowImpl!(less, R).sort(range, temp);
	
	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Tim Sort Low implementation
template TimSortLowImpl(alias pred, R)
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

	enum MIN_MERGE   = 32;
	enum MIN_GALLOP  = 7;
	
	struct Slice{ size_t base, length; }
	
	/// Entry point for tim sort
	void sort(R range, T[] temp)
	{
		// Do insertion sort on small range
		if(range.length <= MIN_MERGE * 4)
		{
			binaryInsertionSort(range);
			return;
		}
		
		immutable minRun     = calcMinRun(range.length);
		size_t    minGallop  = MIN_GALLOP;
		Slice[40] stack      = void;
		size_t    stackLen   = 0;
		size_t    runLen     = 0;
        size_t    collapseAt = 0;
		
		// Allocate temporary memory if not provided by user
		if(temp.length == 0)
			temp.length = max(range.length / 1024, min(range.length / 2, MIN_MERGE));
		
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
			for(upper = i; upper > lower; --upper) range[upper] = range[upper-1];
			range[upper] = o;
		}
	}
	
	/// Merge two runs in stack (at, at + 1)
	void mergeAt(R range, Slice[] stack, immutable size_t at, ref size_t minGallop, T[] temp)
	in
	{
		assert(stack.length >= 2);
		assert(stack.length - at == 2 || stack.length - at == 3);
	}
	body
	{
		// Calculate bounds of runs from stack
		immutable base = stack[at].base;
		immutable mid  = stack[at].length;
		immutable len  = stack[at + 1].length + mid;
		
		// Pop run from stack
		stack[at] = Slice(base, len);
		if(stack.length - at == 3) stack[$ - 2] = stack[$ - 1];
		
		// Merge runs (at, at + 1)
		return merge(range[base .. base + len], mid, minGallop, temp);
	}
	
	void merge(R range, size_t mid, ref size_t minGallop, T[] temp)
	in
	{
		assert(mid <= range.length);
		if(!__ctfe)
		{
			assert(isSorted!pred(range[0 .. mid]));
			assert(isSorted!pred(range[mid .. range.length]));
		}
	}
	body
	{
		while(true)
		{
			// If left or right run is empty, there is nothing to do.
			if(mid == 0 || mid == range.length) return;
			
			// If this condition is true, then the range is already sorted and there is nothing to do.
			if(lessEqual(range[mid - 1], range[mid])) return;
			
			// If smaller run is small enough to fit into temp, then merge.
			if(mid <= range.length / 2)
			{
				if(mid <= temp.length)
				{
					minGallop = mergeLo(range, mid, minGallop, temp);
					return;
				}
			}
			else
			{
				if(range.length - mid <= temp.length)
				{
					minGallop = mergeHi(range, mid, minGallop, temp);
					return;
				}
			}
			
			// If both runs are too large, use rotations to break up into smaller runs
			R lef = range[0 .. mid], rig = range[mid .. range.length];
			immutable split = mergeBig(lef, rig);
			
			if(lef.length <= rig.length)
			{
				merge(lef, split, minGallop, temp);
				range = rig;
				mid = lef.length - split;
			}
			else
			{
				merge(rig, lef.length - split, minGallop, temp);
				range = lef;
				mid = split;
			}
		}
	}
	
	/// Use rotation to reduce two large runs into four smaller runs
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
		
		swapBlocks(lef[lower .. lef.length], rig[0 .. off - lower + 1]);
		
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
		copy(range[0..mid], temp);
		
		size_t i = 0, lef = 0, rig = mid;
		size_t count_lef, count_rig;
		
		outer:
		while(true)
		{
			count_lef = 0;
			count_rig = 0;
			
			// Linear merge
			while((count_lef | count_rig) < minGallop)
			{
				if(lessEqual(temp[lef], range[rig]))
				{
					range[i++] = temp[lef++];
					if(lef >= temp.length) break outer;
					++count_lef;
					count_rig = 0;
				}
				else
				{
					range[i++] = range[rig++];
					if(rig >= range.length) while(true)
					{
						range[i++] = temp[lef++];
						if(lef >= temp.length) break outer;
					}
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
		
		size_t i = range.length - 1, lef = mid - 1, rig = temp.length - 1;
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
					if(rig == 0) break outer;
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
		/// Gallop search on range according to flags forwardReverse and lowerUpper
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
		
		timSortLow!comp(arr);
		
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
    timSortLow(arr);
}