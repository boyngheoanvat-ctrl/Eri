#include <unistd.h>
#import <dlfcn.h>
#include <libgen.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <mach/vm_page_size.h>

// ==================================================
// KHAI BÁO CẤU TRÚC + HÀM DOBBY — SỬA LỖI COMPILE
// ==================================================
typedef struct StaticInlineHookBlock {
    uint64_t hook_vaddr;
    uint32_t hook_size;
    uint32_t patch_size;
    uint32_t patch_hash;
    uint32_t reserved;
    uint64_t code_vaddr;
    uint32_t code_size;
    uint32_t reserved2;
    uint64_t original_vaddr;
    uint64_t patched_vaddr;
    void* target_replace;
} StaticInlineHookBlock;

#ifdef __cplusplus
extern "C" {
#endif

int dobby_create_instrument_bridge(void* target_buf);
bool dobby_static_inline_hook(
    StaticInlineHookBlock* hook,
    StaticInlineHookBlock* hook_va,
    uint64_t func_rva,
    void* func_data,
    uint64_t target_rva,
    void* target_data,
    uint64_t bridge_rva,
    void* patch_bytes,
    uint64_t patch_size
);

#ifdef __cplusplus
}
#endif
// ==================================================

#define DEBUG

#ifdef DEBUG
#define log(...) NSLog(__VA_ARGS__)
#else
#define log(...)
#endif

#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wincomplete-implementation"
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#pragma GCC diagnostic ignored "-W#warnings"
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wformat"
#pragma GCC diagnostic ignored "-Wreorder"
#pragma GCC diagnostic ignored "-Wwritable-strings"
#pragma GCC diagnostic ignored "-Wtrigraphs"

#define STATIC_HOOK_CODEPAGE_SIZE PAGE_SIZE
#define STATIC_HOOK_DATAPAGE_SIZE PAGE_SIZE

uint64_t va2rva(struct mach_header_64* header, uint64_t va)
{
    uint64_t rva = va;
    uint64_t header_vaddr = -1;
    struct load_command* lc = (struct load_command*)((UInt64)header + sizeof(*header));
    for (int i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 * seg = (struct segment_command_64 *)lc;
            if(seg->fileoff==0 && seg->filesize>0) {
                if(header_vaddr != -1) { log(@"multi header mapping! %s", seg->segname); return 0; }
                header_vaddr = seg->vmaddr;
            }
        }
        lc = (struct load_command *) ((char *)lc + lc->cmdsize);
    }
    if(header_vaddr != -1) rva -= header_vaddr;
    return rva;
}

void* rva2data(struct mach_header_64* header, uint64_t rva)
{
    uint64_t header_vaddr = -1;
    struct load_command* lc = (struct load_command*)((UInt64)header + sizeof(*header));
    for (int i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 * seg = (struct segment_command_64 *)lc;
            if(seg->fileoff==0 && seg->filesize>0) {
                if(header_vaddr != -1) { log(@"multi header mapping! %s", seg->segname); return NULL; }
                header_vaddr = seg->vmaddr;
            }
        }
        lc = (struct load_command *) ((char *)lc + lc->cmdsize);
    }
    if(header_vaddr != -1) rva += header_vaddr;
    lc = (struct load_command*)((UInt64)header + sizeof(*header));
    for (int i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 * seg = (struct segment_command_64 *) lc;
            uint64_t seg_vmaddr_start = seg->vmaddr;
            uint64_t seg_vmaddr_end   = seg_vmaddr_start + seg->vmsize;
            if ((uint64_t)rva >= seg_vmaddr_start && (uint64_t)rva < seg_vmaddr_end) {
                uint64_t offset = (uint64_t)rva - seg_vmaddr_start;
                if (offset > seg->filesize) return NULL;
                return (void*)((uint64_t)header + seg->fileoff + offset);
            }
        }
        lc = (struct load_command *) ((char *)lc + lc->cmdsize);
    }
    return NULL;
}

