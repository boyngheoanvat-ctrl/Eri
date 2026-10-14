#import "MetadataParser.h"
#import <mach/mach.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/nlist.h>
#include <string.h>

@implementation MetadataLoadResult
@end

@interface MetadataParser ()
@property (nonatomic, assign) uint8_t *metadataPtr;
@end

@implementation MetadataParser

+ (instancetype)shared {
    static MetadataParser *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MetadataParser alloc] init]; });
    return instance;
}

- (BOOL)autoLoad {
    NSLog(@"[MetadataParser] ===== Auto-load START =====");
    self.result = [[MetadataLoadResult alloc] init];

    uint64_t addr = [self findMetadataViaSymbol];
    if (addr == 0) {
        addr = [self findMetadataViaScan];
    }

    if (addr == 0) {
        self.result.errorMessage = @"Khong tim thay global-metadata.dat trong memory";
        NSLog(@"[MetadataParser] FAIL: %@", self.result.errorMessage);
        return NO;
    }

    NSLog(@"[MetadataParser] Metadata found at 0x%llX", addr);

    Il2CppGlobalMetadataHeader header;
    if (![self readMemory:addr into:&header size:sizeof(header)]) {
        self.result.errorMessage = @"Khong doc duoc header";
        return NO;
    }

    if (header.sanity != IL2CPP_METADATA_MAGIC) {
        NSLog(@"[MetadataParser] Sanity mismatch: 0x%X", header.sanity);
        uint64_t alt = [self findSanityNear:addr];
        if (alt != 0) {
            addr = alt;
            [self readMemory:addr into:&header size:sizeof(header)];
            NSLog(@"[MetadataParser] Retry at 0x%llX: sanity=0x%X", addr, header.sanity);
        }
        if (header.sanity != IL2CPP_METADATA_MAGIC) {
            self.result.errorMessage = [NSString stringWithFormat:
                @"Metadata bi ma hoa (sanity=0x%X)", header.sanity];
            return NO;
        }
    }

    if (header.version < IL2CPP_METADATA_VERSION_MIN ||
        header.version > IL2CPP_METADATA_VERSION_MAX) {
        self.result.errorMessage = [NSString stringWithFormat:
            @"Version khong ho tro: %d", header.version];
        return NO;
    }

    if (header.stringOffset == 0 || header.stringCount == 0 ||
        header.typeDefinitionsOffset == 0 || header.typeDefinitionsCount == 0) {
        self.result.errorMessage = @"Header offsets invalid";
        return NO;
    }

    uint32_t maxSize = [self calculateMetadataSize:&header];
    if (maxSize < 1024) maxSize = 1024 * 1024;

    NSMutableData *data = [NSMutableData dataWithLength:maxSize];
    if (![self readMemory:addr into:data.mutableBytes size:maxSize]) {
        self.result.errorMessage = @"Khong doc duoc toan bo metadata";
        return NO;
    }

    self.metadataData = data;
    self.metadataPtr = (uint8_t *)data.bytes;
    self.header = header;

    self.result.success = YES;
    self.result.addressInMemory = addr;
    self.result.dataSize = maxSize;
    self.result.version = header.version;

    NSLog(@"[MetadataParser] SUCCESS: version=%d, size=%u bytes",
          header.version, maxSize);
    NSLog(@"[MetadataParser] ===== Auto-load END =====");
    return YES;
}

