#import <Foundation/Foundation.h>

@interface AITool : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *toolDescription;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, copy) id (^handler)(NSDictionary *args);

+ (instancetype)toolWithName:(NSString *)name
                 description:(NSString *)desc
                  parameters:(NSDictionary *)params
                     handler:(id (^)(NSDictionary *))handler;

+ (NSArray<AITool *> *)allTools;
+ (AITool *)toolNamed:(NSString *)name;
+ (void)registerTool:(AITool *)tool;
+ (void)registerAll;

- (NSDictionary *)openAISchema;

@end