NSMutableData* load_macho_data(NSString* path)
{
    NSMutableData* macho = [NSMutableData dataWithContentsOfFile:path];
    if(!macho) return nil;
    UInt32 magic = *(uint32_t*)macho.mutableBytes;
    if(magic==FAT_CIGAM) {
        struct fat_header* fathdr = (struct fat_header*)macho.mutableBytes;
        struct fat_arch* archdr = (struct fat_arch*)((UInt64)fathdr + sizeof(*fathdr));
        if(NXSwapLong(fathdr->nfat_arch) != 1) { log(@"too many arch!"); return nil; }
        if(NXSwapLong(archdr->cputype) != CPU_TYPE_ARM64) { log(@"arch not support!"); return nil; }
        macho = [NSMutableData dataWithData:[macho subdataWithRange:NSMakeRange(NXSwapLong(archdr->offset), NXSwapLong(archdr->size))]];
    } else if(magic==FAT_CIGAM_64) {
        struct fat_header* fathdr = (struct fat_header*)macho.mutableBytes;
        struct fat_arch_64* archdr = (struct fat_arch_64*)((UInt64)fathdr + sizeof(*fathdr));
        if(NXSwapLong(fathdr->nfat_arch) != 1) return nil;
        if(NXSwapLong(archdr->cputype) != CPU_TYPE_ARM64) return nil;
        macho = [NSMutableData dataWithData:[macho subdataWithRange:NSMakeRange(NXSwapLong(archdr->offset), NXSwapLong(archdr->size))]];
    } else if(magic != MH_MAGIC_64) return nil;
    return macho;
}