- (uint64_t)findMetadataViaSymbol {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (!strstr(name, "UnityFramework") &&
            !strstr(name, "il2cpp") &&
            !strstr(name, "GameAssembly")) continue;

        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        if (!hdr) continue;

        const uint8_t *base = (const uint8_t *)hdr;
        const uint8_t *cmds = base + sizeof(struct mach_header_64);
        uint32_t off = 0;

        for (uint32_t j = 0; j < hdr->ncmds; j++) {
            const struct load_command *lc =
                (const struct load_command *)(cmds + off);
            if (lc->cmd == LC_SYMTAB) {
                const struct symtab_command *sym =
                    (const struct symtab_command *)lc;
                const struct nlist_64 *nl =
                    (const struct nlist_64 *)(base + sym->symoff);
                const char *strtab = (const char *)(base + sym->stroff);

                for (uint32_t k = 0; k < sym->nsyms; k++) {
                    if (nl[k].n_un.n_strx == 0) continue;
                    const char *nm = strtab + nl[k].n_un.n_strx;

                    if (strstr(nm, "g_GlobalMetadata") ||
                        strstr(nm, "s_GlobalMetadata") ||
                        strstr(nm, "GlobalMetadataHeader")) {

                        uint64_t va = nl[k].n_value + slide;
                        NSLog(@"[MetadataParser] Symbol '%s' @ 0x%llX", nm, va);

                        uint64_t real = 0;
                        if ([self readMemory:va into:&real size:8]) {
                            if (real > 0x100000000 && real < 0x200000000000) {
                                return real;
                            }
                        }

                        Il2CppGlobalMetadataHeader h;
                        if ([self readMemory:va into:&h size:sizeof(h)]) {
                            if (h.sanity == IL2CPP_METADATA_MAGIC) {
                                return va;
                            }
                        }
                    }
                }
            }
            off += lc->cmdsize;
        }
    }
    return 0;
}

- (uint64_t)findMetadataViaScan {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (!strstr(name, "UnityFramework") &&
            !strstr(name, "il2cpp") &&
            !strstr(name, "GameAssembly")) continue;

        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        if (!hdr) continue;

        const uint8_t *base = (const uint8_t *)hdr;
        const uint8_t *cmds = base + sizeof(struct mach_header_64);
        uint32_t off = 0;

        for (uint32_t j = 0; j < hdr->ncmds; j++) {
            const struct load_command *lc =
                (const struct load_command *)(cmds + off);
            if (lc->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *seg =
                    (const struct segment_command_64 *)lc;

                if (seg->filesize == 0) { off += lc->cmdsize; continue; }
                if (seg->vmsize > 1024UL * 1024 * 1024) { off += lc->cmdsize; continue; }

                uint64_t start = seg->vmaddr + slide;
                uint64_t size = seg->vmsize;

                uint64_t found = [self scanRange:start size:size];
                if (found) return found;
            }
            off += lc->cmdsize;
        }
    }
    return 0;
}

- (uint64_t)scanRange:(uint64_t)start size:(uint64_t)size {
    uint8_t page[4096];
    for (uint64_t addr = start; addr < start + size; addr += 4096) {
        if (![self readMemory:addr into:page size:4096]) continue;

        for (size_t i = 0; i < 4096 - 8; i += 4) {
            uint32_t sanity;
            memcpy(&sanity, page + i, 4);
            if (sanity != IL2CPP_METADATA_MAGIC) continue;

            int32_t version;
            memcpy(&version, page + i + 4, 4);
            if (version < IL2CPP_METADATA_VERSION_MIN ||
                version > IL2CPP_METADATA_VERSION_MAX) continue;

            uint64_t foundAddr = addr + i;
            NSLog(@"[MetadataParser] Found candidate @ 0x%llX (v%d)",
                  foundAddr, version);
            return foundAddr;
        }
    }
    return 0;
}

- (uint64_t)findSanityNear:(uint64_t)addr {
    uint64_t start = (addr > 0x100000) ? addr - 0x100000 : addr;
    uint64_t size = 0x200000;
    return [self scanRange:start size:size];
}

- (BOOL)readMemory:(uint64_t)addr into:(void *)buf size:(size_t)size {
    if (!addr || !buf || !size) return NO;
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                          (vm_address_t)addr,
                                          (vm_size_t)size,
                                          (vm_address_t)buf,
                                          &outSize);
    return (kr == KERN_SUCCESS && outSize == size);
}

