module benchsort;
import std.stdio, std.random, std.datetime, std.string, std.range, std.algorithm, std.md5;
import combsort, forwardsort, heapsort, insertionsort, mergesort, shellsort, stablequicksort, stablesort, timsort, unstablesort;

void main()
{
	// Initialize test array
	static uint[] base;
	base.length = 1024 * 1024;
	foreach(i, ref v; base) v = i;
	randomShuffle(base);
	
	// Initialize copy array
	static uint[] copy;
	copy.length = base.length;
	
	// Print information
	writeln(__VENDOR__, " ", __VERSION__);
	writeln(typeid(base).toString, " * ", base.length);
	writeln();
	
	// Profiling functions
	static ulong comps;
	
	static bool pred(T)(T a, T b)
	{
		++comps;
		return a < b;
	}
	
	static ulong bench(lazy void run)
	{
		copy[] = base[];
		StopWatch sw;
		sw.start();
		run();
		sw.stop();
		return sw.peek.msecs;
	}
	
	static ulong count(lazy void run)
	{
		copy[] = base[];
		comps = 0;
		run();
		return comps;
	}
	
	static void profileSort(string name, ulong bench, ulong count)
	{
		immutable blank = "                                                 ";
		
		name = (name ~ blank)[0..40];
		string time = ((bench > 0 ? format(bench, "ms") : "???") ~ blank)[0..10];
		string comps = ((count > 0 ? format(count) : "???") ~ blank)[0..12];
		string hash = getDigestString(copy)[0..8];
		
		writeln(name, time, comps, hash);
	}
	
	// ------------
	//  Benchmarks
	// ------------
	
	profileSort("Comb Sort Standard", bench(combSort(copy)), count(combSort!pred(copy)));
	profileSort("Comb Sort Linear", bench(combSortLinear(copy)), count(combSortLinear!pred(copy)));
	profileSort("Comb Sort Gallop", bench(combSortGallop(copy)), count(combSortGallop!pred(copy)));
	
	profileSort("Forward Sort", bench(forwardSort(copy, false)), count(forwardSort!pred(copy, false)));
	profileSort("Forward Sort (Concurrent)", bench(forwardSort(copy, true)), comps);
	
	profileSort("Heap Sort Standard Binary  Sift-Down", bench(heapSort!("a < b", false)(copy, false)), count(heapSort!(pred, false)(copy, false)));
	profileSort("Heap Sort Standard Binary  Sift-Up", bench(heapSort!("a < b", false)(copy, true)), count(heapSort!(pred, false)(copy, true)));
	profileSort("Heap Sort Standard Ternary Sift-Down", bench(heapSort!("a < b", true)(copy, false)), count(heapSort!(pred, true)(copy, false)));
	profileSort("Heap Sort Standard Ternary Sift-Up", bench(heapSort!("a < b", true)(copy, true)), count(heapSort!(pred, true)(copy, true)));
	profileSort("Heap Sort Bottom-Up Binary", bench(bottomUpHeapSort!("a < b", false)(copy)), count(bottomUpHeapSort!(pred, false)(copy)));
	profileSort("Heap Sort Bottom-Up Ternary", bench(bottomUpHeapSort!("a < b", true)(copy)), count(bottomUpHeapSort!(pred, true)(copy)));
	
	if(base.length <= 1024 * 64)
	{
		profileSort("Insertion Sort Linear", bench(insertionSort(copy)), count(insertionSort!pred(copy)));
		profileSort("Insertion Sort Binary", bench(insertionSort!("a < b", SearchPolicy.binarySearch)(copy)), count(insertionSort!(pred, SearchPolicy.binarySearch)(copy)));
		profileSort("Insertion Sort Gallop", bench(insertionSort!("a < b", SearchPolicy.gallop)(copy)), count(insertionSort!(pred, SearchPolicy.gallop)(copy)));
		profileSort("Insertion Sort Trot", bench(insertionSort!("a < b", SearchPolicy.trot)(copy)), count(insertionSort!(pred, SearchPolicy.trot)(copy)));
	}
	
	profileSort("Merge Sort O(n)", bench(mergeSort!("a < b", false)(copy, false)), count(mergeSort!(pred, false)(copy, false)));
	profileSort("Merge Sort O(n)   (Concurrent)", bench(mergeSort!("a < b", false)(copy, true)), comps);
	profileSort("Merge Sort O(n/2)", bench(mergeSort!("a < b", true)(copy, false)), comps);
	profileSort("Merge Sort O(n/2) (Concurrent)", bench(mergeSort!("a < b", true)(copy, true)), comps);
	
	profileSort("Shell Sort", bench(shellSort(copy)), count(shellSort!pred(copy)));
	
	profileSort("Stable Quick Sort", bench(stableQuickSort!("a < b", false)(copy)), count(stableQuickSort!(pred, false)(copy)));
	profileSort("Stable Quick Sort In-Place", bench(stableQuickSort!("a < b", true)(copy)), count(stableQuickSort!(pred, true)(copy)));
	
	profileSort("Stable Sort", bench(stableSort!("a < b", false)(copy, false)), count(stableSort!(pred, false)(copy, false)));
	profileSort("Stable Sort          (Concurrent)", bench(stableSort!("a < b", false)(copy, true)), 0);
	profileSort("Stable Sort In-Place", bench(stableSort!("a < b", true)(copy, false)), count(stableSort!(pred, true)(copy, false)));
	profileSort("Stable Sort In-Place (Concurrent)", bench(stableSort!("a < b", true)(copy, true)), 0);
	
	profileSort("Tim Sort", bench(timSort(copy)), count(timSort!pred(copy)));
	
	profileSort("Unstable Sort", bench(unstableSort(copy, false)), count(unstableSort!pred(copy, false)));
	profileSort("Unstable Sort (Concurrent)", bench(unstableSort(copy, true)), comps);
	
	profileSort("Phobos Sort Unstable", bench(sort(copy)), count(sort!pred(copy)));
	profileSort("Phobos Sort Stable (Broken)", bench(sort!("a < b", SwapStrategy.stable)(copy)), count(sort!(pred, SwapStrategy.stable)(copy)));
}