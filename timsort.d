/++
	Tim Sort for Random-Access Ranges
	
	Written and tested for DMD 2.059 and Phobos
	
	Authors:  Xinok
	License:  Public Domain
	
	Bugs: CTFE fails under DMD
++/

module timsort;
import std.range, std.algorithm, std.functional, std.array, std.typetuple;

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
	bool greater(T a, T b){ return less(b, a); }
	bool greaterEqual(T a, T b){ return !less(a, b); }
	bool lessEqual(T a, T b){ return !less(b, a); }

	enum MIN_MERGE   = 32;
	enum MIN_GALLOP  = 7;
	enum MIN_STORAGE = 256;
	
	struct Slice{ size_t base, length; }
	
	/// Entry point for tim sort
	void sort(R range, T[] temp)
	{
		// Do insertion sort on small range
		if(range.length <= MIN_MERGE)
		{
			binaryInsertionSort(range);
			return;
		}
		
		immutable minRun    = minRunLength(range.length);
		immutable minTemp   = range.length / 2 < MIN_STORAGE ? range.length / 2 : MIN_STORAGE;
		size_t    minGallop = MIN_GALLOP;
		Slice[40] stack     = void;
		size_t    stackLen  = 0;
		
		// Allocate temporary memory if not provided by user
		if(temp.length < minTemp)
		{
			if(__ctfe) temp.length = minTemp;
			else temp = uninitializedArray!(T[])(minTemp);
		}
		
		for(size_t i = 0; i < range.length; )
		{
			// Find length of first run in list
			size_t runLen = firstRun(range[i .. range.length]);
			
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
			
			// Collapse stack so that (e1 >= e2 + e3 && e2 >= e3)
			while(stackLen > 1)
			{
				if(stackLen >= 3 && stack[stackLen - 3].length <= stack[stackLen - 2].length + stack[stackLen - 1].length)
				{
					if(stack[stackLen - 3].length <= stack[stackLen - 1].length)
					{
						mergeAt(range, stack[0 .. stackLen], stackLen - 3, minGallop, temp);
						--stackLen;
					}
					else
					{
						mergeAt(range, stack[0 .. stackLen], stackLen - 2, minGallop, temp);
						--stackLen;
					}
				}
				else if(stack[stackLen - 2].length <= stack[stackLen - 1].length)
				{
					mergeAt(range, stack[0 .. stackLen], stackLen - 2, minGallop, temp);
					--stackLen;
				}
				else break;
			}
		}
		
		// Force collapse stack until there is only one run left
		while(stackLen > 1)
		{
			if(stackLen >= 3 && stack[stackLen - 3].length <= stack[stackLen - 1].length)
			{
				mergeAt(range, stack[0 .. stackLen], stackLen - 3, minGallop, temp);
				--stackLen;
			}
			else
			{
				mergeAt(range, stack[0 .. stackLen], stackLen - 2, minGallop, temp);
				--stackLen;
			}
		}
	}
	
	/// Calculates optimal value for minRun
	pure size_t minRunLength(size_t n)
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
		assert(at == stack.length - 2 || at == stack.length - 3);
	}
	body
	{
		// Just some values ...
		immutable base = stack[at].base;
		immutable mid  = stack[at].length;
		immutable len  = stack[at + 1].length + mid;
		
		// Pop run from stack
		stack[at] = Slice(base, len);
		if(at == stack.length - 3) stack[$ - 2] = stack[$ - 1];
		
		// Merge runs (at, at + 1)
		return merge(range[base .. base + len], mid, minGallop, temp);
	}
	
	/// Merge two runs in a range. Mid is the starting index of the second run.
	/// minGallop and temp are references; The calling function must receive the updated values.
	void merge(R range, size_t mid, ref size_t minGallop, ref T[] temp)
	in
	{
		if(!__ctfe)
		{
			assert(isSorted!pred(range[0 .. mid]));
			assert(isSorted!pred(range[mid .. range.length]));
		}
	}
	body
	{
		assert(mid < range.length);
		
		// Reduce range of elements
		immutable firstElement = gallopForwardUpper(range[0 .. mid], range[mid]);
		immutable lastElement  = gallopReverseLower(range[mid .. range.length], range[mid - 1]) + mid;
		range = range[firstElement .. lastElement];
		mid -= firstElement;
		
		// Important! Trust me!
		if(mid == 0 || mid == range.length) return;
		
		// Call function which will copy smaller run into temporary memory
		if(mid <= range.length / 2)
		{
			temp = ensureCapacity(range.length, mid, temp);
			minGallop = mergeLo(range, mid, minGallop, temp);
		}
		else
		{
			temp = ensureCapacity(range.length, range.length - mid, temp);
			minGallop = mergeHi(range, mid, minGallop, temp);
		}
	}
	
	/// Enlarge size of temporary memory if needed
	T[] ensureCapacity(size_t rangeLen, size_t minCapacity, T[] temp)
	out(ret)
	{
		assert(ret.length >= minCapacity);
	}
	body
	{
		if(temp.length < minCapacity)
		{
			size_t newSize = minCapacity;
			foreach(n; TypeTuple!(1, 2, 4, 8, 16)) newSize |= newSize >> n;
			++newSize;

			if(newSize < minCapacity) newSize = minCapacity;
			else newSize = min(newSize, rangeLen / 2);
			
			if(__ctfe) temp.length = newSize;
			else temp = uninitializedArray!(T[])(newSize);
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
	
	/// false = forward / lower, true = reverse / upper
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
	
	alias gallopSearch!(false, false) gallopForwardLower;
	alias gallopSearch!(false, true)  gallopForwardUpper;
	alias gallopSearch!(true, false)  gallopReverseLower;
	alias gallopSearch!(true, true)   gallopReverseUpper;
	
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
	bool testSort(alias pred, R)(R range)
	{
		timSort!(pred, R)(range);
		return isSorted!pred(range);
	}
	
	int testCall(T)(in T[] arr)
	{
		int failures = 0;
		
		// Sort
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
	//@ Disabled; Fails to compile under DMD
	version(none)
	{
		enum result = testCall(test);
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: timSort CTFE unittest failed ", result, " of 2 tests");
	}
	
	// Stability test
	bool icmp(ubyte a, ubyte b)
	{
		if(a >= 'a') a -= 'a' - 'A';
		if(b >= 'a') b -= 'a' - 'A';
		return a < b;
	}
	ubyte[] str = cast(ubyte[])"ksugnqtoyedwpvbmifaclrhjzxWELPGDVJIHBAMZCFUNORKSTYXQ".dup;
	timSort!icmp(str);
	assert(str == "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ");
}