- (uint32_t)calculateMetadataSize:(Il2CppGlobalMetadataHeader *)h {
    uint32_t max = 0;
    struct { uint32_t off; uint32_t cnt; } pairs[] = {
        { h->stringLiteralOffset, h->stringLiteralCount },
        { h->stringLiteralDataOffset, h->stringLiteralDataCount },
        { h->stringOffset, h->stringCount },
        { h->eventsOffset, h->eventsCount },
        { h->propertiesOffset, h->propertiesCount },
        { h->methodsOffset, h->methodsCount },
        { h->parametersOffset, h->parametersCount },
        { h->fieldsOffset, h->fieldsCount },
        { h->typeDefinitionsOffset, h->typeDefinitionsCount },
        { h->imagesOffset, h->imagesCount },
        { h->assembliesOffset, h->assembliesCount },
    };
    int n = sizeof(pairs) / sizeof(pairs[0]);
    for (int i = 0; i < n; i++) {
        if (pairs[i].off == 0 || pairs[i].cnt == 0) continue;
        uint32_t end = pairs[i].off + pairs[i].cnt;
        if (end > max) max = end;
    }
    return (max + 4095) & ~4095;
}

#pragma mark - Read helpers

- (NSString *)stringAtIndex:(uint32_t)idx {
    if (!self.metadataPtr || !self.metadataData) return nil;
    if (idx >= self.header.stringCount) return nil;

    uint32_t strOffset = self.header.stringOffset + idx;
    if (strOffset >= self.metadataData.length) return nil;

    const char *ptr = (const char *)(self.metadataPtr + strOffset);
    NSUInteger maxLen = self.metadataData.length - strOffset;
    NSUInteger len = strnlen(ptr, maxLen);
    if (len == 0 || len >= maxLen) return nil;

    return [[NSString alloc] initWithBytes:ptr length:len encoding:NSUTF8StringEncoding];
}

- (NSData *)dataAtOffset:(uint32_t)offset length:(uint32_t)length {
    if (!self.metadataData) return nil;
    if (offset + length > self.metadataData.length) return nil;
    return [self.metadataData subdataWithRange:NSMakeRange(offset, length)];
}

- (void)forEachTypeDefinition:(void (^)(uint32_t, Il2CppTypeDefinition))block {
    if (!self.metadataPtr || !block) return;
    if (self.header.typeDefinitionsCount == 0) return;

    size_t defSize = sizeof(Il2CppTypeDefinition);
    uint32_t baseOffset = self.header.typeDefinitionsOffset;
    uint32_t count = self.header.typeDefinitionsCount;

    for (uint32_t i = 0; i < count; i++) {
        uint32_t off = baseOffset + i * defSize;
        if (off + defSize > self.metadataData.length) break;

        Il2CppTypeDefinition def;
        memcpy(&def, self.metadataPtr + off, defSize);
        block(i, def);
    }
}

- (Il2CppMethodDefinition)methodDefinitionAtIndex:(uint32_t)idx {
    Il2CppMethodDefinition def = {0};
    if (!self.metadataPtr) return def;
    size_t sz = sizeof(Il2CppMethodDefinition);
    uint32_t off = self.header.methodsOffset + idx * sz;
    if (off + sz > self.metadataData.length) return def;
    memcpy(&def, self.metadataPtr + off, sz);
    return def;
}

- (Il2CppFieldDefinition)fieldDefinitionAtIndex:(uint32_t)idx {
    Il2CppFieldDefinition def = {0};
    if (!self.metadataPtr) return def;
    size_t sz = sizeof(Il2CppFieldDefinition);
    uint32_t off = self.header.fieldsOffset + idx * sz;
    if (off + sz > self.metadataData.length) return def;
    memcpy(&def, self.metadataPtr + off, sz);
    return def;
}

- (Il2CppImageDefinition)imageDefinitionAtIndex:(uint32_t)idx {
    Il2CppImageDefinition def = {0};
    if (!self.metadataPtr) return def;
    size_t sz = sizeof(Il2CppImageDefinition);
    uint32_t off = self.header.imagesOffset + idx * sz;
    if (off + sz > self.metadataData.length) return def;
    memcpy(&def, self.metadataPtr + off, sz);
    return def;
}

- (Il2CppAssemblyDefinition)assemblyDefinitionAtIndex:(uint32_t)idx {
    Il2CppAssemblyDefinition def = {0};
    if (!self.metadataPtr) return def;
    size_t sz = sizeof(Il2CppAssemblyDefinition);
    uint32_t off = self.header.assembliesOffset + idx * sz;
    if (off + sz > self.metadataData.length) return def;
    memcpy(&def, self.metadataPtr + off, sz);
    return def;
}

@end
