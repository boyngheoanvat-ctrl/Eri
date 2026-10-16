#import "AIProvider.h"
#import "AITool.h"
#import "AIChatVC.h"

static const NSInteger kMaxToolLoop = 3;
static const NSTimeInterval kRequestTimeout = 60;

@interface AIProvider ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *currentTask;
@property (nonatomic, assign) NSInteger toolLoopCount;
@property (nonatomic, assign) BOOL cancelled;
@end

@implementation AIProvider

+ (instancetype)shared {
    static AIProvider *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AIProvider alloc] init];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = kRequestTimeout;
        cfg.timeoutIntervalForResource = kRequestTimeout + 30;
        instance.session = [NSURLSession sessionWithConfiguration:cfg];
        instance.baseURL = @"https://api.groq.com/openai/v1/chat/completions";
        instance.apiKey  = @"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";
        instance.model   = @"openai/gpt-oss-120b";
    });
    return instance;
}

- (void)cancel {
    self.cancelled = YES;
    self.toolLoopCount = 0;
    [self.currentTask cancel];
    self.currentTask = nil;
}

- (void)sendMessages:(NSArray<NSDictionary *> *)messages tools:(NSArray<NSDictionary *> *)tools delegate:(id<AIStreamDelegate>)delegate {
    self.cancelled = NO;
    self.toolLoopCount = 0;
    [self sendMessagesInternal:messages tools:tools delegate:delegate];
}

- (void)sendMessagesInternal:(NSArray<NSDictionary *> *)messages tools:(NSArray<NSDictionary *> *)tools delegate:(id<AIStreamDelegate>)delegate {
    if (self.cancelled || !delegate) return;
    if (self.toolLoopCount > kMaxToolLoop) {
        [self callDelegate:delegate error:[NSError errorWithDomain:@"AI" code:-10 userInfo:@{NSLocalizedDescriptionKey: @"AI gọi tool quá nhiều lần."}]];
        return;
    }

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"model"] = self.model;
    body[@"messages"] = messages;
    body[@"stream"] = @NO;
    body[@"temperature"] = @0.3;

    if (tools.count > 0) {
        body[@"tools"] = tools;
        body[@"tool_choice"] = @"auto";
        body[@"parallel_tool_calls"] = @NO;
    }

    NSError *jsonErr = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonErr];
    if (jsonErr || !bodyData) { [self callDelegate:delegate error:jsonErr]; return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.baseURL]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = kRequestTimeout;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = bodyData;

    __weak typeof(self) ws = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        @autoreleasepool {
            @try {
                if (ws.cancelled) return;
                if (error) { [ws callDelegate:delegate error:error]; return; }
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (json[@"error"]) {
                    [ws callDelegate:delegate error:[NSError errorWithDomain:@"AI" code:-22 userInfo:@{NSLocalizedDescriptionKey: json[@"error"][@"message"] ?: @"Error"}]];
                    return;
                }
                NSArray *choices = json[@"choices"];
                NSDictionary *message = choices[0][@"message"];
                NSString *content = message[@"content"] ?: @"[AI không trả lời]";
                dispatch_async(dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        if ([delegate respondsToSelector:@selector(aiStreamDidReceiveText:)]) [delegate aiStreamDidReceiveText:content];
                        if ([delegate respondsToSelector:@selector(aiStreamDidComplete)]) [delegate aiStreamDidComplete];
                    }
                });
            } @catch (NSException *e) {
                [ws callDelegate:delegate error:[NSError errorWithDomain:@"AI" code:-99 userInfo:@{NSLocalizedDescriptionKey: e.reason ?: @"Lỗi"}]];
            }
        }
    }];
    self.currentTask = task;
    [task resume];
}

- (void)callDelegate:(id<AIStreamDelegate>)delegate error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            if ([delegate respondsToSelector:@selector(aiStreamDidFailWithError:)]) [delegate aiStreamDidFailWithError:error];
        }
    });
}

@end
