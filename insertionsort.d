/++
    Insertion Sort for Random-Access Ranges
    
    Authors:  Xinok
    License:  Public Domain
++/

module insertionsort;
import std.range, std.algorithm, std.functional, std.array;

/++
    Performs an insertion sort on a random-access range according to predicate less.
    
    Returns: Sorted input as SortedRange
    
    Examples:
    -----------------
    int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
    insertionSort(array);
    insertionSort!"a > b"(array); // Sorts array descending
    -----------------
++/
@trusted SortedRange!(R, less) insertionSort(alias less = "a < b", R)(R range)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasAssignableElements!R);
    alias ElementType!R T;
    alias binaryFun!less lessFun;
    
    T o; size_t j;
    for(size_t i = 1; i < range.length; ++i) if(lessFun(range[i], range[i - 1]))
    {
        j = i; o = range[j];
        do
        {
            range[j] = range[j - 1];
            --j;
        }
        while(j >= 1 && lessFun(o, range[j - 1]));
        range[j] = o;
    }
    
    if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
    return assumeSorted!(less, R)(range.save);
}

/++
    Performs an insertion sort on a random-access range according to predicate less.
    Uses specified SearchPolicy to search sorted elements before inserting.
    Use binary search for high entropy, and gallop or trot for low entropy.
    gallop / gallopBackwards and trot / trotBackwards are treated as the same.
    
    Returns: Sorted input as SortedRange
    
    Examples:
    -----------------
    int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
    insertionSort!("a < b", SearchPolicy.binarySearch)(array); // Sort array utilizing binary search
    -----------------
++/
@trusted SortedRange!(R, less) insertionSort(alias less = "a < b", SearchPolicy SP, R)(R range)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasAssignableElements!R);
    alias ElementType!R T;
    alias binaryFun!less lessFun;
    
    size_t lower, center, upper;
    alias center gap;
    T o;
    foreach(i; 1 .. range.length)
    {
        o = range[i];
        lower = 0;
        upper = i;
        
        static if(SP == SearchPolicy.gallop || SP == SearchPolicy.gallopBackwards)
        {
            gap = 1;
            while(gap <= upper)
            {
                if(lessFun(o, range[upper - gap]))
                {
                    upper -= gap;
                    gap *= 2;
                }
                else
                {
                    lower = upper - gap + 1;
                    break;
                }
            }
        }
        
        static if(SP == SearchPolicy.trot || SP == SearchPolicy.trotBackwards)
        {
            gap = 1;
            while(gap <= upper)
            {
                if(lessFun(o, range[upper - gap]))
                {
                    upper -= gap;
                    ++gap;
                }
                else
                {
                    lower = upper - gap + 1;
                    break;
                }
            }
        }
        
        // Binary search on remainder
        while(upper != lower)
        {
            center = (lower + upper) / 2;
            if(lessFun(o, range[center])) upper = center;
            else lower = center + 1;
        }
        
        // Insertion
        for(upper = i; upper > lower; --upper) range[upper] = range[upper - 1];
        range[upper] = o;
    }
    
    if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
    return assumeSorted!(less, R)(range.save);
}

/+
    An alternate implementation of binary insertion sort utilizing
    Duff's Device for insertion
+/
@trusted SortedRange!(R, less) duffInsertionSort(alias less = "a < b", R)(R range)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasAssignableElements!R);
    alias ElementType!R T;
    alias binaryFun!less lessFun;
    
    size_t lower, center, upper;
    T o;
    foreach(i; 1 .. range.length)
    {
        o = range[i];
        lower = 0;
        upper = i;
        
        // Binary search
        while(upper != lower)
        {
            center = (lower + upper) / 2;
            if(lessFun(o, range[center])) upper = center;
            else lower = center + 1;
        }
        
        upper = i;
        // Insertion using simple loop for CTFE
        if(__ctfe) for(; upper > lower; --upper) range[upper] = range[upper - 1];
        else if(upper > lower)
        {
            // Insertion using Duff's Device
            switch((upper - lower) % 8)
            {
                default: assert(0);
                case 0: range[upper] = range[upper - 1]; --upper; goto case;
                case 7: range[upper] = range[upper - 1]; --upper; goto case;
                case 6: range[upper] = range[upper - 1]; --upper; goto case;
                case 5: range[upper] = range[upper - 1]; --upper; goto case;
                case 4: range[upper] = range[upper - 1]; --upper; goto case;
                case 3: range[upper] = range[upper - 1]; --upper; goto case;
                case 2: range[upper] = range[upper - 1]; --upper; goto case;
                case 1: range[upper] = range[upper - 1]; --upper;
                if(upper > lower) goto case 0;
            }
        }
        
        range[upper] = o;
    }
    
    if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
    return assumeSorted!(less, R)(range.save);
}

