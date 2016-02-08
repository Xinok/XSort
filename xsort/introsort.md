# [Introsort](./introsort.d) #
[Introsort](https://en.wikipedia.org/wiki/Introsort) is an unstable hybrid sorting algorithm which begins with quicksort but falls back to heapsort in the worst case to sustain [linearithmic](https://en.wikipedia.org/wiki/Time_complexity#Linearithmic_time) running time.

## Attributes ##
- Unstable
- O(n log n) running time
- O(log n) space (due to function recursion)

## Implementation ##
**Choosing a pivot:** The pivot is chosen from a median of three for small sublists and a median of five for larger sublists. The threshold can be changed by modifying the constant `PIVOT_THRESHOLD`. The median of five usually results in a better pivot but does add a small overhead which is why a median of three is used for small sublists. Once the median is found, the first few elements can be partitioned without any additional comparisons. A small negative is that the median of five tends to remove a bit of structure from the input which, after many recursions, may result in slightly worse performance by the end. However, the benefits are obvious for inputs exhibiting high entropy.

The algorithm for median of five partitions the elements by the median in six comparisons such that `(a <= c && b <= c && c <= d && c <= e)`. This algorithm allows these few elements to be partitioned without any additional comparisons. My original implementation has been replaced by a superior implementation [found here](http://forum.dlang.org/post/n8u980$1gkr$1@digitalmars.com) which is [idempotent](https://en.wiktionary.org/wiki/idempotent#Adjective) and performs fewer swaps overall.

**Partitioning:** The partition strategy is designed to minimize overall swaps and handle large amounts of equal elements efficiently. An element less than the pivot will never be moved to the right partition unnecessarily and vice versa. It attempts to distribute equal elements amongst both partitions in hopes of placing the pivot closer to the center.

It alternates between iterating the left and right indices, skipping over equal elements, until it encounters an element that belongs in the other partition. At this point, it will "fast-forward" the other iterator until it finds an element that it can swap with, thus moving two elements into place with a single swap. A small compromise was made, it may swap with an element equal to the pivot because this achieved better results in many test cases.

I was able to apply a small optimization when it "fast-forwards" by excluding any bounds checking. This is thanks to the first step when it chooses a pivot. Since a few elements are already partitioned, they act as "barriers" preventing the iterators from running outside the bounds of the array.

**Insertion Sort:** Once a sublist becomes small enough, [insertion sort](https://en.wikipedia.org/wiki/Insertion_sort) is used to finish sorting. This is often faster because insertion sort has less overhead than quicksort. The threshold for this step can be changed by modifying the constant `MAX_INSERT`. A [galloping search](https://en.wikipedia.org/wiki/Exponential_search) is used to find where to insert the max element. A galloping search performs O(n) comparisons in the best case and O(n log n) in the worst-case. It typically achieves better results on inputs with low entropy.

Galloping search can be disabled by setting the constant `GALLOP_MODE` to false. By disabling gallop mode, insertion sort will use a binary search instead which performs better on input with high entropy.

**Heapsort:** If, after O(log n) recursions, the input is still not completely sorted, the remaining elements will be sorted using heapsort instead. More specifically, [bottom-up heapsort](https://en.wikipedia.org/wiki/Heapsort#Bottom-up_heapsort) is used because it performs almost half the number of comparisons in an average case but also performs more swaps. Heapsort makes a good fall-back algorithm because it runs in O(n log n) time and uses O(1) space but is typically slower than quicksort in an average case. Otherwise, there aren't any optimizations to speak of since this is only meant to handle the worst cases.

## Example ##
    import xsort.introsort;
    auto array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
    
    // Sort array
    introSort(array);
    
    // Sort array in descending order
    introSort!"a > b"(array);
    
    // Sort array concurrently in multiple threads
    introSort(array, true);