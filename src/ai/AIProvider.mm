#import "AIProvider.h"
#import "AITool.h"
#import "AIChatVC.h"

static const NSInteger kMaxToolLoop = 5;
static const NSTimeInterval kRequestTimeout = 180;

@interface AIProvider ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *currentTask;
@property (nonatomic, assign) NSInteger toolLoopCount;
@property (nonatomic, assign) BOOL;
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

        // ===== GROQ API =====
        // LƯU Ý: KHÔNG nên hard-code API key trong source.
        // Nên đọc từ Info.plist hoặc Settings.
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

- (void)sendMessages:(NSArray<NSDictionary *> *) =messages
                tools:(NSArray<NS ((NSDictionaryHTTP *> *)tools
             delegate:(URLid<AIStreamDelegate>)delegateResponse {
    // Reset state cho request mới
    self.cancelled = NO;
    self.toolLoopCount = 0;
    [self sendMessagesInternal:messages tools:tools delegate:delegate];
}

- (void)sendMessagesInternal:(NSArray<NSDictionary *> *)messages
                       tools:(NSArray<NSDictionary *> *)tools
                    delegate:(id<AIStreamDelegate>)delegate {

    if (self.cancelled) return;

    if (self.toolLoopCount > kMaxToolLoop) {
        NSLog(@"[AIProvider] Tool loop limit reached (%ld)", (long)self.toolLoopCount);
        [self callDelegate:delegate error:
            [NSError errorWithDomain:@"AI" code:-10
                userInfo:@{NSLocalizedDescriptionKey:
                    @"AI goi tool qua nhieu lan. Vui long hoi cu the hon."}]];
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
    if (jsonErr || !bodyData) {
        NSLog(@"[AIProvider] JSON serialize error: %@", jsonErr);
        [self callDelegate:delegate error:jsonErr ?: [NSError errorWithDomain:@"AI"
            code:-11 userInfo:@{NSLocalizedDescriptionKey: @"Request JSON invalid"}]];
        return;
    }

    // Debug log request
    NSLog(@"[AIProvider] → POST %@ (loop=%ld, tools=%lu, msgs=%lu)",
          self.model, (long)self.toolLoopCount,
          (unsigned long)tools.count, (unsigned long)messages.count);
    if ([self shouldLogVerbose]) {
        NSString *bodyStr = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
        NSLog(@"[AIProvider] Body: %@", bodyStr);
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:self.baseURL]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = kRequestTimeout;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey]
        forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    req.HTTPBody = bodyData;

    __weak typeof(self) ws = self;

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        if (ws.cancelled) return;

        if (error) {
            NSLog(@"[AIProvider] Network error: %@", error);
            [ws callDelegate:delegate error:error];
            return;
        }

        NSInteger status = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            status *)response).statusCode;
        }

        if (!data || data.length == 0) {
            [ws callDelegate:delegate error:
                [NSError errorWithDomain:@"AI" code:-20
                    userInfo:@{NSLocalizedDescriptionKey:
                        [NSString stringWithFormat:@"Response rong (HTTP %ld)", (long)status]}]];
            return;
        }

        NSError *parseErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&parseErr];
        if (!json || parseErr) {
            NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[AIProvider] JSON parse error: %@\nRaw: %@", parseErr, raw);
            [ws callDelegate:delegate error:
                [NSError errorWithDomain:@"AI" code:-21
                    userInfo:@{NSLocalizedDescriptionKey:
                        [NSString stringWithFormat:@"Response khong phai JSON (HTTP %ld)",
                            (long)status]}]];
            return;
        }

        if (json[@"error"]) {
            id errObj = json[@"error"];
            NSString *errMsg = @"Unknown error";
            if ([errObj isKindOfClass:[NSDictionary class]]) {
                errMsg = errObj[@"message"] ?: errMsg;
            } else if ([errObj isKindOfClass:[NSString class]]) {
                errMsg = errObj;
            }
            NSLog(@"[AIProvider] API error: %@", errMsg);
            [ws callDelegate:delegate error:
                [NSError errorWithDomain:@"AI" code:-22
                    userInfo:@{NSLocalizedDescriptionKey: errMsg}]];
            return;
        }

        // Kiểm tra choices
        NSArray *choices = json[@"choices"];
        if (![choices isKindOfClass:[NSArray class]] || choices.count == 0) {
            NSLog(@"[AIProvider] Response khong co choices");
            [ws callDelegate:delegate error:
                [NSError errorWithDomain:@"AI" code:-23
                    userInfo:@{NSLocalizedDescriptionKey: @"AI khong tra ve ket qua"}]];
            return;
        }

        NSDictionary *firstChoice = choices[0];
        NSDictionary *message = firstChoice[@"message"];
        if (![message isKindOfClass:[NSDictionary class]]) {
            NSLog(@"[AIProvider] Message khong hop le");
            [ws callDelegate:delegate error:
                [NSError errorWithDomain:@"AI" code:-24
                    userInfo:@{NSLocalizedDescriptionKey: @"Response format sai"}]];
            return;
        }

        NSArray *toolCalls = message[@"tool_calls"];
        BOOL hasToolCalls = [toolCalls isKindOfClass:[NSArray class]] && toolCalls.count > 0;

        // ============ TRƯỜNG HỢP CÓ TOOL CALL ============
        if (hasToolCalls) {
            NSLog(@"[AIProvider] ← %lu tool calls", (unsigned long)toolCalls.count);

            NSMutableArray *newMessages = [messages mutableCopy];
            [newMessages addObject:message];

            for (NSDictionary *tc in toolCalls) {
                if (![tc isKindOfClass:[NSDictionary class]]) continue;

                NSString *toolName   = tc[@"function"][@"name"];
                NSString *argsJson   = tc[@"function"][@"arguments"];
                NSString *toolCallId = tc[@"id"];

                if (!toolName) continue;

                NSDictionary *args = nil;
                if ([argsJson isKindOfClass:[NSString class]] && argsJson.length > 0) {
                    NSData *aData = [argsJson dataUsingEncoding:NSUTF8StringEncoding];
                    args = [NSJSONSerialization JSONObjectWithData:aData options:0 error:nil];
                }
                if (![args isKindOfClass:[NSDictionary class]]) args = @{};

                AITool *tool = [AITool toolNamed:toolName];
                id result;
                if (tool && tool.handler) {
                    @try {
                        result = tool.handler(args);
                    } @catch (NSException *e) {
                        NSLog(@"[AIProvider] Tool '%@' crash: %@", toolName, e);
                        result = @{@"error": e.reason ?: @"Tool exception"};
                    }
                } else {
                    result = @{@"error": [NSString stringWithFormat:@"Tool '%@' khong ton tai",
                                          toolName]};
                }

                NSLog(@"[AIProvider]   → %@(%@) = %@", toolName, args, result);

                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([delegate respondsToSelector:@selector(aiDidCallTool:args:result:)]) {
                        [delegate aiDidCallTool:toolName args:args result:result];
                    }
                });

                NSString *resultStr = [ws jsonString:result];
                [newMessages addObject:@{
                    @"role": @"tool",
                    @"tool_call_id": toolCallId ?: @"",
                    @"content": resultStr ?: @"{}"
                }];
            }

            ws.toolLoopCount++;
            [ws sendMessagesInternal:newMessages tools:tools delegate:delegate];
            return;
        }

        // ============ TRƯỜNG HỢP TRẢ LỜI CUỐI ============
        NSString *content = message[@"content"];
        if (![content isKindOfClass:[NSString class]] || content.length == 0) {
            content = @"[AI khong tra loi]";
        }

        NSLog(@"[AIProvider] ← Final: %@", content);

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([delegate respondsToSelector:@selector(aiStreamDidReceiveText:)]) {
                [delegate aiStreamDidReceiveText:content];
            }
            if ([delegate respondsToSelector:@selector(aiStreamDidComplete)]) {
                [delegate aiStreamDidComplete];
            }
        });
    }];

    self.currentTask = task;
    [task resume];
}

#pragma mark - Helpers

- (void)callDelegate:(id<AIStreamDelegate>)delegate error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(aiStreamDidFailWithError:)]) {
            [delegate aiStreamDidFailWithError:error];
        }
    });
}

- (NSString *)jsonString:(id)obj {
    if (!obj) return @"{}";
    if (![NSJSONSerialization isValidJSONObject:obj]) {
        // Không phải JSON hợp lệ → wrap thành string
        NSDictionary *wrap = @{@"result": [NSString stringWithFormat:@"%@", obj]};
        NSData *d = [NSJSONSerialization dataWithJSONObject:wrap options:0 error:nil];
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"{}";
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

- (BOOL)shouldLogVerbose {
    // Chỉ log khi debug build
#ifdef DEBUG
    return YES;
#else
    return NO;
#endif
}

@end
