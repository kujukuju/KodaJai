SerializeStructure :: struct (DataType: Type) {
    hash: SerializedStructureHash;
    data: DataType;
}

SerializedStructureHash :: struct {
    hash: u32;
    size: s64;
}

// checks the hash files against the saved hash to see whether or not the serialized file needs to be updated
read_serialized :: (serialized_path: string, hash_files: [$N] string, $T: Type) -> T, bool {
    // TODO maybe use file mod time
    file, success := read_entire_file(serialized_path, log_errors = false);
    defer free(file);

    // TODO the serializer isn't working for geometries, so ignoring it for now
    success = false;

    if success {
        file_bytes: [] u8;
        file_bytes.data = file.data;
        file_bytes.count = file.count;

        if file_bytes.count < size_of(SerializedStructureHash) {
            empty: T;
            return empty, false;
        }

        cache_hash, cache_size, cache_success := get_hash_from_files(hash_files);
        if !cache_success {
            empty: T;
            return empty, false;
        }

        serialized_hash := deserialize_hash(file_bytes);
        if serialized_hash.hash == cache_hash && serialized_hash.size == cache_size {
            data_bytes: [] u8;
            data_bytes.data = file_bytes.data + size_of(SerializedStructureHash);
            data_bytes.count = file_bytes.count - size_of(SerializedStructureHash);
            
            serialized: T;
            index: int;
            serializer.read(data_bytes, *index, *serialized);

            return serialized, true;
        }
    }

    print("Could not read serialized %.\n", serialized_path);

    empty: T;
    return empty, false;
}

write_serialized :: (serialized_path: string, hash_files: [$N] string, data: $T) {
    cache_hash, cache_size, cache_success := get_hash_from_files(hash_files);
    assert(cache_success, "Could not read hash files for writing serialized data.");

    serialized: SerializeStructure(T);
    serialized.hash = .{cache_hash, cache_size};
    serialized.data = data;

    bytes: [..] u8;
    defer array_free(bytes);
    serializer.write(*bytes, serialized);

    write_entire_file(serialized_path, bytes.data, bytes.count);
}

#scope_file

deserialize_hash :: (bytes: [] u8) -> SerializedStructureHash {
    index: int;

    hash: SerializedStructureHash;
    serializer.read(bytes, *index, *hash);

    return hash;
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
