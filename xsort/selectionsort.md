# Bubble Sort #
 [Selection sort](https://en.wikipedia.org/wiki/Selection_sort) is one of the most basic sorting algorithms. It's often used as a tool to introduce beginning programmers about sorting algorithms or algorithms in general.  Compared to bubble sort, it does significantly less I/O. Otherwise, selection sort has poor performance characteristics so it's not a good algorithm to use in practice.

Also see [bubble sort](https://en.wikipedia.org/wiki/Bubble_sort) and [insertion sort](https://en.wikipedia.org/wiki/Insertion_sort).

## Attributes ##
- Unstable
- O(n^2) time complexity
- O(1) space complexity

## Implementation ##
The implementation is written to work with any forward range with assignable or ref-able elements, such as [std.container:SList](http://dlang.org/phobos/std_container.html#.SList).

On each pass, it traverses the range to find the next smallest element and swaps it into place. The code is optimized to minimize I/O so that it performs exactly N writes on a range with N elements.

## Example ##
    import xsort.selectionsort;
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    selectionSort(array);
    
    // Sort array in reverse order
    selectionSort!"b < a"(array);