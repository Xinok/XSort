# XSort #

XSort is a collection of sorting algorithms and related profiling tools implemented in the [D programming language](http://dlang.org/). All source code is available in the [public domain](https://en.wikipedia.org/wiki/Public_domain).

> This document is a draft and reflects pending changes to this repository. Some details may be inaccurate and there may be references to modules not yet available.

## Algorithms ##

All modules are provided with documentation and unittests. Any single module may be used independently without any other modules installed.

- Bubble Sort - Implemented to work with forward ranges
- Comb Sort - Standard implementation or final pass with linear/gallop insertion sort
- Forward Sort - In-place sort for forward ranges utilizing a combination of quick sort + comb sort
- Heap Sort - Six variants: binary or ternary tree; sift-down, sift-up, or bottom-up traversal
- In-Place Merge Sort - O(lg^2 n) time complexity
- Insertion Sort - Utilizing linear, binary, gallop, or trot search
- Merge Sort - O(n) or O(n/2) space complexity
- Selection Sort - Implemented to work with forward ranges
- Shell Sort - Provides concurrent implementation
- Stable Quick Sort (3-way stable quick sort with O(lg n) or O(lg^2 n) space complexity)
- Stable Sort - Natural merge sort with O(lg^2 n) space complexity
- Timsort - Standard implementation without any special tricks
- Timsortlow - Variant of Timsort with O(n/1024) space complexity
- Unstable Sort ([introsort](https://en.wikipedia.org/wiki/Introsort)) - Pivot chosen from median of five and bottom-up heap sort used as a fallback algorithm

## Third Party Implementations ##

Here are a few other sorting algorithms implemented by others for the D programming language:

- [Radix Sort](https://github.com/nordlow/justd/blob/master/intsort.d#L92intsort.d) by Per Nordlöw - Supports integral and floating-point element types
- [Smooth Sort](https://github.com/deadalnix/Dsort/blob/master/sort/smooth.d) by deadalnix - A natural variant of heap sort using Leonardo heaps
- [Tree Sort](http://dlang.org/phobos/std_container_rbtree.html) - An implementation of a red-black tree is available in the Phobos standard library

## Compiling ##

To compile the profiling tools, assuming you have [Git](http://git-scm.com/) and [DMD](http://dlang.org/download.html) installed, simply run these commands from a path of your choice:

	git clone https://github.com/Xinok/XSort
	cd XSort
	dmd @release.args

## Profiler ##

The current profiler is implemented in `benchsort.d` and is preliminary. I intend to replace it with a more powerful tool which can be executed with various command line parameters. These are some of the features I plan on implementing in the new profiler:

- Customize data type, length, and ordering / shuffling
- Take average of multiple runs / data sets
- Measure I/O (reads + writes)
- Cache simulator (hits + misses)
- Choose number of threads for concurrent benchmarks

## Notes ##

Most of the algorithms available here are [comparison-based sorting algorithms](https://en.wikipedia.org/wiki/Comparison_sort). Other algorithms such as [radix sort](https://en.wikipedia.org/wiki/Radix_sort) or [bucket sort](https://en.wikipedia.org/wiki/Bucket_sort) are not comparison sorts.

The documentation provided here and in the source code makes use of some notions and terminology which are common to sorting algorithms or algorithms in general. I'll list a few of them here:

- [Big O notation](https://en.wikipedia.org/wiki/Big_O_notation) - A useful notation which describes how well algorithms scale as the input grows larger.
- [Stable](https://en.wikipedia.org/wiki/Sorting_algorithm#Stability) - A stable sorting algorithm will retain the original ordering of equal elements. For example, suppose you have a list of names that you want to sort by first name only, ignoring the last name. If the list is sufficiently large, some people are bound to have the same first name but different last names. A stable sorting algorithm will keep the original order of the last names for people who have the same first name. An *unstable* sorting algorithm generally will not.
- [Adaptive](https://en.wikipedia.org/wiki/Adaptive_sort) - An adaptive (or natural) sorting algorithm generally performs faster on data which is already partially sorted. These algorithms may utilize multiple techniques to better exploit patterns in the data.
- [In-Place](https://en.wikipedia.org/wiki/In-place_algorithm) - I use this term to classify an algorithm which is implemented without any sort of buffer or allocated memory. 
- [Ranges](http://dlang.org/phobos/std_range.html) - The Phobos standard library has the concept of ranges which are similar to C++ iterators. All of the modules in this repository make use of ranges. You can read more about them [here](http://ddili.org/ders/d.en/ranges.html).

## Plans ##

- [Smoothsort](https://en.wikipedia.org/wiki/Smoothsort) - An adaptive variant of heap sort
- [Tree sort](https://en.wikipedia.org/wiki/Tree_sort) - A sorting algorithm utilizing a binary tree
- [Block sort](https://en.wikipedia.org/wiki/Block_sort) - An in-place stable sort which runs in O(n lg n) time
- [Trie sorting algorithm](https://en.wikipedia.org/wiki/Trie#Sorting) for strings (e.g. [Burstsort](https://en.wikipedia.org/wiki/Burstsort))
- Write independent modules for some useful functions such as a stable `partition3`.

## References ##

- [Smoothsort Demystified](http://www.keithschwarz.com/smoothsort/) by Keith Schwarz. 
- [Timsort for Android](http://cr.openjdk.java.net/~martin/webrevs/openjdk7/timsort/raw_files/new/src/share/classes/java/util/TimSort.java) by Google