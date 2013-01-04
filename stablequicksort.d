/++
	Stable Quick Sort for Random-Access Ranges
	
	Written and tested for DMD 2.059 and Phobos
	
	Authors:  Xinok
	License:  Public Domain
++/

module stablequicksort;
import std.range, std.algorithm, std.functional, std.math;

/++
	Performs a stable quick sort on a random-access range according to predicate less.
	The algorithm is a 3-way stable quick sort with O(log n log n) space complexity.
	The pivot is chosen from a median of five.
	
	Returns: Sorted input as SortedRange
	
	Params:
	inPlace  = Set to true to perform an in-place sort using minimal additional space
	
	Examples:
	-----------------
	int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
	stableQuickSort(array);
	stableQuickSort!"a > b"(array); // Sorts array descending
	stableQuickSort!("a < b", true)(array); // Sorts array in-place
	-----------------
++/

@trusted SortedRange!(R, less) stableQuickSort(alias less = "a < b", bool inPlace = false, R)(R range, ElementType!(R)[] temp = null)
{
	static assert(isRandomAccessRange!R);
	static assert(hasLength!R);
	static assert(hasSlicing!R);
	static assert(hasAssignableElements!R);
	
	StableQuickSortImpl!(less, inPlace, R).sort(range, temp);

	if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
	return assumeSorted!(less, R)(range.save);
}