unittest
{
    bool testSort(alias pred, R)(R range)
    {
        insertionSort!(pred, R)(range);
        return isSorted!pred(range);
    }
    
    bool testSort2(alias pred, SearchPolicy SP, R)(R range)
    {
        insertionSort!(pred, SP, R)(range);
        return isSorted!pred(range);
    }
    
    int testCall(T)(in T[] arr)
    {
        int failures = 0;
        
        if(!testSort!"a < b"(arr.dup)) ++failures;
        if(!testSort!"a > b"(arr.dup)) ++failures;
        if(!testSort2!("a < b", SearchPolicy.binarySearch)(arr.dup)) ++failures;
        if(!testSort2!("a > b", SearchPolicy.binarySearch)(arr.dup)) ++failures;
        if(!testSort2!("a < b", SearchPolicy.gallop)(arr.dup)) ++failures;
        if(!testSort2!("a > b", SearchPolicy.gallop)(arr.dup)) ++failures;
        if(!testSort2!("a < b", SearchPolicy.trot)(arr.dup)) ++failures;
        if(!testSort2!("a > b", SearchPolicy.trot)(arr.dup)) ++failures;
        
        return failures;
    }
    
    // Array containing 256 random ints
    enum test = [
        10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70, 89, 94, 32, 46, 76, 43, 33, 62, 76, 
        37, 93, 45, 48, 49, 21, 67, 56, 58, 17, 15, 41, 91, 94, 95, 41, 38, 80, 37, 24, 
        26, 71, 87, 54, 72, 60, 29, 37, 41, 99, 31, 66, 75, 72, 86, 97, 37, 25, 98, 89, 
        53, 45, 52, 76, 51, 38, 59, 53, 74, 96, 94, 42, 68, 84, 65, 27, 49, 57, 53, 74, 
        39, 75, 39, 26, 46, 37, 68, 96, 19, 79, 73, 83, 36, 90, 11, 39, 48, 94, 97, 72, 
        37, 43, 69, 36, 41, 47, 31, 48, 33, 21, 20, 18, 45, 28, 47, 54, 41, 28, 47, 44, 
        51, 15, 21, 64, 82, 23, 41, 82, 30, 25, 78, 72, 50, 34, 45, 59, 14, 71, 50, 97, 
        39, 87, 74, 60, 52, 17, 87, 45, 69, 54, 91, 68, 46, 99, 78, 33, 27, 53, 41, 84, 
        82, 54, 29, 55, 53, 87, 13, 98, 55, 33, 73, 64, 19, 81, 57, 78, 23, 45, 94, 75, 
        55, 43, 93, 85, 96, 82, 44, 73, 22, 79, 89, 20, 36, 11, 12, 51, 86, 86, 75, 66, 
        81, 90, 80, 80, 36, 36, 47, 43, 86, 96, 45, 73, 70, 90, 57, 23, 86, 29, 12, 54, 
        37, 17, 87, 12, 36, 78, 26, 28, 30, 15, 10, 53, 76, 34, 23, 49, 65, 17, 37, 51, 
        26, 23, 66, 12, 26, 84, 60, 47, 30, 26, 78, 20, 42, 40, 63, 40
    ];
    
    // Runtime test
    assert(testCall(test) == 0);
    
    // CTFE Test
    {
        enum result = testCall(test);
        static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: insertionSort CTFE unittest failed ", result, " of 8 tests");
    }
}