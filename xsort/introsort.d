/++
    Introsort for Random-Access Ranges
    
    Authors:  Xinok
    License:  Public Domain
++/

module xsort.introsort;
import std.range, std.algorithm, std.functional, std.parallelism;

/++
    Performs an introsort on a random-access range according to predicate less.
    Introsort is a hybrid algorithm which begins with quicksort but falls back
    to heapsort in the worst case to sustain linearithmic running time.
    
    Returns: Sorted input as SortedRange
    
    Params:
    range = Range to be sorted
    threaded = Set to true for concurrent sorting
    
    Params:
    less = Predicate (string, function, or delegate) used for comparing elements; Defaults to "a < b"
    R = Type of range to be sorted; Must be a finite random-access range with slicing
++/

@trusted SortedRange!(R, less) introSort(alias less = "a < b", R)(R range, bool threaded = false)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasSlicing!R);
    static assert(hasAssignableElements!R);
    
    IntroSortImpl!(less, R).sort(range, threaded);
    
    if(!__ctfe) assert(isSorted!(less)(range.save), "Range is not sorted");
    return assumeSorted!(less, R)(range.save);
}

///
unittest
{
    int[] array = [10, 37, 74, 99, 86, 28, 17, 39, 18, 38, 70];
    introSort(array);
    introSort!"a > b"(array); // Sorts array descending
    introSort(array, true);   // Sorts array using multiple threads
}

