
// // the purpose of this function is to copy non-base context data between threads
// // so it's safe to assume that both contexts being used here are identical

// copy_context_additions :: (parent: #Context) {
//     copy_context_additions(*context, parent);
// } @thread

// copy_context_additions :: (current: *#Context, parent: #Context) {
//     info := parent.context_info;

//     context_ptr := cast(*u8) current;
//     parent_ptr := cast(*u8) *parent;

//     for member: info.members {
//         if member.name == "base" {
//             assert(member.offset_in_bytes == 0, "Found base context not where expected.\n");
//             base_runtime_size := member.type.runtime_size;

//             memcpy(context_ptr + base_runtime_size, parent_ptr + base_runtime_size, info.runtime_size - base_runtime_size);
//             return;
//         }
//     }

//     assert(false, "Could not find base context to start the context copy.\n");
// } @thread
