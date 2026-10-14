#import <Foundation/Foundation.h>

@interface GameFingerprint : NSObject

+ (instancetype)shared;

// Quét 1 lần, cache lại
- (void)scan;

// Tên game (nếu nhận diện được), không thì "Auto"
- (NSString *)detectedGame;

// Tổng hợp signature đặc trưng (dùng để debug)
- (NSDictionary *)fingerprintInfo;

// Trả về method nào CÓ trong game cho khái niệm này
// Ý tưởng: thử từng synonym, cái nào có method tồn tại → trả về
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept
                                         maxResults:(NSInteger)max;

@end
