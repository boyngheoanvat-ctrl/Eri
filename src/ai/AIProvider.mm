#import "AIProvider.h"
#import "AITool.h"
#import "AIChatVC.h"

@interface AIProvider ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) NSInteger toolLoopCount;
@end

@implementation AIProvider

+ (instancetype)shared {
    static AIProvider *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AIProvider alloc] init];
        instance.session = [NSURLSession sessionWithConfiguration:
            [NSURLSessionConfiguration defaultSessionConfiguration]];

        // ===== GROQ API =====
        instance.baseURL = @"https://api.groq.com/openai/v1/chat/completions";
        instance.apiKey = @"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";
        instance.model = @"openai/gpt-oss-120b";
    });
    return instance;
}

- (void)sendMessages:(NSArray<NSDictionary *> *)messages
                tools:(NSArray<NSDictionary *> *)tools
             delegate:(id<AIStreamDelegate>)delegate {

    if (self.toolLoopCount > 5) {
        self.toolLoopCount = 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([delegate respondsToSelector:@selector(aiStreamDidFailWithError:)]) {
                [delegate aiStreamDidFailWithError:[NSError errorWithDomain:@"AI" code:-1
                    userInfo:@{NSLocalizedDescriptionKey: @"Tool loop limit"}]];
            }
        });
        return;
    }

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"model"] = self.model;
    body[@"messages"] = messages;
    body[@"stream"] = @NO;

    if (tools.count > 0) {
        body[@"tools"] = tools;
        body[@"tool_choice"] = @"auto";
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:self.baseURL]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 180;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey]
        forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    __weak typeof(self) ws = self;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(aiStreamDidFailWithError:)]) {
                    [delegate aiStreamDidFailWithError:error ?: [NSError errorWithDomain:@"AI"
                        code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Network error"}]];
                }
            });
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!json) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate aiStreamDidFailWithError:[NSError errorWithDomain:@"AI" code:-1
                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid response"}]];
            });
            return;
        }

        if (json[@"error"]) {
            NSString *errMsg = json[@"error"][@"message"] ?: @"Unknown error";
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate aiStreamDidFailWithError:[NSError errorWithDomain:@"AI" code:-2
                    userInfo:@{NSLocalizedDescriptionKey: errMsg}]];
            });
            return;
        }

        NSDictionary *message = json[@"choices"][0][@"message"];
        if (!message) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate aiStreamDidFailWithError:[NSError errorWithDomain:@"AI" code:-3
                    userInfo:@{NSLocalizedDescriptionKey: @"No message"}]];
            });
            return;
        }

        NSArray *toolCalls = message[@"tool_calls"];

        if (toolCalls.count > 0) {
            NSMutableArray *newMessages = [messages mutableCopy];
            [newMessages addObject:message];

            for (NSDictionary *tc in toolCalls) {
                NSString *toolName = tc[@"function"][@"name"];
                NSString *argsJson = tc[@"function"][@"arguments"];
                NSString *toolCallId = tc[@"id"];

                NSDictionary *args = nil;
                if (argsJson.length > 0) {
                    args = [NSJSONSerialization JSONObjectWithData:
                        [argsJson dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                }

                AITool *tool = [AITool toolNamed:toolName];
                id result = tool && tool.handler ? tool.handler(args ?: @{}) : @{@"error": @"Tool not found"};

                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([delegate respondsToSelector:@selector(aiDidCallTool:args:result:)]) {
                        [delegate aiDidCallTool:toolName args:args ?: @{} result:result];
                    }
                });

                NSString *resultStr = [ws jsonString:result];
                [newMessages addObject:@{
                    @"role": @"tool",
                    @"tool_call_id": toolCallId ?: @"",
                    @"content": resultStr
                }];
            }

            ws.toolLoopCount++;
            [ws sendMessages:newMessages tools:tools delegate:delegate];
            return;
        }

        ws.toolLoopCount = 0;
        NSString *content = message[@"content"] ?: @"[AI khong tra loi]";

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([delegate respondsToSelector:@selector(aiStreamDidReceiveText:)]) {
                [delegate aiStreamDidReceiveText:content];
            }
            if ([delegate respondsToSelector:@selector(aiStreamDidComplete)]) {
                [delegate aiStreamDidComplete];
            }
        });
    }] resume];
}

- (NSString *)jsonString:(id)obj {
    if ([NSJSONSerialization isValidJSONObject:obj]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
    }
    return [NSString stringWithFormat:@"%@", obj];
}

- (void)cancel {
    self.toolLoopCount = 0;
}

@end
