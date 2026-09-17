#ifndef SUBSTRATE_H
#define SUBSTRATE_H

#ifdef __cplusplus
extern "C" {
#endif

#import <objc/runtime.h>
#import <objc/message.h>

// Khai báo hàm hook bộ nhớ cốt lõi của MobileSubstrate / Cydia Substrate
void MSHookFunction(void *symbol, void *replace, void **result);

// Khai báo hook Objective-C methods (nếu cần dùng sau này)
void MSHookMessageEx(Class _class, SEL message, IMP replacement, IMP *old);

#ifdef __cplusplus
}
#endif

#endif /* SUBSTRATE_H */
