#import <Foundation/Foundation.h>
#import "IL2CPPConstants.h"

// Kết quả load metadata
@interface MetadataLoadResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, assign) uint64_t addressInMemory;   // địa chỉ metadata trong memory
@property (nonatomic, assign) uint32_t dataSize;          // size metadata
@property (nonatomic, assign) int32_t version;            // 24/27/29/31
@property (nonatomic, copy)   NSString *errorMessage;
@end

@interface MetadataParser : NSObject

+ (instancetype)shared;

// Kết quả load
@property (nonatomic, strong) MetadataLoadResult *result;

// Metadata bytes trong memory (đã copy ra NSData)
@property (nonatomic, strong) NSData *metadataData;

// Header đã parse
@property (nonatomic, assign) Il2CppGlobalMetadataHeader header;

// Tự động tìm + load metadata từ memory
- (BOOL)autoLoad;

// Read helpers (dùng sau khi load)
- (NSString *)stringAtIndex:(uint32_t)idx;
- (NSData *)dataAtOffset:(uint32_t)offset length:(uint32_t)length;

// Iterate type definitions
- (void)forEachTypeDefinition:(void (^)(uint32_t idx, Il2CppTypeDefinition def))block;

// Lấy method definition
- (Il2CppMethodDefinition)methodDefinitionAtIndex:(uint32_t)idx;
- (Il2CppFieldDefinition)fieldDefinitionAtIndex:(uint32_t)idx;
- (Il2CppImageDefinition)imageDefinitionAtIndex:(uint32_t)idx;
- (Il2CppAssemblyDefinition)assemblyDefinitionAtIndex:(uint32_t)idx;

@end
