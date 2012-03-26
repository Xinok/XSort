Phobos is the standard library for the D programming language. The stable sort in Phobos is slow, broken, and not even stable. The unstable sort works great overall but has a few bad cases where it performs poorly ([bug 7767](http://d.puremagic.com/issues/show_bug.cgi?id=7767)). I wrote these modules as substitutes (and possibly replacements) for the sort function in Phobos.

----------

stablesort.d
============
A natural merge sort using O(log n log n) additional space. Up to 1KiB may be allocated on the stack, and anything larger will be allocated on the heap.

A natural merge sort scans the list from left to right, looking for "runs" in ascending or descending order and merging them. A 'run' is a sublist of elements that is already sorted. If elements are in descending order, it will reverse them.

If a run is too small, a binary insertion sort is used to build the run up to MIN_RUN length (32 elements long).

When merging, the smaller of the two halves is copied into temporary memory and then merged in place. It may need to merge from front to back, or back to front, depending on which half is smaller.

Rotations are used to reduce two runs into four smaller runs. It's difficult to explain how or why this works. This is done recursively until the runs are small enough to fit into the additional space.

An optional template argument, inPlace, when set to true, utilizes no additional space at the cost of performance. In-place merging is done using insertions rather than temporary memory.


----------

unstablesort.d
==============
A custom quick sort / intro sort implementation with an acceptable worst-case. A tail call is used to avoid stack overflow.

Quick sort uses a median of three to choose the pivot. The partitioning method used works well when many elements are equal to the pivot.

Binary insertion sort is used to sort small sublists.

After too many recursions, shell sort is used to avoid the worst-case of quick sort. It uses the best known gap sequence. Shell sort has an acceptable worst-case, and I chose it over heap sort because I've found that it generally performs faster and requires fewer comparisons.

----------

forwardsort.d
=============
> **WARNING:** This sort may have a worst case of O(n^2). While it's unlikely to happen in normal usage, it's potentially exploitable in a DoS attack. Do not use this module when security is vital.

A custom quick sort implementation especially for sorting forward ranges in place. It uses what I like to call the "caterpillar tracks" method for partitioning, which works well with forward ranges. A tail call is used to avoid stack overflow.

Rather than walk the range, the first element is used as the pivot. This is a poor design choice, so I hope to come up with a better solution in the future.

Binary insertion sort is used to sort small sublists. Up to 32 elements are copied into a temporary array on the stack, sorted, and copied back.

After too many recursions, comb sort is used to avoid the worst-case of quick sort. Comb sort works well with forward ranges, and although it still has a worst-case of O(n^2), it's far less likely to happen in common usage.