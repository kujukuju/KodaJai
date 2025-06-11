
SerializeStructure :: struct (DataType: Type) {
    hash: SerializedStructureHash;
    data: DataType;
}

SerializedStructureHash :: struct {
    hash: u32;
    size: s64;
}

// if you reuse memory you can basically never free it because itll be offset by the hash value
// checks the hash files against the saved hash to see whether or not the serialized file needs to be updated
read_serialized :: (serialized_path: string, hash_files: [$N] string, data: *$T, $reuse_memory: bool = false) -> bool, *void {
    // TODO maybe use file mod time
    file, success := read_entire_file(serialized_path, log_errors = false);
    #if !reuse_memory {
        defer free(file);
        memory: *void = null;
    } else {
        memory: *void = file.data;
    }

    if success {
        file_bytes: [] u8;
        file_bytes.data = file.data;
        file_bytes.count = file.count;

        if file_bytes.count < size_of(SerializedStructureHash) {
            return false, memory;
        }

        #if VALIDATE_SERIALIZED {
            cache_hash, cache_size, cache_success := get_hash_from_files(hash_files);
            if !cache_success {
                return false, memory;
            }

            serialized_hash := deserialize_hash(file_bytes);
            if serialized_hash.hash == cache_hash && serialized_hash.size == cache_size {
                // data_bytes: [] u8;
                // data_bytes.data = file_bytes.data + size_of(SerializedStructureHash);
                // data_bytes.count = file_bytes.count - size_of(SerializedStructureHash);

                serialized: SerializeStructure(T);
                serializer_read(file_bytes, *serialized, 0, reuse_memory);
                data.* = serialized.data;

                return true, memory;
            }
        } else {
            serialized: SerializeStructure(T);
            serializer_read(file_bytes, *serialized, 0, reuse_memory);
            data.* = serialized.data;

            return true, memory;
        }
    }

    print("Could not read serialized %.\n", serialized_path);

    return false, memory;
}

load_serialized :: (serialized_path: string, $T: Type, $reuse_memory: bool = false) -> T, bool, *void {
    data: T;
    success, memory := read_serialized(serialized_path, .[], *data, reuse_memory);

    return data, success, memory;
}

load_serialized :: (serialized_path: string, hash_files: [$N] string, $fallback: (data: $D) -> $T, fallback_data: D, $reuse_memory: bool = false) -> T, bool, *void {
    data: T;
    success, memory := read_serialized(serialized_path, hash_files, *data, reuse_memory);

    if success {
        return data, true, memory;
    }

    #if VALIDATE_SERIALIZED {
        data = fallback(fallback_data);
        write_serialized(serialized_path, hash_files, data, reuse_memory);

        return data, true, null;
    } else {
        return data, false, memory;
    }
}

load_serialized :: (serialized_path: string, hash_files: [$N] string, fallback: () -> $T, $reuse_memory: bool = false) -> T, bool, *void {
    result, success, memory := load_serialized(serialized_path, hash_files, (fallback: () -> T) -> T {
        return fallback();
    }, fallback, reuse_memory);

    return result, success, memory;
}

write_serialized :: (serialized_path: string, hash_files: [$N] string, data: $T, $reuse_memory: bool = false) {
    cache_hash, cache_size, cache_success := get_hash_from_files(hash_files);
    assert(cache_success, "Could not read hash files for writing serialized data.");

    serialized: SerializeStructure(T);
    serialized.hash = .{cache_hash, cache_size};
    serialized.data = data;

    bytes: [..] u8;
    defer array_free(bytes);
    serializer_write(*bytes, serialized, reuse_memory);

    write_entire_file(serialized_path, bytes.data, bytes.count);
}

get_hash_from_files :: (hash_files: [$N] string) -> u32, s64, bool {
    hash_file_data: [N] string;
    defer {
        for data: hash_file_data {
            if data free(data);
        }
    }

    for hash_path, hash_index: hash_files {
        success: bool;
        hash_file_data[hash_index], success = read_entire_file(hash_path);
        if !success {
            return 0, 0, false;
        }
    }

    cache_hash: u32;
    cache_size: s64;
    for hash_data: hash_file_data {
        hash_file_bytes: [] u8;
        hash_file_bytes.data = hash_data.data;
        hash_file_bytes.count = hash_data.count;

        cache_hash ^= get_hash(hash_file_bytes);
        cache_size ^= hash_file_bytes.count;
    }

    return cache_hash, cache_size, true;
}

#scope_file

deserialize_hash :: (bytes: [] u8) -> SerializedStructureHash {
    index: int;

    hash: SerializedStructureHash;
    hash = (cast(*SerializedStructureHash) bytes.data).*;

    return hash;
}
