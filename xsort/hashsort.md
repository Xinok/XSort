# [Hash Sort](./hashsort.d) #
Hash sort is a variant of [counting sort](https://en.wikipedia.org/wiki/Counting_sort) which uses a [hash table](https://en.wikipedia.org/wiki/Hash_table) to find and count all distinct elements in the range. The hash table means this algorithm is adaptable to a much wider variety of element types. I coined the name Hash Sort because I'm unaware of any other similar named algorithms.

If the number of distinct elements remains constant, then this algorithm runs in linear time. However, the overhead of the hash table generally makes this a slower algorithm in practice.

## Attributes ##
- Stable
- O(n) best-case time complexity
- O(n log n) worst-case time complexity
- O(n) space complexity

## Algorithm ##
This section provides a brief description of the algorithm since I'm unaware of any similar algorithms. Implementation specific details are given in the next section.

**Find and count all distinct elements:** A hash table is used to find and track all distinct elements. The elements in the range act as keys and the elements of the hash table are counters. Assuming the hash table exhibits constant look-up time, this stage runs in linear time.

**Sort the Keys:** Extract the keys from the hash table and sort them using any sorting algorithm. The time complexity of this stage is dependent on the sorting algorithm used. In any case, if the number of distinct elements is constant, then the running time of this stage is constant, thus the algorithm as a whole runs in linear time.

**Build array of indices:** By traversing the keys in the hash table in ascending or descending order, modify the counters to represent the starting index of each distinct element. Then traverse the range and, by looking up each element in the hash table and incrementing the counters, build an array of indices which contains the sorted index for each element.

**Cycle Sort:** Perform a cycle sort to move the elements into place using the array of indices to determine where each element belongs.

## Implementation ##
The D language has built-in [associative arrays](http://dlang.org/hash-map.html) which are used for the hash table. This was done for the sake of simplicity but the downside is that you cannot simply provide your own hash function. This can be remedied by building a wrapper type for the elements which contains a custom hash function.

When sorting the keys, the Phobos unstable sort is used. The implementation assumes all keys are distinct. The stability of the algorithm depends on the predicate treating two elements as equal if and only if those two elements produce the same hash.

## Example ##
    import xsort.hashsort;
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    hashSort(array);
    
    // Sort array in reverse order
    hashSort!"b < a"(array);