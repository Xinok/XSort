/++
    Bubble Sort for Forward Ranges
    
    Authors:  Xinok
    License:  Public Domain
++/

module xsort.bubblesort;
import std.range, std.algorithm, std.functional;

/++
    Sorts a forward range in-place using the bubble sort algorithm
    
    Params:
    LessFun = Predicate used for comparing elements
    Range = Type of the range being sorted
++/

@safe @nogc
void bubbleSort(alias LessFun = "a < b", Range)(Range r)
{
    static assert(isForwardRange!Range);
    static assert(!isInfinite!Range);
    static assert(hasAssignableElements!Range
               || hasSwappableElements!Range);
    
    BubbleSortImpl!(Range, LessFun).sort(r);
    
    if(!__ctfe) assert(isSorted!(LessFun)(r.save), "Range is not sorted");
}

///
unittest
{
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    bubbleSort(array);
    assert(array == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    
    // Sort array in reverse order
    bubbleSort!"b < a"(array);
    assert(array == [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
}

template BubbleSortImpl(Range, alias LessFun)
{
    static assert(isForwardRange!Range);
    static assert(!isInfinite!Range);
    static assert(hasAssignableElements!Range ||
                  hasSwappableElements!Range);
    
    alias ElementType!Range Element;
    alias binaryFun!LessFun less;
    
    @safe @nogc
    void sort()(Range r)
    {
        /+
            The greatest element is moved into place on each pass. We can save
            time by skipping these elements once they're in place.
        +/
        
        for(size_t end = walkLength(r); end > 1; --end)
        {
            Range a = r.save;
            Range b = r.save;
            b.popFront();
            
            foreach(i; 1 .. end)
            {
                if(less(b.front, a.front)) swapFront(a, b);
                a.popFront();
                b.popFront();
            }
        }
    }
    
    // Swap front elements of two forward ranges
    @safe @nogc
    void swapFront()(Range a, Range b)
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
    bubbleSort(array);
    checkArray(array);
    
    
    /+
        Few Elements Test
    
        Special test cases when the array has no more than a few elements
    +/
    
    array = [];
    bubbleSort(array);
    checkArray(array);
    array = [0];
    bubbleSort(array);
    checkArray(array);
    array = [1, 0];
    bubbleSort(array);
    checkArray(array);
    
    
    /+
        Attributes Test
        
        Check that the following function compiles without any errors
    +/
    
    @safe @nogc pure static
    void purityTest()
    {
        // Test attributes on custom predicate
        @safe @nogc pure static
        bool pred(int a, int b){ return b > a; }
        
        // Allocate static array to prevent GC allocation
        int[8] array = [3, 4, 2, 6, 7, 1, 0, 5];
        
        bubbleSort!pred(array[]);
    }
}