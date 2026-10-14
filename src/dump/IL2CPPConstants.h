#ifndef IL2CPPConstants_h
#define IL2CPPConstants_h

#include <stdint.h>

#define IL2CPP_METADATA_MAGIC       0xFAB11BAF
#define IL2CPP_METADATA_VERSION_MIN 24
#define IL2CPP_METADATA_VERSION_MAX 31

typedef enum {
    Il2CppBinaryFormatUnknown = 0,
    Il2CppBinaryFormatMachO,
    Il2CppBinaryFormatELF,
} Il2CppBinaryFormat;

#pragma pack(push, 4)
typedef struct {
    uint32_t sanity;
    int32_t  version;

    uint32_t stringLiteralOffset;
    uint32_t stringLiteralCount;
    uint32_t stringLiteralDataOffset;
    uint32_t stringLiteralDataCount;

    uint32_t stringOffset;
    uint32_t stringCount;

    uint32_t eventsOffset;
    uint32_t eventsCount;

    uint32_t propertiesOffset;
    uint32_t propertiesCount;

    uint32_t methodsOffset;
    uint32_t methodsCount;

    uint32_t parameterDefaultValuesOffset;
    uint32_t parameterDefaultValuesCount;

    uint32_t fieldDefaultValuesOffset;
    uint32_t fieldDefaultValuesCount;

    uint32_t fieldAndParameterDefaultValueDataOffset;
    uint32_t fieldAndParameterDefaultValueDataCount;

    uint32_t fieldMarshaledSizesOffset;
    uint32_t fieldMarshaledSizesCount;

    uint32_t parametersOffset;
    uint32_t parametersCount;

    uint32_t fieldsOffset;
    uint32_t fieldsCount;

    uint32_t genericParametersOffset;
    uint32_t genericParametersCount;

    uint32_t genericParameterConstraintsOffset;
    uint32_t genericParameterConstraintsCount;

    uint32_t genericContainersOffset;
    uint32_t genericContainersCount;

    uint32_t nestedTypesOffset;
    uint32_t nestedTypesCount;

    uint32_t interfacesOffset;
    uint32_t interfacesCount;

    uint32_t vtableMethodsOffset;
    uint32_t vtableMethodsCount;

    uint32_t interfaceOffsetsOffset;
    uint32_t interfaceOffsetsCount;

    uint32_t typeDefinitionsOffset;
    uint32_t typeDefinitionsCount;

    uint32_t imagesOffset;
    uint32_t imagesCount;
    uint32_t assembliesOffset;
    uint32_t assembliesCount;

    uint32_t fieldRefsOffset;
    uint32_t fieldRefsCount;
    uint32_t referencedAssembliesOffset;
    uint32_t referencedAssembliesCount;

    uint32_t attributeDataOffset;
    uint32_t attributeDataCount;
    uint32_t attributeDataRangeOffset;
    uint32_t attributeDataRangeCount;

    uint32_t unresolvedVirtualCallParameterTypesOffset;
    uint32_t unresolvedVirtualCallParameterTypesCount;
} Il2CppGlobalMetadataHeader;
#pragma pack(pop)

#pragma pack(push, 4)
typedef struct {
    uint32_t nameIndex;
    uint32_t namespaceIndex;
    int32_t  byvalTypeIndex;
    int32_t  declaringTypeIndex;
    int32_t  parentIndex;
    int32_t  elementTypeIndex;
    int32_t  genericContainerIndex;
    uint32_t flags;
    uint32_t fieldStart;
    uint32_t methodStart;
    uint32_t eventStart;
    uint32_t propertyStart;
    uint32_t nestedTypesStart;
    uint32_t interfacesStart;
    uint32_t vtableStart;
    uint32_t interfaceOffsetsStart;
    uint16_t method_count;
    uint16_t property_count;
    uint16_t field_count;
    uint16_t event_count;
    uint16_t nested_type_count;
    uint16_t vtable_count;
    uint16_t interfaces_count;
    uint16_t interface_offsets_count;
    uint32_t bitfield;
    uint32_t token;
} Il2CppTypeDefinition;
#pragma pack(pop)

#pragma pack(push, 4)
typedef struct {
    uint32_t nameIndex;
    uint32_t declaringType;
    uint32_t returnType;
    int32_t  parameterStart;
    int32_t  genericContainerIndex;
    uint32_t token;
    uint16_t flags;
    uint16_t iflags;
    uint16_t slot;
    uint16_t parameterCount;
} Il2CppMethodDefinition;
#pragma pack(pop)

#pragma pack(push, 4)
typedef struct {
    uint32_t nameIndex;
    uint32_t typeIndex;
    uint32_t token;
} Il2CppFieldDefinition;
#pragma pack(pop)

#pragma pack(push, 4)
typedef struct {
    uint32_t nameIndex;
    uint32_t assemblyIndex;
    uint32_t typeStart;
    uint32_t typeCount;
    uint32_t exportedTypeStart;
    uint32_t exportedTypeCount;
    uint32_t entryPointIndex;
    uint32_t token;
    uint32_t customAttributeStart;
    uint32_t customAttributeCount;
} Il2CppImageDefinition;
#pragma pack(pop)

#pragma pack(push, 4)
typedef struct {
    uint32_t imageIndex;
    uint32_t token;
    int32_t  referencedAssemblyStart;
    int32_t  referencedAssemblyCount;
    uint32_t aname_nameIndex;
    int32_t  aname_major;
    int32_t  aname_minor;
    int32_t  aname_build;
    int32_t  aname_revision;
    uint32_t aname_publicKeyIndex;
    uint32_t aname_c fixultureIndex;
    uint32_t aname_hash_alg;
    uint32_t aname_hash_len;
    uint32_t aname_flags;
    uint32_t aname_public_key_token[8];
} Il2CppAssemblyDefinition;
#pragma pack(pop)

#endif