NSMutableData* add_hook_section(NSMutableData* macho)
{
    struct mach_header_64* header = (struct mach_header_64*)macho.mutableBytes;
    uint64_t vm_end = 0;
    uint64_t min_section_offset = 0;
    struct segment_command_64* linkedit_seg = NULL;
    struct load_command* lc = (struct load_command*)((UInt64)header + sizeof(*header));
    for (int i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 * seg = (struct segment_command_64 *) lc;
            if(strcmp(seg->segname,SEG_LINKEDIT)==0) linkedit_seg = seg;
            else if(seg->vmsize && vm_end<(seg->vmaddr+seg->vmsize)) vm_end = seg->vmaddr+seg->vmsize;
            struct section_64* sec = (struct section_64*)((uint64_t)seg+sizeof(*seg));
            for(int j=0; j<seg->nsects; j++)
                if(min_section_offset < sec[j].offset) min_section_offset = sec[j].offset;
        }
        lc = (struct load_command *) ((char *)lc + lc->cmdsize);
    }
    if(!min_section_offset || !vm_end || !linkedit_seg) return nil;
    NSRange linkedit_range = NSMakeRange(linkedit_seg->fileoff, linkedit_seg->filesize);
    NSData* linkedit_data = [macho subdataWithRange:linkedit_range];
    [macho replaceBytesInRange:linkedit_range withBytes:nil length:0];

    struct segment_command_64 text_seg = {
        .cmd = LC_SEGMENT_64, .cmdsize=sizeof(struct segment_command_64)+sizeof(struct section_64),
        .segname = {"_PP_OFFSETS"}, .vmaddr = vm_end, .vmsize = STATIC_HOOK_CODEPAGE_SIZE,
        .fileoff = macho.length, .filesize = STATIC_HOOK_CODEPAGE_SIZE,
        .maxprot = VM_PROT_READ|VM_PROT_EXECUTE, .initprot = VM_PROT_READ|VM_PROT_EXECUTE, .nsects = 1
    };
    struct section_64 text_sec = {
        .segname = {"_PP_OFFSETS"}, .sectname = {"_pp_offsets"},
        .addr = text_seg.vmaddr, .size = text_seg.vmsize, .offset = (uint32_t)text_seg.fileoff,
        .flags = S_ATTR_PURE_INSTRUCTIONS|S_ATTR_SOME_INSTRUCTIONS
    };
    struct segment_command_64 data_seg = {
        .cmd = LC_SEGMENT_64, .cmdsize=sizeof(struct segment_command_64)+sizeof(struct section_64),
        .segname = {"_PP_BYTESVA"}, .vmaddr = text_seg.vmaddr+text_seg.vmsize, .vmsize = STATIC_HOOK_CODEPAGE_SIZE,
        .fileoff = text_seg.fileoff+text_seg.filesize, .filesize = STATIC_HOOK_CODEPAGE_SIZE,
        .maxprot = VM_PROT_READ|VM_PROT_WRITE, .initprot = VM_PROT_READ|VM_PROT_WRITE, .nsects = 1
    };
    struct section_64 data_sec = {
        .segname = {"_PP_BYTESVA"}, .sectname = {"_pp_bytesva"},
        .addr = data_seg.vmaddr, .size = data_seg.vmsize, .offset = (uint32_t)data_seg.fileoff
    };

    uint64_t linkedit_cmd_offset = (uint64_t)linkedit_seg - ((uint64_t)header+sizeof(*header));
    unsigned char* cmds = (unsigned char*)malloc(header->sizeofcmds);
    memcpy(cmds, (unsigned char*)header+sizeof(*header), header->sizeofcmds);
    unsigned char* patch = (unsigned char*)header + sizeof(*header) + linkedit_cmd_offset;
    memcpy(patch, &text_seg, sizeof(text_seg)); patch += sizeof(text_seg);
    memcpy(patch, &text_sec, sizeof(text_sec)); patch += sizeof(text_sec);
    memcpy(patch, &data_seg, sizeof(data_seg)); patch += sizeof(data_seg);
    memcpy(patch, &data_sec, sizeof(data_sec)); patch += sizeof(data_sec);
    memcpy(patch, cmds+linkedit_cmd_offset, header->sizeofcmds-linkedit_cmd_offset);
    free(cmds);

    linkedit_seg = (struct segment_command_64*)patch;
    header->ncmds += 2;
    header->sizeofcmds += text_seg.cmdsize + data_seg.cmdsize;
    linkedit_seg->fileoff = macho.length+text_seg.filesize+data_seg.filesize;
    linkedit_seg->vmaddr = vm_end+text_seg.vmsize+data_seg.vmsize;

    struct load_command *load_cmd = (struct load_command *)((uint64_t)header + sizeof(*header));
    uint64_t fixoffset = text_seg.filesize+data_seg.filesize;
    for (int i = 0; i < header->ncmds; i++, load_cmd = (struct load_command *)((uint64_t)load_cmd + load_cmd->cmdsize)) {
        switch (load_cmd->cmd) {
            case LC_DYLD_INFO: case LC_DYLD_INFO_ONLY: {
                struct dyld_info_command *tmp = (struct dyld_info_command *)load_cmd;
                tmp->rebase_off += fixoffset; tmp->bind_off += fixoffset;
                if (tmp->weak_bind_off) tmp->weak_bind_off += fixoffset;
                if (tmp->lazy_bind_off) tmp->lazy_bind_off += fixoffset;
                if (tmp->export_off) tmp->export_off += fixoffset;
            } break;
            case LC_SYMTAB: {
                struct symtab_command *tmp = (struct symtab_command *)load_cmd;
                if (tmp->symoff) tmp->symoff += fixoffset;
                if (tmp->stroff) tmp->stroff += fixoffset;
            } break;
            case LC_DYSYMTAB: {
                struct dysymtab_command *tmp = (struct dysymtab_command *)load_cmd;
                if (tmp->tocoff) tmp->tocoff += fixoffset;
                if (tmp->modtaboff) tmp->modtaboff += fixoffset;
                if (tmp->extrefsymoff) tmp->extrefsymoff += fixoffset;
                if (tmp->indirectsymoff) tmp->indirectsymoff += fixoffset;
                if (tmp->extreloff) tmp->extreloff += fixoffset;
                if (tmp->locreloff) tmp->locreloff += fixoffset;
            } break;
            case LC_FUNCTION_STARTS: case LC_DATA_IN_CODE: case LC_CODE_SIGNATURE:
            case LC_SEGMENT_SPLIT_INFO: case LC_DYLIB_CODE_SIGN_DRS:
            case LC_LINKER_OPTIMIZATION_HINT: case LC_DYLD_EXPORTS_TRIE:
            case LC_DYLD_CHAINED_FIXUPS: {
                struct linkedit_data_command *tmp = (struct linkedit_data_command *)load_cmd;
                if (tmp->dataoff) tmp->dataoff += fixoffset;
            } break;
        }
    }
    if(min_section_offset < (sizeof(struct mach_header_64)+header->sizeofcmds)) return nil;

    unsigned char* codepage = (unsigned char*)malloc(text_seg.vmsize);
    memset(codepage, 0xFF, text_seg.vmsize);
    [macho appendBytes:codepage length:text_seg.vmsize]; free(codepage);
    unsigned char* datapage = (unsigned char*)malloc(data_seg.vmsize);
    memset(datapage, 0, data_seg.vmsize);
    [macho appendBytes:datapage length:data_seg.vmsize]; free(datapage);
    [macho appendData:linkedit_data];
    return macho;
}

bool hex2bytes(char* bytes, unsigned char* buffer) {
    size_t len=strlen(bytes);
    for(int i=0; i<len; i++) {
        char _byte = bytes[i];
        if(_byte>='0'&&_byte<='9') _byte-='0';
        else if(_byte>='a'&&_byte<='f') _byte=_byte-'a'+10;
        else if(_byte>='A'&&_byte<='F') _byte=_byte-'A'+10;
        else return false;
        buffer[i/2] &= (i+1)%2 ? 0x0F : 0xF0;
        buffer[i/2] |= _byte << (((i+1)%2)*4);
    }
    return true;
}

