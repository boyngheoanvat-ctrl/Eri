#ifndef ESPStructs_h
#define ESPStructs_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Vector3 {
    float x;
    float y;
    float z;
} Vector3;

typedef struct Vector2 {
    float x;
    float y;
} Vector2;

#ifdef __cplusplus
}
#endif

#endif
