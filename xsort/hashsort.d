/++
    Hash Sort for Random-Access Ranges
    
    Authors:  Xinok
    License:  Public Domain
++/

module xsort.hashsort;
import std.range, std.algorithm, std.functional;

/++
    Sorts a random-access range using a variant of counting sort
    
    Params:
    LessFun = Predicate used for comparing elements
    Range = Type of the range being sorted
++/

SortedRange!(Range, LessFun) hashSort(alias LessFun = "a < b", Range)(Range r)
{
    HashSortImpl!(Range, LessFun).sort(r);
    if(!__ctfe) assert(isSorted!(LessFun)(r.save), "Range is not sorted");
    return assumeSorted!(LessFun, Range)(r.save);
}

///
unittest
{
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    hashSort(array);
    assert(array == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    
    // Sort array in reverse order
    hashSort!"b < a"(array);
    assert(array == [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
}

template HashSortImpl(Range, alias LessFun)
{
    static assert(isRandomAccessRange!Range);
    static assert(hasLength!Range);
    static assert(hasAssignableElements!Range || hasSwappableElements!Range);
    static assert(isKeyType!Element);
    
    enum isKeyType(T) = __traits(compiles, size_t[T]);
    
    alias ElementType!Range Element;
    alias binaryFun!LessFun less;
    
    void sort()(Range r)
    {
        // Count number of instances of each distinct key
        size_t[Element] counter;
        foreach(e; r) counter[e]++;
        
        // Sort keys using comparison-based algorithm
        auto keys = std.algorithm.sort!less(counter.keys).release;
        
        // Compute the ending index for each distinct element
        size_t index = r.length;
        foreach_reverse(k; keys)
        {
            counter[k] = index -= counter[k];
        }
        
        // Compute sorted position of each element
        size_t[] indices;
        indices.length = r.length;
        foreach(i, ref e; indices) e = counter[r[i]]++;
        
        version(unittest)
        for(__gshared runOnce = true; runOnce && r.length >= 16; runOnce = false)
        {
            // Checks that all values in indices are distinct
            bool[] flags;
            flags.length = r.length;
            foreach(i; indices) flags[i] = true;
            foreach(b; flags) assert(b);
        }
        
        // This step is, in essence, a cycle sort which uses the pre-computed
        // indices to stably sort the elements in linear time
        foreach(a; 0 .. r.length)
        {
            size_t b = indices[a];
            
            while(a != b)
            {
                swapAt(r, a, b);
                swapAt(indices, a, b);
                b = indices[a];
            }
        }
    }
    
    void swapAt(Range)(Range r, size_t a, size_t b)
    {
        static if(hasSwappableElements!Range)
        {
            swap(r[a], r[b]);
        }
        else
        {
            auto c = r[a];
            r[a] = r[b];
            r[b] = c;
        }
    }
}

unittest
{
    /+
        General Sorting Test
        
        The array contains the elements 0 to 31 in a random order. After 
        sorting, it should be true that array[i] == i for all i.
    +/
    
    @safe @nogc pure static
    void checkArray(R)(R array)
    {
        foreach(a, b; array) assert(a == b);
    }
    
    auto array = [
        2, 17, 19, 22, 0, 7, 30, 5, 9, 12, 23, 8, 18, 21, 11, 20,
        15, 4, 28, 25, 3, 1, 26, 24, 31, 13, 6, 16, 14, 29, 10, 27
        ];
    hashSort(array);
    checkArray(array);
    
    
    /+
        Few Elements Test
    
        Special test cases when the array has no more than a few elements
    +/
    
    array = [];
    hashSort(array);
    checkArray(array);
    array = [0];
    hashSort(array);
    checkArray(array);
    array = [1, 0];
    hashSort(array);
    checkArray(array);
}