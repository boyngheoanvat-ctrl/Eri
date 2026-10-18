#import <Foundation/Foundation.h>
#import "AIChatVC.h"

@interface AIProvider : NSObject

+ (instancetype)shared;

@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *model;

- (void)sendMessages:(NSArray<NSDictionary *> *)messages
                tools:(NSArray<NSDictionary *> *)tools
             delegate:(id<AIStreamDelegate>)delegate;

- (void)cancel;

@end
