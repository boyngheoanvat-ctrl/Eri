#import <Foundation/Foundation.h>

@interface GameFingerprint : NSObject

+ (instancetype)shared;

// Quét 1 lần, cache lại
- (void)scan;

// Tên game (nếu nhận diện được), không thì "Unknown"
- (NSString *)detectedGame;

// Signature đặc trưng (debug)
- (NSDictionary *)fingerprintInfo;

// Tìm method match concept (map/speed/damage/...)
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept
                                         maxResults:(NSInteger)max;

@end
