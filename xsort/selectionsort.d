/++
    Selection Sort for Forward Ranges
    
    Authors:  Xinok
    License:  Public Domain
++/

module xsort.selectionsort;
import std.range, std.algorithm, std.functional;

/++
    Sorts a forward range in-place using the selection sort algorithm
    
    Params:
    LessFun = Predicate used for comparing elements
    Range = Type of the range being sorted
++/

void selectionSort(alias LessFun = "a < b", Range)(Range r)
{
    static assert(isForwardRange!Range);
    static assert(!isInfinite!Range);
    static assert(hasAssignableElements!Range
               || hasSwappableElements!Range);
    
    SelectionSortImpl!(Range, LessFun).sort(r);
    
    if(!__ctfe) assert(isSorted!(LessFun)(r.save), "Range is not sorted");
}

///
unittest
{
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    selectionSort(array);
    assert(array == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    
    // Sort array in reverse order
    selectionSort!"b < a"(array);
    assert(array == [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
}

template SelectionSortImpl(Range, alias LessFun)
{
    static assert(isForwardRange!Range);
    static assert(!isInfinite!Range);
    static assert(hasAssignableElements!Range ||
                  hasSwappableElements!Range);
    
    alias ElementType!Range Element;
    
    alias binaryFun!LessFun less;
    // bool greater(T a, T b){ return less(b, a); }
    // bool greaterEqual(T a, T b){ return !less(a, b); }
    // bool lessEqual(T a, T b){ return !less(b, a); };
    
    void sort(Range r)
    {
        Range current = r.save;
        while(!current.empty)
        {
            Range max = current.save;
            Range iterator = current.save;
            iterator.popFront();
            while(!iterator.empty)
            {
                if(less(iterator.front, max.front)) max = iterator.save;
                iterator.popFront();
            }
            swapFront(current, max);
            current.popFront();
        }
    }
    
    // Swap front elements of two forward ranges
    void swapFront(Range a, Range b)
    {
        static if(hasSwappableElements!Range) swap(a.front, b.front);
        else
        {
            auto o = a.front;
            a.front = b.front;
            b.front = o;
        }
    }
}

unittest
{
    /+
        The array contains the elements 0 to 31 in a random order. After 
        sorting, it should be true that array[i] == i for all i.
    +/
    
    auto array = [
        2, 17, 19, 22, 0, 7, 30, 5, 9, 12, 23, 8, 18, 21, 11, 20,
        15, 4, 28, 25, 3, 1, 26, 24, 31, 13, 6, 16, 14, 29, 10, 27
        ];
    
    selectionSort(array);
    
    foreach(a, b; array) assert(a == b);
}