uint64_t calc_patch_hash(uint64_t vaddr, char* patch) {
    return [[[NSString stringWithUTF8String:patch] lowercaseString] hash] ^ vaddr;
}

NSString* Hook1110(char* machoPath, uint64_t vaddr, char* patch)
{
    static NSMutableDictionary* gStaticInlineHookMachO = [[NSMutableDictionary alloc] init];
    NSString* path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[NSString stringWithUTF8String:machoPath]];
    NSString* newPath = gStaticInlineHookMachO[path];
    NSMutableData* macho = newPath ? load_macho_data(newPath) : load_macho_data(path);
    if(!macho) return @"Error: cannot read file";

    uint32_t cryptid = 0;
    struct mach_header_64* header = NULL;
    struct segment_command_64* text_seg = NULL;
    struct segment_command_64* data_seg = NULL;

    while(true) {
        header = (struct mach_header_64*)macho.mutableBytes;
        struct load_command* lc = (struct load_command*)((UInt64)header + sizeof(*header));
        for (int i = 0; i < header->ncmds; i++) {
            if (lc->cmd == LC_SEGMENT_64) {
                struct segment_command_64 * seg = (struct segment_command_64 *) lc;
                if(strcmp(seg->segname,"_PP_OFFSETS")==0) text_seg = seg;
                if(strcmp(seg->segname,"_PP_BYTESVA")==0) data_seg = seg;
            }
            if(lc->cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command_64* info = (struct encryption_info_command_64*)lc;
                if(cryptid==0) cryptid = info->cryptid;
            }
            lc = (struct load_command *) ((char *)lc + lc->cmdsize);
        }
        if(text_seg && data_seg) break;
        macho = add_hook_section(macho);
        if(!macho) return @"Error: add_hook_section failed";
    }
    if(cryptid != 0) return @"Error: App is encrypted";
    if(!text_seg || !data_seg) return @"Error: parse machO failed";

    uint64_t funcRVA = vaddr & ~3ULL;
    void *funcData = rva2data(header, funcRVA);
    if(!funcData) return @"Error: Invalid offset";

    void* patch_bytes = NULL; uint64_t patch_size = 0;
    if(patch && patch[0]) {
        uint64_t patch_end = vaddr + (strlen(patch)+1)/2;
        uint64_t code_end = (patch_end+3) & ~3ULL;
        patch_size = code_end - funcRVA;
        NSMutableData* pb = [[NSMutableData alloc] initWithLength:patch_size];
        patch_bytes = pb.mutableBytes;
        memcpy(patch_bytes, funcData, patch_size);
        if(!hex2bytes(patch, (uint8_t*)patch_bytes + (vaddr & 3))) return @"Error: invalid patch bytes";
    } else if(vaddr & 3) return @"Error: offset not aligned";

    uint64_t targetRVA = va2rva(header, text_seg->vmaddr);
    void* targetData = rva2data(header, targetRVA);
    uint64_t bridgeRVA = targetRVA;
    uint64_t dataRVA = va2rva(header, data_seg->vmaddr);
    void* dataData = rva2data(header, dataRVA);

    StaticInlineHookBlock* hookBlock = (StaticInlineHookBlock*)dataData;
    StaticInlineHookBlock* hookBlockRVA = NULL;
    for(int i=0; i<STATIC_HOOK_CODEPAGE_SIZE/sizeof(StaticInlineHookBlock); i++)
    {
        if(hookBlock[i].hook_vaddr == funcRVA) {
            if(patch && patch[0] && hookBlock[i].patch_hash != calc_patch_hash(vaddr, patch))
                return @"Error: patch hash mismatch";
            return @"Error: already patched";
        }
        if(funcRVA > hookBlock[i].hook_vaddr && hookBlock[i].hook_vaddr != 0 &&
           (funcRVA < hookBlock[i].hook_vaddr + hookBlock[i].hook_size ||
            funcRVA < hookBlock[i].hook_vaddr + hookBlock[i].patch_size))
            return @"Error: offset occupied";
        if(hookBlock[i].hook_vaddr == 0) {
            hookBlock = &hookBlock[i];
            hookBlockRVA = (StaticInlineHookBlock*)(dataRVA + i * sizeof(StaticInlineHookBlock));
            if(i == 0) {
                int codesize = dobby_create_instrument_bridge(targetData);
                targetRVA += codesize;
                targetData = (void*)((uint64_t)targetData + codesize);
            } else {
                StaticInlineHookBlock* prev = hookBlock - 1;
                targetRVA = prev->code_vaddr + prev->code_size;
                targetData = rva2data(header, targetRVA);
            }
            break;
        }
    }
    if(!hookBlockRVA) return @"Error: hook table full";

    if(!dobby_static_inline_hook(hookBlock, hookBlockRVA, funcRVA, funcData,
                                  targetRVA, targetData, bridgeRVA, patch_bytes, patch_size))
        return @"Error: dobby hook failed";

    if(patch && patch[0]) {
        hookBlock->patch_size = patch_size;
        hookBlock->patch_hash = calc_patch_hash(vaddr, patch);
    }

    NSString* savePath = [NSString stringWithFormat:@"%@/Documents/CTDOTECH/%s", NSHomeDirectory(), machoPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:[savePath stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    if(![macho writeToFile:savePath atomically:NO]) return @"Error: write file failed";
    gStaticInlineHookMachO[path] = savePath;
    return [NSString stringWithFormat:@"OK -> %@", savePath];
}

void* find_module_by_path(char* machoPath)
{
    NSString* path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:[NSString stringWithUTF8String:machoPath]];
    for(int i=0; i<_dyld_image_count(); i++) {
        const char* fpath = _dyld_get_image_name(i);
        if([path isEqualToString:@(fpath)])
            return (void*)_dyld_get_image_header(i);
    }
    return NULL;
}

