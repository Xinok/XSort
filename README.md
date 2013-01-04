A collection of sorting algorithms for the [D programming language](http://dlang.org/). Some were implemented with a specific purpose in mind *(stable / unstable / forward sorting)*, while others are generic implementations provided for general use or reference. All modules contain documentation, unittests, and can be used independently of one another.

The Timsort module has been incorporated as the stable sorting algorithm for Phobos, the standard library for the D programming language. The Phobos implementation is revised and should be considered independent of the module located in this repository.

----------

# stablesort.d #
A stable sort for sorting random-access ranges using little to no additional memory while retaining performance.

Stable sorting preserves the original order of equal elements. This is often necessary when sorting a list with multiple fields, where sorting one field changes the order of elements in other fields (e.g. table / spreadsheet).

**Features**

* Concurrently sort range in multiple threads
* Provide your own temporary memory (useful to avoid multiple allocations)
* Sort in-place without using any additional space (but at the cost of performance)

**Attributes**

* Stable, Natural
* O(n) best case
* O(n log n) average case
* O(n log n) *approximate* worst case
* O(log n log n) auxiliary space complexity
* O(log n) auxiliary space complexity (in-place)

**Implementation**

The algorithm is a natural merge sort with reduced space complexity. A natural merge sort performs best on lists with low entropy.

For additional space, up to 1KiB may be allocated on the stack (using alloca()), and anything larger will be allocated on the heap. When sorting in-place, no additional space is allocated.

It begins by scanning the list from left to right, looking for "runs" in ascending or descending order and merging them. A 'run' is a sublist of elements that is already sorted. If the elements are in descending order, it will reverse them.

If a run is too small, a binary insertion sort is used to build the run up to MIN_RUN length (32 elements long).

When merging, one of the two halves is copied into temporary memory and then merged in place. It may need to merge from front to back, or back to front, depending on which half was copied into temporary memory.

Rotations are used to reduce two runs into four smaller runs. It's difficult to explain how or why this works. This is done recursively until the runs are small enough to fit into the additional space.

An optional template argument, inPlace, when set to true, utilizes no *additional space* at the cost of performance. In-place merging is done using insertions rather than temporary memory.

**Concurrent sorting** is done by slicing the range into multiple parts of equal length for each thread, then merging these parts at the end. This doesn't take advantage of natural sorting, but is much faster on random data.


----------

# unstablesort.d #
An unstable sort for quickly sorting random-access ranges in O(n log n) time.

Unstable sorting doesn't preserve the original order of equal elements but is often faster than stable sorting.

**Features**

* Concurrently sort range in multiple threads

**Attributes**

* Unstable
* O(n log n) best case
* O(n log n) average case
* O(n log n) *approximate* worst case
* O(log n) auxiliary space complexity

**Implementation**

The algorithm is, in essence, an intro sort, meaning a quick sort which falls back to a heap sort after too many recursions to guarantee O(n log n) worst case performance.

The pivot for quick sort is chosen from a median of five in six comparisons. The method used satisfies the condition, a < c && b < c && c < d && c < e. This means the first five elements can be partitioned without any additional comparisons after the median is found.

The partition method for quick sort attempts to divide elements equal to the pivot into both partitions. So if many elements are equal to the pivot, the pivot should end up closer to the center, resulting in faster performance and fewer comparisons.

When a partition is small enough, binary insertion sort is used to sort small sublists of up to 32 elements. This increases performance as well as reduces the number of comparisons in an average case.

If too many recursions occur, a bottom-up binary heap sort is used to avoid the worst case of quick sort. A bottom-up heap sort does nearly half the number of comparisons as a standard heap sort and about 50% less than shell sort. On top of that, it has O(1) space complexity. This makes it the ideal "fall-back" unstable sorting algorithm.

**Concurrent sorting** is done by creating a new task for sublists greater than 64k elements in length. All of these tasks are executed in a task pool using a fixed number of threads. This method achieves greater performance, even if a few bad pivots are chosen.

----------

# forwardsort.d #
An unstable sort for sorting forward ranges in-place.

Forward ranges don't allow for random access, so efficiently sorting in-place is more difficult. 

> **WARNING:** This has a worst case performance of O(n^2). It's unlikely to occur in regular usage, but it's potentially exploitable in a DoS attack. Do not use when security is vital.

**Features**

* Concurrently sort range in multiple threads
* Works on non-Lvalue Ranges (including SList and DList)

**Attributes**

* Unstable
* O(n log n) best case
* O(n log n) average case
* O(n^2) worst case
* O(log n + 32n) auxiliary space complexity

**Implementation**

It begins with a quick sort using a partitioning method which I like to call "caterpillar tracks", which works especially well for forward ranges. Since forward ranges don't have random access, it picks the first element as the pivot. This is a poor design choice, as it invokes worst case behavior on already sorted lists, so I hope to come up with a better solution in the future.

When a partition is small enough, binary insertion sort is used to sort small sublists. Up to 32 elements are copied into a static array on the stack, sorted, and copied back. This increases performance as well as reduces the number of comparisons in an average case.

If too many recursions occur, comb sort is used to avoid the worst case of quick sort. A shrink factor of 1.2473 is used. Comb sort works well with forward ranges, and although it still has a worst-case of O(n^2), it's unlikely to happen in regular usage.

**Concurrent sorting** is done by creating a new task for sublists greater than 64k elements in length. All of these tasks are executed in a task pool using a fixed number of threads. This method achieves greater performance, even if a few bad pivots are chosen.

----------

# timsort.d #
A tim sort for random-access ranges.

Tim sort is a natural merge sort variant. It's a complex algorithm, so if you wish to know more about it, see [Wikipedia](https://en.wikipedia.org/wiki/Timsort) or the [Timsort Paper](http://svn.python.org/projects/python/trunk/Objects/listsort.txt).

**Features**

* None to speak of

**Attributes**

* Stable, Natural
* O(n) best case
* O(n log n) average case
* O(n log n) worst case
* O(n / 2) worst case auxiliary space complexity

**Implementation**

I wrote a proper implementation from scratch for D. I used [TimSort.java](http://cr.openjdk.java.net/~martin/webrevs/openjdk7/timsort/raw_files/new/src/share/classes/java/util/TimSort.java) for Android as a reference. Major differences include the use of static functions, slicing, and the way in which many components were implemented.

This module was revised and incorporated as the stable sorting algorithm in Phobos, the standard library of the D programming language. I will continue to maintain this implementation independently of Phobos.

----------

# insertionsort.d #
An insertion sort for small or nearly sorted random-access ranges.

Insertion sort is useful for optimizing other sorting algorithms. Quick sort and merge sort are divide-and-conquer algorithms, so insertion sort can be used to sort small sublists. Comb sort results in a nearly sorted list, and insertion sort using a linear or gallop search can be used in the final pass.

> **WARNING:** Insertion sort has an average and worst case performance of O(n^2). Do not use with large ranges.

**Features**

* Four search modes: Linear, Binary, Gallop, Trot

**Attributes**

* Stable, Natural (excl. binary search)
* O(n) best case
* O(n^2) average case
* O(n^2) worst case
* O(1) auxiliary space complexity

**Implementation**

An insertion sort which runs from front to back and provides four different search modes.

A linear search is used by default which is standard for insertion sort. It has the benefit of being the fastest when comparisons are inexpensive, but has a worst case of `O((n*(n-1))/2)` comparisons.

**Recommended:** A binary search does the fewest comparisons on lists with high entropy. It has the benefit of an average/worst case of O(n log n) comparisons.

A gallop search does fewer comparisons if the list is partially sorted. The search increases in powers of two [1, 2, 4, 8, 16, 32, ...]. It has the benefit of a best case of O(n) comparisons.

A trot search increases linearly [1, 3, 6, 10, 15, 21, ...]. This mode is not recommended over gallop as it performs worse in most cases.

----------

# combsort.d #
A comb sort for random-access ranges.

While other sorting algorithms may generally be more favorable, it has it's uses. I found it to be very effective at sorting forward ranges in-place. It's small code size and O(1) auxiliary space complexity may have applications in microprocessors with limited resources.

> **WARNING:** Comb sort has a worst case performance of O(n^2). It's unlikely to occur in regular usage, but it's potentially exploitable in a DoS attack. Do not use when security is vital.

**Features**

* Optional final pass of insertion sort utilizing linear or gallop search

**Attributes**

* Unstable
* O(n) best case (according to [Wikipedia](https://secure.wikimedia.org/wikipedia/en/wiki/Comb_sort))
* O(n log n) average case
* O(n^2) worst case
* O(1) auxiliary space complexity

**Implementation**

First is a standard comb sort which passes over the range multiple times until it's sorted. A standard shrink factor of 1.2473 is used. This has the worst performance, and is only provided for reference.

Second is a comb sort with a shrink factor of 1.375. It will sweep the range until the gap is 6 or less. It finishes with a final pass of insertion sort (using a standard linear search). This offers the best performance when comparisons are inexpensive.

Third is a comb sort with a shrink factor of 1.42. It will sweep the range until the gap is 32 or less. It finishes with a final pass of insertion sort utilizing a gallop search. This adds the most overhead, but does the fewest comparisons.

----------

# shellsort.d #
A shell sort for random-access ranges.

I've always favored shell sort for it's acceptable worst case performance, O(1) space complexity, ease of implementation, and small code size similar to comb sort. It makes an ideal alternative to quick sort or heap sort.

**Features**

* None to speak of

**Attributes**

* Unstable, Natural
* Unknown time complexity with given gap sequence
* O(1) auxiliary space complexity

**Implementation**

A standard shell sort implementation. The lower part of the gap sequence is the best known, [1750, 701, 301, 132, 57, 23, 10, 4, 1]. Larger gaps were calculated using the formula, `(9 ^ k - 4 ^ k) / (5 * 4 ^ (k - 1))`.

----------

# mergesort.d #
A merge sort for random-access ranges.

**Features**

* Concurrently sort range in multiple threads
* Provide your own temporary memory (useful to avoid multiple allocations)
* Sort using O(n) or O(n/2) space complexity

**Attributes**

* Stable
* O((n log n) / 2) best case
* O(n log n) average case
* O(n log n) worst case
* O(n), O(n/2) auxiliary space complexity

**Implementation**

First is a standard merge sort implementation using O(n) additional space.

Second is a merge sort using O(n/2) additional space. It accomplishes this by copying only the left half into temporary memory, and then merging both halves in place.

Binary insertion sort is used to sort small sublists of up to 32 elements. This increases performance, but doesn't necessarily reduce the number of comparisons.

**Concurrent sorting** is done by slicing the range into multiple parts of equal length for each thread, then merging these parts at the end.

----------

# heapsort.d #
A heap sort for random-access ranges

Heap sort combines in-place sorting with a **guaranteed** worst-case performance of O(n log n). Quick sort and comb sort have a worst-case performance of O(n^2), and the worst-case of shell sort is unknown (depending on gap sequence).

**Features**

* Use a binary or ternary heap
* Heapify using sift-down or sift-up method

**Attributes**

* Unstable
* O(n log n) best case
* O(n log n) average case
* O(n log n) worst case
* O(1) auxiliary space complexity

**Implementation**

First is a standard heap sort. You may choose between a binary or ternary heap; The **ternary** heap is used by default. You may also choose between the sift-down or sift-up heapify method; The **sift-down** method is used by default.

Second is a bottom-up heap sort. You may choose between a binary or ternary heap; The **binary** heap is used by default.

In a binary heap, each node has two children. In a ternary heap, each node has three children. A ternary heap tends to be faster and does fewer comparisons in a standard heap sort. A binary heap tends to do fewer comparisons in a bottom-up heap sort, though being slower when comparisons are cheap.

The sift-down heapify method walks in the direction of parent to child to child. The sift-up heapify method walks in the direction of child to parent to parent. The sift-down method tends to be faster and does fewer comparisons as it only does n/2 or n/3 passes as opposed to sift-up which does n passes.

A bottom-up heap sort sifts down the tree, pulling down each max element along the way, until there are no more children. Then it sifts up, looking for where to insert the current element. Because there are fewer elements towards the base of the tree, an element is more likely to be in place near the end of the path, which is why a bottom-up heap sort tends to do fewer comparisons. It's average case is better, but because it sifts down as far as possible, it's best case is far from that of a standard heap sort. As to why a binary heap is better than a ternary heap, I'm not sure.

Best modes to use:

- Standard Heap Sort = Ternary Heap and Sift-Down Heapify Method
- Bottom-up Heap Sort = Binary Heap

----------

# stablequicksort.d #
A stable quick sort for random-access ranges

There seems to be little use for a stable quick sort, as in nearly all cases, an equivalent merge sort will outperform it. However, there is merit in a stable partition function, which is why I chose to write this module.

> **WARNING:** This has a worst case performance of O(n^2/3). It's highly recommended to use merge sort or tim sort instead.

**Features**

* Provide your own temporary memory (useful to avoid multiple allocations)
* Sort in-place without using any additional space (but at the cost of performance)

**Attributes**

* Stable
* O(n) best case
* O(n log n) average case
* O(n^2/3) worst case
* O(log n log n) auxiliary space complexity
* O(log n) auxiliary space complexity (in-place)

**Implementation**

The algorithm is a 3-way stable quick sort, meaning elements are divided into three groups by pivot: [less than, equal to, greater than]. The best case is only achieved when all elements are equal to the pivot. There is no fall-back algorithm, as the lower space complexity would require implementing an in-place merge sort to suit.

The pivot is chosen from a median of five in six comparisons. Besides for generally choosing a better pivot, this guarantees that each partition contains at least three elements on each pass, reducing the worst-case by a third.

Partitioning works by scanning the list from left to right, grouping elements that are less than, equal to, or greater than the pivot. The size of the resulting partition depends on the distribution of these elements.

If using additional space, elements less than are written in-place, while elements equal or greater than are stored in the additional space, with equal elements being stored at the end in reverse order. Once the additional space is full, the elements are copied back.

If sorting in-place, elements are rearranged using insertions. It continues to sort until the cost of insertions is too expensive. It stops when it takes more than 32 insertions to move an element into place.

Initially, only several small sublists are partitioned. The elements in these sublists are then brought together by rotating elements between two sublists at a time, until the entire range is properly partitioned.

When a partition is small enough, binary insertion sort is used to sort small sublists of up to 32 elements. This increases performance as well as reduces the number of comparisons in an average case.

----------


# Other Algorithms #

**Smooth sort** - A natural heap sort variant using leonardo numbers. An implementation in D can be found [here](https://github.com/deadalnix/Dsort/blob/master/sort/smooth.d), albeit it is broken.

**Tree Sort** - A sorting algorithm utilizing a binary search tree (preferably self-balancing). One can easily be implemented in D using [RedBlackTree in std.container](http://dlang.org/phobos/std_container.html#RedBlackTree).