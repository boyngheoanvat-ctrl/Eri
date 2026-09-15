#pragma once
#include <functional>
#include "../il2cpp/il2cpp-object-internals.h"
namespace il2cpp { namespace gc {
    class GarbageCollector {
    public:
        static void ForEachHeapObject(std::function<void(Il2CppObject*)> callback);
    };
}}