StaticInlineHookBlock* find_hook_block(void* base, uint64_t vaddr)
{
    struct mach_header_64* header = (struct mach_header_64*)base;
    struct segment_command_64 *text_seg=NULL, *data_seg=NULL;
    struct load_command* lc = (struct load_command*)((UInt64)header + sizeof(*header));
    for (int i=0; i<header->ncmds; i++) {
        if(lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (struct segment_command_64*)lc;
            if(strcmp(seg->segname,"_PP_OFFSETS")==0) text_seg=seg;
            if(strcmp(seg->segname,"_PP_BYTESVA")==0) data_seg=seg;
        }
        lc = (struct load_command*)((char*)lc + lc->cmdsize);
    }
    if(!text_seg || !data_seg) return NULL;
    StaticInlineHookBlock* blocks = (StaticInlineHookBlock*)((uint64_t)header + va2rva(header, data_seg->vmaddr));
    for(int i=0; i<STATIC_HOOK_CODEPAGE_SIZE/sizeof(StaticInlineHookBlock); i++)
        if(blocks[i].hook_vaddr == vaddr) return &blocks[i];
    return NULL;
}

void* StaticInlineHookFunction(char* machoPath, uint64_t vaddr, void* replace)
{
    void* base = find_module_by_path(machoPath);
    if(!base) return NULL;
    StaticInlineHookBlock* block = find_hook_block(base, vaddr);
    if(!block) return NULL;
    block->target_replace = replace;
    return (void*)((uint64_t)base + block->original_vaddr);
}

BOOL ActiveCodePatch(char* machoPath, uint64_t vaddr, char* patch)
{
    void* base = find_module_by_path(machoPath);
    if(!base) { NSLog(@"%p: module not found", (void*)vaddr); return NO; }
    StaticInlineHookBlock* block = find_hook_block(base, vaddr & ~3ULL);
    if(!block) { NSLog(@"%p: block not found", (void*)vaddr); return NO; }
    if(block->patch_hash != calc_patch_hash(vaddr, patch)) { NSLog(@"%p: hash mismatch", (void*)vaddr); return NO; }
    block->target_replace = (void*)((uint64_t)base + block->patched_vaddr);
    return YES;
}

BOOL DeactiveCodePatch(char* machoPath, uint64_t vaddr, char* patch)
{
    void* base = find_module_by_path(machoPath);
    if(!base) { NSLog(@"%p: module not found", (void*)vaddr); return NO; }
    StaticInlineHookBlock* block = find_hook_block(base, vaddr & ~3ULL);
    if(!block) { NSLog(@"%p: block not found", (void*)vaddr); return NO; }
    if(block->patch_hash != calc_patch_hash(vaddr, patch)) { NSLog(@"%p: hash mismatch", (void*)vaddr); return NO; }
    block->target_replace = NULL;
    return YES;
}

#define HOOK(x, y, z) \
NSString* _res_##y = Hook1110("Frameworks/UnityFramework.framework/UnityFramework", x, nullptr); \
if (_res_##y) { \
    log(@"Hook %p: %@", (void*)(uintptr_t)x, _res_##y); \
    void* _orig_##y = StaticInlineHookFunction("Frameworks/UnityFramework.framework/UnityFramework", x, (void*)y); \
    *(void**)&z = _orig_##y; \
}
