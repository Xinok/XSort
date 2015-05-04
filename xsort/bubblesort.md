# Bubble Sort #
[Bubble sort](https://en.wikipedia.org/wiki/Bubble_sort) is one of the most basic sorting algorithms. It's often used as a tool to introduce beginning programmers about sorting algorithms or algorithms in general. Otherwise, bubble sort has poor performance characteristics so it's not a good algorithm to use in practice.

Also see [selection sort](https://en.wikipedia.org/wiki/Selection_sort) and [insertion sort](https://en.wikipedia.org/wiki/Insertion_sort).

## Attributes ##
- Stable
- O(n^2) time complexity
- O(1) space complexity

## Implementation ##
The implementation is written to work with any forward range with assignable or ref-able elements, such as [std.container:SList](http://dlang.org/phobos/std_container.html#.SList).

**Optimization:** On each pass, the greatest element is moved into place at the end of the range. As such, there is no need to traverse these elements again so they are skipped on latter passes.

## Example ##
    import xsort.bubblesort;
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    bubbleSort(array);
    
    // Sort array in reverse order
    bubbleSort!"b < a"(array);