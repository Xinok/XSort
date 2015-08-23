# [Cycle Sort](./cyclesort.d) #
[Cycle sort](https://en.wikipedia.org/wiki/Cycle_sort) is known for performing the minimal number of writes possible to sort an array. It is not a practical algorithm because of poor performance characteristics but is useful in a theoretical context.

Also see [selection sort](https://en.wikipedia.org/wiki/Selection_sort).

## Attributes ##
- Unstable
- O(n^2) time complexity
- O(1) space complexity
- O(n) writes

## Implementation ##
This implementation supports forward ranges with assignable elements. It was written as to perform the minimal number of writes to the original array. This means it uses assignments rather than swaps as each swap performs two writes. 

## Example ##
    import xsort.cyclesort;
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    cylceSort(array);
    
    // Sort array in reverse order
    cycleSort!"b < a"(array);