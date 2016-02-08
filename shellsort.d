/++
    Shell Sort for Random-Access Ranges
        
    Authors:  Xinok
    License:  Public Domain
++/

module shellsort;
import std.range, std.algorithm, std.functional, std.parallelism;

/++
    Performs a shell sort on a random-access range according to predicate less.
    
    Returns: Sorted input as SortedRange
    
    Params:
    threaded = Set to true for concurrent sorting
    
    Examples:
    -----------------
    int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
    shellSort(array);
    shellSort!"a > b"(array); // Sorts array descending
    -----------------
++/

@trusted SortedRange!(R, less) shellSort(alias less = "a < b", R)(R range, immutable bool threaded = false)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasAssignableElements!R);
    
    if(threaded) ShellSortImpl!(less, R).sort(range, defaultPoolThreads + 1);
    else ShellSortImpl!(less, R).sort(range);
    
    if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
    return assumeSorted!(less, R)(range.save);
}

template ShellSortImpl(alias pred = "a < b", R)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasAssignableElements!R);
    
    alias ElementType!R T;
    alias binaryFun!pred less;
    
    static immutable gaps = [
        1147718699, 510097199, 226709865, 100759939, 44782195, 19903197, 
        8845865, 3931495, 1747330, 776590, 345151, 153400, 68177, 30300, 
        13466, 5984, 2659, 1750, 701, 301, 132, 57, 23, 10, 4, 1];
    
    void sort(R range)
    {
        foreach(gap; gaps) if(gap <= range.length / 2) pass(range, gap);
    }
    
    void sort(R range, size_t threadCount)
    {
        foreach(gap; gaps) if(gap <= range.length / 2)
        {
            immutable count = min(threadCount, gap);
            
            if(count == 1)
            {
                pass(range, gap);
                continue;
            }
            
            sort(range, count, gap, gap, gap * 2);
        }
    }
    
    void sort(R range, immutable size_t threadCount, immutable size_t gap, immutable size_t start, immutable size_t end)
    {
        if(threadCount < 2)
        {
            pass(range, gap, start, end);
            return;
        }
        
        immutable mid = (end - start) / threadCount * (threadCount / 2) + start;
        
        auto th = task!sort(range, threadCount / 2, gap, start, mid);
        taskPool.put(th);
        sort(range, threadCount - (threadCount / 2), gap, mid, end);
        th.workForce();
    }
    
    void pass(R range, immutable size_t gap)
    {
        size_t i;
        T o;
        
        foreach(start; gap .. range.length) if(less(range[start], range[start - gap]))
        {
            i = start;
            o = range[i];
            do
            {
                range[i] = range[i - gap];
                i -= gap;
            }
            while(i >= gap && less(o, range[i - gap]));
            range[i] = o;
        }
    }
    
    void pass(R range, immutable size_t gap, size_t start, immutable size_t end)
    {
        size_t c, i;
        T o;
        
        for(; start < end; ++start)
            for(c = start; c < range.length; c += gap)
                if(less(range[c], range[c - gap]))
        {
            i = c;
            o = range[i];
            do
            {
                range[i] = range[i - gap];
                i -= gap;
            }
            while(i >= gap && less(o, range[i - gap]));
            range[i] = o;
        }
    }
}

// No longer used; Provided merely for reference
version(none) pure immutable(size_t)[] shellGaps(size_t len)
{
    import std.math;
    
    immutable(size_t)[] gaps = [1, 4, 10, 23, 57, 132, 301, 701, 1750];
    if(__ctfe) return gaps;
    
    real k = 10;
    real gap;
    if(gaps[0] < len) while(true)
    {
        gap = (9 ^^ k - 4 ^^ k) / (5 * 4 ^^ (k - 1));
        if(gap > len) break;
        gaps ~= cast(size_t)gap;
        ++k;
    }
    return gaps;
}

unittest
{
    bool testSort(alias pred, R)(R range)
    {
        shellSort!(pred, R)(range);
        return isSorted!pred(range);
    }
    
    int testCall(T)(in T[] arr)
    {
        int failures = 0;
        
        if(!testSort!"a < b"(arr.dup)) ++failures;
        if(!testSort!"a > b"(arr.dup)) ++failures;
        
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
        static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: shellSort CTFE unittest failed ", result, " of 2 tests");
    }
}