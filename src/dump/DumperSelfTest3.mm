#import "DumperSelfTest3.h"
#import "MetadataParser.h"

@implementation DumperSelfTest3

+ (void)runAll {
    NSLog(@"===== DumperSelfTest3 START =====");

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        MetadataParser *mp = [MetadataParser shared];
        BOOL ok = [mp autoLoad];
        
        if (!ok) {
            NSLog(@"[Test3] FAILED: %@", mp.result.errorMessage);
            NSLog(@"===== DumperSelfTest3 END =====");
            return;
        }
        
        NSLog(@"[Test3] SUCCESS");
        NSLog(@"[Test3]   address: 0x%llX", mp.result.addressInMemory);
        NSLog(@"[Test3]   version: %d", mp.result.version);
        NSLog(@"[Test3]   size: %u bytes", mp.result.dataSize);
        
        NSLog(@"[Test3]   stringCount: %u", mp.header.stringCount);
        NSLog(@"[Test3]   typeDefinitionsCount: %u", mp.header.typeDefinitionsCount);
        NSLog(@"[Test3]   methodsCount: %u", mp.header.methodsCount);
        NSLog(@"[Test3]   fieldsCount: %u", mp.header.fieldsCount);
        NSLog(@"[Test3]   imagesCount: %u", mp.header.imagesCount);
        NSLog(@"[Test3]   assembliesCount: %u", mp.header.assembliesCount);
        
        // In 20 string đầu
        NSLog(@"[Test3] First 20 strings:");
        uint32_t idx = 0;
        uint32_t printed = 0;
        while (idx < mp.header.stringCount && printed < 20) {
            NSString *s = [mp stringAtIndex:idx];
            if (s && s.length > 0) {
                NSLog(@"[Test3]   [%u] %@", idx, s);
                printed++;
            }
            idx++;
        }
        
        // In 10 type đầu
        NSLog(@"[Test3] First 10 types:");
        __block uint32_t count = 0;
        [mp forEachTypeDefinition:^(uint32_t i, Il2CppTypeDefinition def) {
            if (count >= 10) return;
            NSString *name = [mp stringAtIndex:def.nameIndex];
            NSString *ns = [mp stringAtIndex:def.namespaceIndex];
            NSLog(@"[Test3]   [%u] %@.%@ (methods=%u fields=%u)",
                  i, ns ?: @"-", name ?: @"?", def.method_count, def.field_count);
            count++;
        }];
        
        // In 5 images đầu
        NSLog(@"[Test3] First 5 images:");
        for (uint32_t i = 0; i < MIN(mp.header.imagesCount, 5); i++) {
            Il2CppImageDefinition img = [mp imageDefinitionAtIndex:i];
            NSString *name = [mp stringAtIndex:img.nameIndex];
            NSLog(@"[Test3]   [%u] %@ (typeStart=%u typeCount=%u)",
                  i, name ?: @"?", img.typeStart, img.typeCount);
        }
        
        NSLog(@"===== DumperSelfTest3 END =====");
    });
}

@end