/// Introsort implementation
template IntroSortImpl(alias pred, R)
{
    static assert(isRandomAccessRange!R);
    static assert(hasLength!R);
    static assert(hasSlicing!R);
    static assert(hasAssignableElements!R);
        
    alias ElementType!R T;
    alias binaryFun!pred less;
    bool lessEqual(T a, T b){ return !less(b, a); }

    // Tweakable attributes of the algorithm
    enum MAX_INSERT      = 2^^5;  // Maximum length for an insertion sort
    enum MIN_THREAD      = 2^^10; // Minimum length of a sublist to initiate new thread
    enum PIVOT_THRESHOLD = 2^^8;  // Threshold to choose pivot from median of three or five
    enum GALLOP_MODE     = true;  // Activate galloping search for insertion sort
    
    /// Entry sort function
    void sort(R range, bool threaded = false)
    {
        if(threaded && !__ctfe) concSort(range, range.length);
        else sort(range, range.length);
    }
    
    /// Recursively partition list
    void sort(R range, real depth)
    {
        while(true)
        {
            if(range.length <= MAX_INSERT)
            {
                insertionSort(range);
                return;
            }
            if(depth < 1.0)
            {
                heapSort(range);
                return;
            }
            
            depth /= 1.5;
            
            immutable mid = partition(range);
            
            if(mid <= range.length / 2)
            {
                sort(range[0 .. mid - 1], depth);
                range = range[mid .. range.length];
            }
            else
            {
                sort(range[mid .. range.length], depth);
                range = range[0 .. mid - 1];
            }
        }
    }
    
    /// Concurrently sorts range
    void concSort(R range, real depth)
    {
        if(range.length < MIN_THREAD)
        {
            sort(range, depth);
            return;
        }
        if(depth < 1.0)
        {
            heapSort(range);
            return;
        }
        
        depth /= 1.5;
        
        immutable mid = partition(range);
        
        auto th = task!(concSort)(range[0 .. mid - 1], depth);
        taskPool.put(th);
        concSort(range[mid .. range.length], depth);
        th.workForce();
    }
    
    /// Partitions range, returns starting index of second range excluding pivot
    size_t partition(R range)
    {
        // Variables
        T piv, o;
        size_t lef, rig;
    
        // Choose pivot from median of three or five
        if(range.length <= PIVOT_THRESHOLD)
        {
            // Choose pivot from median of three
            immutable b = range.length / 2;
            getPivot3(range[0], range[b], range[range.length - 1]);
            
            // Move pivot into place
            swap(range[1], range[b]);
            
            // Initialize index variables
            lef = 2;
            rig = range.length - 2;
        }
        else
        {
            // Choose pivot from median of five
            immutable b = range.length / 4, c = range.length / 2, d = b + c;
            getPivot5(range[0], range[b], range[c], range[d], range[range.length - 1]);
            
            // Move first elements into place
            swap(range[2], range[b]);
            swap(range[1], range[c]);
            swap(range[range.length - 2], range[d]);
            
            // Initialize index variables
            lef = 3;
            rig = range.length - 3;
        }
        
        // Initialize pivot
        piv = range[1];
        
        /+
            Partition range by pivot
            
            The code is designed to handle large amounts of equal elements well
            * Equal elements are distributed among both partitions
            * Fewer writes are performed when equal elements are present
        +/
        do
        {
            if(less(piv, range[lef]))
            {
                while(less(piv, range[rig])) --rig;
                if(lef >= rig) break;
                swap(range[lef++], range[rig--]);
            }
            else ++lef;
            
            if(less(range[rig], piv))
            {
                while(less(range[lef], piv)) ++lef;
                if(lef >= rig) break;
                swap(range[lef++], range[rig--]);
            }
            else --rig;
        } while(lef < rig);
        
        // This step is necessary to ensure pivot is inserted at correct location
        if(lessEqual(range[lef], piv)) ++lef;
        
        // Move pivot into place
        swap(range[lef - 1], range[1]);
        
        return lef;
    }
    
    /// Sorts the elements satisfying the condition:
    /// (a <= b && b <= c)
    void getPivot3(ref T a, ref T b, ref T c)
    out
    {
        assert(lessEqual(a, b) && lessEqual(b, c));
    }
    body
    {
        if(less(b, a))
        {
            if(less(c, b)) swap(a, c);
            else
            {
                swap(a, b);
                if(less(c, b)) swap(b, c);
            }
        }
        else if(less(c, b))
        {
            swap(b, c);
            if(less(b, a)) swap(a, b);
        }
    }
    
    /++
        Partitions five elements by the median satisfying the condition:
        (a <= c && b <= c && c <= d && c <= e)
        Credit: Timon Gehr, "tn", Ivan Kazmenko
    ++/
    void getPivot5(ref T a, ref T b, ref T c, ref T d, ref T e)
    out
    {
        assert(lessEqual(a, c) && lessEqual(b, c) && lessEqual(c, d) && lessEqual(c, e));
    }
    body
    {
        if(less(c, a)) swap(a, c);
        if(less(d, b)) swap(b, d);
        if(less(d, c))
        {
            swap(c, d);
            swap(a, b);
        }
        if(less(e, b)) swap(b, e);
        if(less(e, c))
        {
            swap(c, e);
            if(less(c, a)) swap(a, c);
        } 
        else if(less(c, b)) swap(b, c);
    }
    
    /// Insertion sort is used for sorting small sublists
    void insertionSort(R range)
    {
        size_t lower, upper, center;
        alias gap = center;
        T o;
        for(size_t i = 1; i < range.length; ++i)
        {
            o = range[i];
            lower = 0;
            upper = i;
            
            // Gallop Search
            static if(GALLOP_MODE)
            {
                gap = 1;
                while(gap <= upper)
                {
                    if(less(o, range[upper - gap]))
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
            
            // Binary Search
            while(upper != lower)
            {
                center = (lower + upper) / 2;
                if(less(o, range[center])) upper = center;
                else lower = center + 1;
            }
            for(upper = i; upper > lower; --upper) range[upper] = range[upper-1];
            range[upper] = o;
        }
    }
    
    /// Bottom-up binary heap sort is used to avoid the worst-case of quick sort
    void heapSort(R range)
    {
        // Build Heap
        size_t i = (range.length - 2) / 2 + 1;
        while(i > 0) sift(range, --i, range.length);
        
        // Sort
        i = range.length - 1;
        while(i > 0)
        {
            swap(range[0], range[i]);
            sift(range, 0, i);
            --i;
        }
    }
    
    void sift(R range, size_t parent, immutable size_t end)
    {
        immutable root = parent;
        T value = range[parent];
        size_t child = void;
        
        // Sift down
        while(true)
        {
            child = parent * 2 + 1;
            
            if(child >= end) break;
            
            if(child + 1 < end && less(range[child], range[child + 1])) child += 1;
            
            range[parent] = range[child];
            parent = child;
        }
        
        child = parent;
        
        // Sift up
        while(child > root)
        {
            parent = (child - 1) / 2;
            if(less(range[parent], value))
            {
                range[child] = range[parent];
                child = parent;
            }
            else break;
        }
        
        range[child] = value;
    }
}

unittest
{
    bool testSort(alias pred, R)(R range)
    {
        introSort!(pred, R)(range);
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
        static if(result != 0) pragma(msg, __FILE__, "(", __LINE__, "): Warning: introSort CTFE unittest failed ", result, " of 2 tests");
    }
}