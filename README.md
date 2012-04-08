A collection of sorting algorithms for the D programming language. Some were implemented with a specific purpose in mind *(stable / unstable / forward sorting)*, while others are generic implementations provided for general use or reference. All modules contain documentation, unittests, and can be used independently of one another.

Phobos is the standard library for the [D programming language](http://dlang.org/). The stable sort in Phobos is slow, broken, and not even stable ([bug 4584](http://d.puremagic.com/issues/show_bug.cgi?id=4584)). The unstable sort works great overall but has a few bad cases where it performs poorly ([bug 7767](http://d.puremagic.com/issues/show_bug.cgi?id=7767)). I provide two of these modules as substitutes (and possible replacements) for the sort function in Phobos.

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

For additional space, up to 1KiB may be allocated on the stack (using alloca()), and anything larger will be allocated on the heap. When sorting in-place, no additional space is allocated.

It begins with a natural merge sort which scans the list from left to right, looking for "runs" in ascending or descending order and merging them. A 'run' is a sublist of elements that is already sorted. If the elements are in descending order, it will reverse them.

If a run is too small, a binary insertion sort is used to build the run up to MIN_RUN length (32 elements long).

When merging, one of the two halves is copied into temporary memory and then merged in place. It may need to merge from front to back, or back to front, depending on which half was copied into temporary memory.

Rotations are used to reduce two runs into four smaller runs. It's difficult to explain how or why this works. This is done recursively until the runs are small enough to fit into the additional space.

An optional template argument, inPlace, when set to true, utilizes no *additional space* at the cost of performance. In-place merging is done using insertions rather than temporary memory.


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

It begins with a quick sort that chooses a pivot from a median of three, from the first, middle, and last elements. The partitioning method used works well when several elements are equal to the pivot.

When a partition is small enough, binary insertion sort is used to sort small sublists of up to 32 elements. This increases performance as well as reduces the number of comparisons in an average case.

If too many recursions occur, shell sort is used to avoid the worst case of quick sort. While heap sort is a more popular choice, I chose shell sort because I've typically found it to be faster and do fewer comparisons. It begins with the gap sequence, `[1, 4, 10, 23, 57, 132, 301, 701, 1750]`, and uses the formula, `(9 ^ k - 4 ^ k) / (5 * 4 ^ (k - 1))`, to generate larger gaps.

----------

# forwardsort.d #
An unstable sort for sorting forward ranges in-place.

Forward ranges don't allow for random access, so efficiently sorting in-place is more difficult. 

> **WARNING:** This has a worst case performance of O(n^2). It's unlikely to occur in regular usage, but it's potentially exploitable in a DoS attack. Do not use when security is vital.

**Features**

* Concurrently sort range in multiple threads

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

A standard shell sort implementation. It begins with the gap sequence, `[1, 4, 10, 23, 57, 132, 301, 701, 1750]`, and uses the formula, `(9 ^ k - 4 ^ k) / (5 * 4 ^ (k - 1))`, to generate larger gaps.

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

----------

# Other Algorithms #

**Tim Sort** - A clever adaptive merge sort variant which strives to minimize comparisons. An implementation in D can be found [here](http://personal.utulsa.edu/~ellery-newcomer/timsort.d), albeit it is broken. I plan to write my own module.

**Heap Sort** - An in-place unstable sorting algorithm with a guaranteed worst case performance of O(n log n).

**Stable quick sort** - It is possible to write a stable quick sort, though there's no reason to use it over merge sort. I plan to write a module with three levels of space complexity: O(n), O(log n log n), and O(log n) in-place.

**Smooth sort** - A natural heap sort variant using leonardo numbers. An implementation in D can be found [here](https://github.com/deadalnix/Dsort/blob/master/sort/smooth.d), albeit it is broken.

**Tree Sort** - A sorting algorithm utilizing a binary search tree (preferably self-balancing). One can easily be implemented in D using [RedBlackTree in std.container](http://dlang.org/phobos/std_container.html#RedBlackTree).