/// Stable Quick Sort Implementation
template StableQuickSortImpl(alias pred, bool inPlace, R)
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
	
	/// Entry sort function
	void sort(R range, T[] temp)
	{
		if(range.length <= MAX_INSERT)
		{
			binaryInsertionSort(range);
			return;
		}
		
		if(temp.length < range.length) temp.length = range.length;
		
		static if(!inPlace)
		{
			if(__ctfe) temp = new T[1024 / T.sizeof];
			else
			{
				// Cannot use log2 at compile time
				immutable len = cast(size_t)(log2(range.length) * log2(range.length));
				temp = new T[len];
			}
		}
		
		split(range, temp);
	}
	
	/// Recursively split range until list is sorted
	void split(R range, T[] temp)
	{
		while(true)
		{
			if(range.length <= MAX_INSERT)
			{
				binaryInsertionSort(range);
				return;
			}
			
			auto parts = partition3(range, temp, getPivot(range), range.length);
			auto lef = range[0 .. parts[0]];
			auto rig = range[parts[1] .. range.length];
			
			// Recurse into smaller half, tail call on larger half
			if(lef.length <= rig.length)
			{
				split(lef, temp);
				range = rig;
			}
			else
			{
				split(rig, temp);
				range = lef;
			}
		}
	}
	
	/// Get pivot as median of five elements
	T getPivot(R range)
	{
		return medianOfFive(
			range[0],
			range[range.length / 4],
			range[range.length / 2],
			range[range.length / 2 + range.length / 4],
			range[range.length - 1]
		);
	}
	
	/// Return median of five arguments in six comparisons
	/// Web: $(LINK http://stackoverflow.com/a/2117018)
	T medianOfFive(T a, T b, T c, T d, T e)
	{
		return less(b, a) ? less(d, c) ? less(b, d) ? less(a, e) ? less(a, d) ? less(e, d) ? e : d
			: less(c, a) ? c : a
			: less(e, d) ? less(a, d) ? a : d
			: less(c, e) ? c : e
			: less(c, e) ? less(b, c) ? less(a, c) ? a : c
			: less(e, b) ? e : b
			: less(b, e) ? less(a, e) ? a : e
			: less(c, b) ? c : b
			: less(b, c) ? less(a, e) ? less(a, c) ? less(e, c) ? e : c
			: less(d, a) ? d : a
			: less(e, c) ? less(a, c) ? a : c
			: less(d, e) ? d : e
			: less(d, e) ? less(b, d) ? less(a, d) ? a : d
			: less(e, b) ? e : b
			: less(b, e) ? less(a, e) ? a : e
			: less(d, b) ? d : b
			: less(d, c) ? less(a, d) ? less(b, e) ? less(b, d) ? less(e, d) ? e : d
			: less(c, b) ? c : b
			: less(e, d) ? less(b, d) ? b : d
			: less(c, e) ? c : e
			: less(c, e) ? less(a, c) ? less(b, c) ? b : c
			: less(e, a) ? e : a
			: less(a, e) ? less(b, e) ? b : e
			: less(c, a) ? c : a
			: less(a, c) ? less(b, e) ? less(b, c) ? less(e, c) ? e : c
			: less(d, b) ? d : b
			: less(e, c) ? less(b, c) ? b : c
			: less(d, e) ? d : e
			: less(d, e) ? less(a, d) ? less(b, d) ? b : d
			: less(e, a) ? e : a
			: less(a, e) ? less(b, e) ? b : e
			: less(d, a) ? d : a;
	}
	
	/// Partition range into three parts by pivot
	size_t[3] partition3(R range, T[] temp, T pivot, size_t minLength)
	{
		// Simple optimization
		if(minLength >= range.length / 2) minLength = range.length;
		
		size_t i, p1, p2, p3;
		
		static if(!inPlace)
		{
			p2 = temp.length;
			
			while(true)
			{
				if(less(range[i], pivot))
				{
					range[p1] = range[i];
					++p1;
				}
				else if(greater(range[i], pivot))
				{
					temp[p3] = range[i];
					++p3;
					if(p3 >= p2) break;
				}
				else // equal to pivot
				{
					--p2;
					temp[p2] = range[i];
					if(p2 <= p3) break;
				}
				
				if(++i >= range.length) break;
				
				// Repeat, but with less/greater swapped
				if(greater(range[i], pivot))
				{
					temp[p3] = range[i];
					++p3;
					if(p3 >= p2) break;
				}
				else if(less(range[i], pivot))
				{
					range[p1] = range[i];
					++p1;
				}
				else // equal to pivot
				{
					--p2;
					temp[p2] = range[i];
					if(p2 <= p3) break;
				}
				
				if(++i >= range.length) break;
			}
			
			i = p1;
			
			// Copy back elements equal to pivot
			foreach_reverse(k; p2 .. temp.length)
			{
				range[i] = temp[k];
				++i;
			}
			
			// Copy back elements greater than pivot
			foreach(k; 0 .. p3)
			{
				range[i] = temp[k];
				++i;
			}
			
			p2 = p1 + (temp.length - p2);
			p3 += p2;
		}
		
		static if(inPlace)
		{
			T o;
			
			while(p3 - p1 < MAX_INSERT)
			{
				if(less(range[p3], pivot))
				{
					o = range[p3];
					for(i = p3; i > p1; --i) range[i] = range[i - 1];
					range[i] = o;
					++p1; ++p2;
				}
				else if(greater(range[p3], pivot)){ }
				else // Equal to pivot
				{
					o = range[p3];
					for(i = p3; i > p2; --i) range[i] = range[i - 1];
					range[i] = o;
					++p2;
				}
				
				if(++p3 >= range.length) break;
				
				if(greater(range[p3], pivot)){ }
				else if(less(range[p3], pivot))
				{
					o = range[p3];
					for(i = p3; i > p1; --i) range[i] = range[i - 1];
					range[i] = o;
					++p1; ++p2;
				}
				else // Equal to pivot
				{
					o = range[p3];
					for(i = p3; i > p2; --i) range[i] = range[i - 1];
					range[i] = o;
					++p2;
				}
				
				if(++p3 >= range.length) break;
			}
		}
		
		// Rotate elements
		while(p3 < minLength)
		{
			auto parts = partition3(range[p3 .. range.length], temp, pivot, p3);
			size_t p4 = parts[0] + p3, p5 = parts[1] + p3, p6 = parts[2] + p3;
			
			rotate(range[p2 .. p4], p3 - p2, temp);
			p3 = p4 - (p3 - p2);
			rotate(range[p1 .. p3], p2 - p1, temp);
			rotate(range[p3 .. p5], p4 - p3, temp);
			p2 = p3 - (p2 - p1);
			p4 = p5 - (p4 - p3);
			
			p1 = p2;
			p2 = p4;
			p3 = p6;
		}
		
		return [p1, p2, p3];
	}
	
	/// Rotate elements on 'mid' axis
	void rotate(R range, size_t mid, T[] temp)
	in
	{
		assert(mid <= range.length);
	}
	body
	{
		T o;
		while(true)
		{
			immutable nu = range.length - mid;
			
			if(mid <= range.length / 2)
			{
				if(mid == 0) return;
				else static if(!inPlace) if(mid <= temp.length)
				{
					foreach(i; 0 .. mid) temp[i] = range[i];
					foreach(i; 0 .. nu) range[i] = range[i + mid];
					foreach(i; 0 .. mid) range[nu + i] = temp[i];
					return;
				}
				
				foreach(i; 0 .. mid) swap(range[i], range[i + mid]);
				range = range[mid .. range.length];
			}
			else
			{
				if(mid == range.length) return;
				else static if(!inPlace) if(range.length - mid <= temp.length)
				{
					foreach(i; mid .. range.length) temp[i - mid] = range[i];
					foreach_reverse(i; nu .. range.length) range[i] = range[i - nu];
					foreach(i; 0 .. nu) range[i] = temp[i];
					return;
				}
				
				foreach(i; mid - nu .. mid) swap(range[i], range[i + nu]);
				range = range[0 .. mid];
				mid = mid - nu;
			}
		}
	}
	
	/// Binary insertion sort is used for sorting small sublists
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
			for(upper = i; upper > lower; --upper) range[upper] = range[upper - 1];
			range[upper] = o;
		}
	}
}

unittest
{
	bool testSort(alias pred, bool inPlace = false, R)(R range)
	{
		stableQuickSort!(pred, inPlace, R)(range);
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
		static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: stableQuickSort CTFE unittest failed ", result, " of 4 tests");
	}
	
	// Stability test
	bool icmp(ubyte a, ubyte b)
	{
		if(a >= 'a') a -= 'a' - 'A';
		if(b >= 'a') b -= 'a' - 'A';
		return a < b;
	}
	ubyte[] str = cast(ubyte[])"ksugnqtoyedwpvbmifaclrhjzxWELPGDVJIHBAMZCFUNORKSTYXQ".dup;
	stableQuickSort!icmp(str);
	assert(str == "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ");
}