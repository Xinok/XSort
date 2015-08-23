/++
    Cycle Sort for Forward Ranges
    
    Authors:  Xinok
    License:  Public Domain
++/

module xsort.cyclesort;
import std.range, std.algorithm, std.functional;

/++
    Sorts a forward range in-place using the cycle sort algorithm
    
    Params:
    LessFun = Predicate used for comparing elements
    Range = Type of the range being sorted
++/

@safe @nogc
void cycleSort(alias LessFun = "a < b", Range)(Range r)
{
    static assert(isForwardRange!Range);
	static assert(!isInfinite!Range);
	static assert(hasAssignableElements!Range);
    
    CycleSortImpl!(Range, LessFun).sort(r);
    
    if(!__ctfe) assert(isSorted!(LessFun)(r.save), "Range is not sorted");
}

///
unittest
{
    auto array = [5, 10, 2, 1, 6, 7, 8, 4, 3, 9];
    
    // Sort array
    cycleSort(array);
    assert(array == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    
    // Sort array in reverse order
    cycleSort!"b < a"(array);
    assert(array == [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
}

template CycleSortImpl(Range, alias LessFun)
{
    static assert(isForwardRange!Range);
	static assert(!isInfinite!Range);
	static assert(hasAssignableElements!Range);
    
    alias ElementType!Range Element;
    alias binaryFun!LessFun less;
    
    @safe @nogc
    void sort()(Range r)
    {
        while(!r.empty)
        {
            auto el = r.front;
            size_t lastIndex = 0;
            while(true)
            {
                // Find where to insert 'el'
                size_t offset = 0;
                auto it = r.save;
                it.popFront();
                foreach(v; it) if(less(v, el)) offset += 1;
                it = consume(r, offset);
                
                if(lastIndex == 0 && offset == 0) break;
                
                // Find first position AFTER any equal elements
                while(!it.empty && !less(it.front, el) && !less(el, it.front))
                {
                    it.popFront();
                    offset += 1;
                }
                
                // If all remaining elements are equal
                // then there is nothing left to do
                if(it.empty)
                {
                    assert(lastIndex == 0);
                    return;
                }
                
                // Insert at current position
                auto temp = it.front;
                it.front = el;
                
                // Cycle complete
                if(offset == 0) break;
                
                // Prepare for next iteration of cycle...
                el = temp;
                lastIndex = offset;
            }
            
            r.popFront();
        }
    }
    
    auto consume(Range r, size_t count)
    {
        auto t = r.save;
        foreach(i; 0..count) t.popFront();
        return t;
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
    cycleSort(array);
    checkArray(array);
    
    
    /+
        Few Elements Test
    
        Special test cases when the array has no more than a few elements
    +/
    
    array = [];
    cycleSort(array);
    checkArray(array);
    array = [0];
    cycleSort(array);
    checkArray(array);
    array = [1, 0];
    cycleSort(array);
    checkArray(array);
    
    
    /+
        Attributes Test
        
        Check that the following function compiles without any errors
    +/
    
    version(none)
    @safe @nogc pure static
    void purityTest()
    {
        // Test attributes on custom predicate
        @safe @nogc pure static
        bool pred(int a, int b){ return b > a; }
        
        // Allocate static array to prevent GC allocation
        int[8] array = [3, 4, 2, 6, 7, 1, 0, 5];
        
        cycleSort!pred(array[]);
    }
}