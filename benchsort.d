module benchsort;
import std.stdio, std.random, std.datetime, std.array, std.range, std.algorithm;
import combsort, forwardsort, heapsort, insertionsort, mergesort, shellsort, stablesort, timsort, unstablesort;

void benchSort(string name, lazy void call)
{
	StopWatch sw;
	
	sw.start();
	call();
	sw.stop();
	
	writeln(name, std.array.replicate(" ", 40 - name.length), sw.peek.msecs, "ms");
}

void main()
{
	// Initialize test array
	uint[] base;
	base.length = 1024 * 1024;
	foreach(i, ref v; base) v = i;
	randomShuffle(base);
	
	// Initialize copy array
	uint[] copy;
	copy.length = base.length;
	
	// Print information
	writeln(__VENDOR__, " ", __VERSION__);
	writeln(typeid(base).toString, " * ", base.length);
	writeln();
	
	
	// ------------
	//  Benchmarks
	// ------------
	
	copy[] = base[];
	benchSort("Comb Sort Standard", combSort(copy));
	
	copy[] = base[];
	benchSort("Comb Sort Linear", combSortLinear(copy));
	
	copy[] = base[];
	benchSort("Comb Sort Gallop", combSortGallop(copy));
	
	copy[] = base[];
	benchSort("Forward Sort", forwardSort(copy, false));
	
	copy[] = base[];
	benchSort("Forward Sort (Concurrent)", forwardSort(copy, true));
	
	copy[] = base[];
	benchSort("Heap Sort Standard Binary  Sift-Down", heapSort!("a < b", false)(copy, false));
	
	copy[] = base[];
	benchSort("Heap Sort Standard Binary  Sift-Up", heapSort!("a < b", false)(copy, true));
	
	copy[] = base[];
	benchSort("Heap Sort Standard Ternary Sift-Down", heapSort!("a < b", true)(copy, false));
	
	copy[] = base[];
	benchSort("Heap Sort Standard Ternary Sift-Up", heapSort!("a < b", true)(copy, true));
	
	copy[] = base[];
	benchSort("Heap Sort Bottom-Up Binary", bottomUpHeapSort!("a < b", false)(copy));
	
	copy[] = base[];
	benchSort("Heap Sort Bottom-Up Ternary", bottomUpHeapSort!("a < b", true)(copy));
	
	copy[] = base[];
	benchSort("Heap Sort by Haider", haiderHeapSort(copy));
	
	if(base.length <= 1024 * 64)
	{
		copy[] = base[];
		benchSort("Insertion Sort Linear", insertionSort(copy));
		
		copy[] = base[];
		benchSort("Insertion Sort Binary", insertionSort!("a < b", SearchPolicy.binarySearch)(copy));
		
		copy[] = base[];
		benchSort("Insertion Sort Gallop", insertionSort!("a < b", SearchPolicy.gallop)(copy));
		
		copy[] = base[];
		benchSort("Insertion Sort Trot", insertionSort!("a < b", SearchPolicy.trot)(copy));
	}
	
	copy[] = base[];
	benchSort("Merge Sort O(n)", mergeSort!("a < b", false)(copy, false));
	
	copy[] = base[];
	benchSort("Merge Sort O(n)   (Concurrent)", mergeSort!("a < b", false)(copy, true));
	
	copy[] = base[];
	benchSort("Merge Sort O(n/2)", mergeSort!("a < b", true)(copy, false));
	
	copy[] = base[];
	benchSort("Merge Sort O(n/2) (Concurrent)", mergeSort!("a < b", true)(copy, true));
	
	copy[] = base[];
	benchSort("Shell Sort", shellSort(copy));
	
	copy[] = base[];
	benchSort("Stable Sort", stableSort!("a < b", false)(copy, false));
	
	copy[] = base[];
	benchSort("Stable Sort          (Concurrent)", stableSort!("a < b", false)(copy, true));
	
	copy[] = base[];
	benchSort("Stable Sort In-Place", stableSort!("a < b", true)(copy, false));
	
	copy[] = base[];
	benchSort("Stable Sort In-Place (Concurrent)", stableSort!("a < b", true)(copy, true));
	
	copy[] = base[];
	benchSort("Tim Sort", timSort(copy));
	
	copy[] = base[];
	benchSort("Unstable Sort", unstableSort(copy, false));
	
	copy[] = base[];
	benchSort("Unstable Sort (Concurrent)", unstableSort(copy, true));
	
	copy[] = base[];
	benchSort("Phobos Sort Unstable", sort(copy));
	
	copy[] = base[];
	benchSort("Phobos Sort Stable", sort!("a < b", SwapStrategy.stable)(copy));
}