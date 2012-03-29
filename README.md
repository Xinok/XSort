Phobos is the standard library for the D programming language. The stable sort in Phobos is slow, broken, and not even stable. The unstable sort works great overall but has a few bad cases where it performs poorly ([bug 7767](http://d.puremagic.com/issues/show_bug.cgi?id=7767)). I wrote these modules as substitutes (and possibly replacements) for the sort function in Phobos.

----------

# stablesort.d #
A natural merge sort with O(log n log n) space complexity. Up to 1KiB may be allocated on the stack, and anything larger will be allocated on the heap. Best case performance is O(n), worst case performance is **approximately** O(n log n).

A natural merge sort scans the list from left to right, looking for "runs" in ascending or descending order and merging them. A 'run' is a sublist of elements that is already sorted. If elements are in descending order, it will reverse them.

If a run is too small, a binary insertion sort is used to build the run up to MIN_RUN length (32 elements long).

When merging, one of the two halves is copied into temporary memory and then merged in place. It may need to merge from front to back, or back to front, depending on which half was copied into temporary memory.

Rotations are used to reduce two runs into four smaller runs. It's difficult to explain how or why this works. This is done recursively until the runs are small enough to fit into the additional space.

An optional template argument, inPlace, when set to true, utilizes no additional space at the cost of performance. In-place merging is done using insertions rather than temporary memory.


----------

# unstablesort.d #
A custom quick sort / intro sort implementation. Best case performance is O(n log n), worst case performance is **approximately** O(n log n).

Quick sort uses a median of three to choose the pivot. The partitioning method used works well when many elements are equal to the pivot.

Binary insertion sort is used to sort small sublists.

After too many recursions, shell sort is used to avoid the worst-case of quick sort. It uses the best known gap sequence. Shell sort has acceptable worst case performance, and I chose it over heap sort because I've found that it generally performs faster and does fewer comparisons.

----------

# forwardsort.d #
> **WARNING:** This sort has a worst case performance of O(n^2). While it's unlikely to happen in normal usage, it's potentially exploitable in a DoS attack. Do not use this module when security is vital.

A custom quick sort implementation especially for sorting forward ranges in-place. It uses what I like to call the "caterpillar tracks" method for partitioning, which works well with forward ranges. A tail call is used to avoid stack overflow. Best case performance is O(n log n), worst case performance is O(n^2).

Rather than walk the range, the first element is used as the pivot. This is a poor design choice, so I hope to come up with a better solution in the future.

Binary insertion sort is used to sort small sublists. Up to 32 elements are copied into a temporary array on the stack, sorted, and copied back.

After too many recursions, comb sort is used to avoid the worst-case of quick sort. Comb sort works well with forward ranges, and although it still has a worst-case of O(n^2), it's far less likely to happen in common usage.


----------

# insertionsort.d #
> **WARNING:** This sort has an averange and worst case performance of O(n^2). Insertion sort is only practical for sorting small sublists. It may take a long time to sort large sublists. It's useful for optimizing other sorting algorithms, but is impractical as a standalone algorithm.

An insertion sort with four different search modes: linear search, binary search, gallop search, and trot search. Best case performance is O(n), average and worst case performance is O(n^2).

* A linear search is used by default which is standard for insertion sort.
* **Recommended**, a binary search does the fewest comparisons on lists with high entropy.
* A gallop search does fewer comparisons if the list is partially sorted.
* A trot search is only useful for lists which are mostly sorted.