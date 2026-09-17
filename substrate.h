// substrate.h - Minimal header for MobileSubstrate
#ifndef SUBSTRATE_H
#define SUBSTRATE_H

#include <stddef.h>
#include <stdint.h>
#include <mach/mach.h>

#ifdef __cplusplus
extern "C" {
#endif

void MSHookFunction(void* symbol, void* replacement, void** storage);
void MSHookMessageEx(void* classPtr, void* selector, void* replacement, void** storage);
void* MSFindSymbol(const char* image, const char* name);

#ifdef __cplusplus
}
#endif

#define %orig   __orig_self
#define %self   __self
#define %hook   __attribute__((used, section("__DATA,__hook")))
#define %ctor   __attribute__((constructor)) static void

#endif // SUBSTRATE_H
