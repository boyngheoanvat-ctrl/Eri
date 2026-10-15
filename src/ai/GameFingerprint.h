#import <Foundation/Foundation.h>

@interface GameFingerprint : NSObject

+ (instancetype)shared;

// Các phương thức được gọi từ AITool
- (NSString *)detectedGame;
- (NSString *)detectedEntityClass;
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults;

// Bộ lọc phương thức
- (NSArray<NSDictionary *> *)filterAndRefineMethods:(NSArray<NSDictionary *> *)rawMethods;

@end
