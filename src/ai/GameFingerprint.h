#import <Foundation/Foundation.h>

@interface GameFingerprint : NSObject

+ (instancetype)shared;

- (void)scan;
- (NSString *)detectedGame;
- (NSString *)detectedEntityClass;
- (NSDictionary *)fingerprintInfo;
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept
                                         maxResults:(NSInteger)max;

@end
