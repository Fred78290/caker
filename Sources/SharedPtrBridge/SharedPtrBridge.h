#ifndef SharedPtrBridge_h
#define SharedPtrBridge_h

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Extract the raw pointer managed by a std::shared_ptr<T> whose address is passed as void*.
// The argument must be a pointer to the std::shared_ptr<T> object (not the managed T*).
// Returns the underlying T* as a const void* (may be NULL).
const void * SPBGetSharedPtrRawPointer(const void *sharedPtrObjectAddr);

// Optionally, return the use_count of the shared_ptr if available; returns -1 on failure.
long SPBGetSharedPtrUseCount(const void *sharedPtrObjectAddr);

#ifdef __cplusplus
}
#endif

#endif /* SharedPtrBridge_h */
