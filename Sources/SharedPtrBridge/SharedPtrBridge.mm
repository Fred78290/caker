#import "SharedPtrBridge.h"

#ifdef __cplusplus
#include <memory>
#endif

// We treat the incoming pointer as pointing to a std::shared_ptr<void>-compatible layout.
// In practice, we can only safely work with the exact type. Since we don't know T,
// we cast to shared_ptr<const void> which is layout-compatible when the original
// shared_ptr was instantiated with any T*. This is a best-effort, non-portable trick.
// If this assumption doesn't hold in a given context, these functions may return NULL.

const void * SPBGetSharedPtrRawPointer(const void *sharedPtrObjectAddr) {
#ifdef __cplusplus
    if (!sharedPtrObjectAddr) { return nullptr; }
    // Copy the shared_ptr by value so we don't mutate ownership in the caller.
    try {
        const std::shared_ptr<const void> *sp = reinterpret_cast<const std::shared_ptr<const void> *>(sharedPtrObjectAddr);
        if (!sp) { return nullptr; }
        return sp->get();
    } catch (...) {
        return nullptr;
    }
#else
    (void)sharedPtrObjectAddr;
    return NULL;
#endif
}

long SPBGetSharedPtrUseCount(const void *sharedPtrObjectAddr) {
#ifdef __cplusplus
    if (!sharedPtrObjectAddr) { return -1; }
    try {
        const std::shared_ptr<const void> *sp = reinterpret_cast<const std::shared_ptr<const void> *>(sharedPtrObjectAddr);
        if (!sp) { return -1; }
        return static_cast<long>(sp->use_count());
    } catch (...) {
        return -1;
    }
#else
    (void)sharedPtrObjectAddr;
    return -1;
#endif
}
