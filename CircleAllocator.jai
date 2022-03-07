// TODO idk if I like this concept enough to keep it

CircleAllocator :: struct (AllocatedType: Type) {
    active: [..] bool;
    allocated: [..] AllocatedType = ---;
    count: int;

    free :: (allocator: CircleAllocator) {
        array_free(allocator.active);
        array_free(allocator.allocated);
    }
}

operator [] :: (allocator: CircleAllocator($T), index: int) -> *T {
    #if DEBUG {
        assert(index >= 0 && index < allocator.active.count);
    }

    if !allocator.active[index] {
        return null;
    }

    return *allocator.allocated[index];
}

for_expansion :: (allocator: *CircleAllocator($T), body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE)); // We don't handle the reverse flag.

    `it_index := 0;
    while it_index < allocator.allocated.count {
        #if flags & .POINTER {
            `it := *allocator.allocated[it_index];
        } else {
            if !allocator.active[it_index] {
                `it_index += 1;
                continue;
            }

            `it := allocator.allocated[it_index];
        }
        
        #insert body;

        // TODO this kind of completely removes the purpose and validity of count, which already seems to be useless tbh
        #if flags & .POINTER {
            allocator.active[it_index] = ifx it == null then false else true;
            allocator.allocated[it_index] = << it;
        }
        
        it_index += 1;
    }
}

// should this allocator empty or undefined?
claim :: (allocator: *CircleAllocator($T)) -> *T {
    entry: T;
    result, index := claim(allocator, entry);
    return result;
}

claim_index :: (allocator: *CircleAllocator($T), entry: T) -> int {
    result, index := claim(allocator, entry);
    return index;
}

claim :: (allocator: *CircleAllocator($T), entry: T) -> *T, int {
    for i: 0..allocator.active.count - 1 {
        if !allocator.active[i] {
            allocator.active[i] = true;
            allocator.allocated[i] = entry;
            return *allocator.allocated[i], i;
        }
    }

    array_add(*allocator.active, true);
    array_add(*allocator.allocated, entry);

    allocator.count += 1;

    return *allocator.allocated[allocator.allocated.count - 1], allocator.allocated.count - 1;
}

free :: (allocator: *CircleAllocator($T), entry: *T) {
    for i: 0..allocator.allocated.count - 1 {
        if !allocator.active[i] {
            continue;
        }

        allocated: *T = *allocator.allocated[i];
        if allocated == entry {
            free(allocator, i);
            return;
        }
    }

    print("Unable to free allocated object. Crashing.\n");
    assert(false);
}

free :: (allocator: *CircleAllocator($T), index: int) {
    assert(allocator.active[index]);

    allocator.active[index] = false;
    allocator.count -= 1;
}

contains :: (allocator: CircleAllocator($T), entry: *T) -> bool {
    for i: 0..allocator.allocated.count - 1 {
        if !allocator.active[i] {
            continue;
        }

        allocated: *T = *allocator.allocated[i];
        if allocated == entry {
            return true;
        }
    }

    return false;
}

#scope_file

#import "Basic";

DEBUG :: true;