#import <Foundation/Foundation.h>

#ifndef ESP_STRUCTS_H
#define ESP_STRUCTS_H

typedef struct Vector3 {
    float x;
    float y;
    float z;
} Vector3;

typedef struct Vector2 {
    float x;
    float y;
} Vector2;

typedef struct Quaternion {
    float x;
    float y;
    float z;
    float w;
} Quaternion;

#endif
