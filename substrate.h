#ifndef SUBSTRATE_H
#define SUBSTRATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void MSHookFunction(void* symbol, void* replacement, void** storage);
void* MSFindSymbol(const char* image, const char* name);

#ifdef __cplusplus
}
#endif

#endif
