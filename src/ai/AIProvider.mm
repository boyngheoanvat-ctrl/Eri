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

- (void)sendMessages:(NSArray<NSDictionary *> *)messages
                tools:(NSArray<NSDictionary *> *)tools
             delegate:(id<AIStreamDelegate>)delegate {
    self.cancelled = NO;
    self.toolLoopCount = 0;
    [self sendMessagesInternal:messages tools:tools delegate:delegate];
}

- (void)sendMessagesInternal:(NSArray<NSDictionary *> *)messages
                       tools:(NSArray<NSDictionary *> *)tools
                    delegate:(id<AIStreamDelegate>)delegate {

    if (self.cancelled) return;
    if (!delegate) return;
    if (self.toolLoopCount > kMaxToolLoop) {
        [self callDelegate:delegate error:
            [NSError errorWithDomain:@"AI" code:-10
                userInfo:@{NSLocalizedDescriptionKey: @"AI goi tool qua nhieu lan."}]];
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
        [self callDelegate:delegate error:jsonErr];
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:self.baseURL]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = kRequestTimeout;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey]
        forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = bodyData;

    __weak typeof(self) ws = self;

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        @try {
            if (ws.cancelled) return;

            if (error) {
                [ws callDelegate:delegate error:error];
                return;
            }

            NSInteger status = 0;
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                status = ((NSHTTPURLResponse *)response).statusCode;
            }

            if (!data || data.length == 0) {
                [ws callDelegate:delegate error:
                    [NSError errorWithDomain:@"AI" code:-20
                        userInfo:@{NSLocalizedDescriptionKey:
                            [NSString stringWithFormat:@"Response rong (HTTP %ld)", (long)status]}]];
                return;
            }

            NSError *parseErr = nil;
            id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseErr];
            if (!parsed || parseErr || ![parsed isKindOfClass:[NSDictionary class]]) {
                [ws callDelegate:delegate error:
                    [NSError errorWithDomain:@"AI" code:-21
                        userInfo:@{NSLocalizedDescriptionKey: @"Response khong hop le"}]];
                return;
            }

            NSDictionary *json = (NSDictionary *)parsed;

            if (json[@"error"]) {
                id errObj = json[@"error"];
                NSString *errMsg = @"Unknown error";
                if ([errObj isKindOfClass:[NSDictionary class]]) {
                    id m = errObj[@"message"];
                    if ([m isKindOfClass:[NSString class]]) errMsg = m;
                    else if (m) errMsg = [m description];
                } else if ([errObj isKindOfClass:[NSString class]]) {
                    errMsg = errObj;
                } else if (errObj) {
                    errMsg = [errObj description];
                }
                [ws callDelegate:delegate error:
                    [NSError errorWithDomain:@"AI" code:-22
                        userInfo:@{NSLocalizedDescriptionKey: errMsg}]];
                return;
            }

            NSArray *choices = json[@"choices"];
            if (![choices isKindOfClass:[NSArray class]] || choices.count == 0) {
                [ws callDelegate:delegate error:
                    [NSError errorWithDomain:@"AI" code:-23
                        userInfo:@{NSLocalizedDescriptionKey: @"AI khong tra ve ket qua"}]];
                return;
            }

            id firstChoice = choices[0];
            if (![firstChoice isKindOfClass:[NSDictionary class]]) {
                [ws callDelegate:delegate error:
                    [NSError errorWithDomain:@"AI" code:-26
                        userInfo:@{NSLocalizedDescriptionKey: @"Choice format sai"}]];
                return;
            }

            id messageObj = ((NSDictionary *)firstChoice)[@"message"];
            if (![messageObj isKindOfClass:[NSDictionary class]]) {
                [ws callDelegate:delegate error:
                    [NSError errorWithDomain:@"AI" code:-24
                        userInfo:@{NSLocalizedDescriptionKey: @"Response format sai"}]];
                return;
            }

            NSDictionary *message = (NSDictionary *)messageObj;
            NSArray *toolCalls = message[@"tool_calls"];
            BOOL hasToolCalls = [toolCalls isKindOfClass:[NSArray class]] && toolCalls.count > 0;

            // ============ CÓ TOOL CALLS ============
            if (hasToolCalls) {
                NSMutableArray *toolResults = [NSMutableArray array];

                for (NSDictionary *tc in toolCalls) {
                    if (![tc isKindOfClass:[NSDictionary class]]) continue;

                    id fnObj = tc[@"function"];
                    if (![fnObj isKindOfClass:[NSDictionary class]]) continue;

                    NSString *toolName = ((NSDictionary *)fnObj)[@"name"];
                    NSString *argsJson = ((NSDictionary *)fnObj)[@"arguments"];

                    if (![toolName isKindOfClass:[NSString class]] || toolName.length == 0) continue;

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
                            NSLog(@"[AIProvider] Tool '%@' NSException: %@", toolName, e);
                            result = @{@"error": e.reason ?: @"Tool exception"};
                        } @catch (...) {
                            NSLog(@"[AIProvider] Tool '%@' unknown exception", toolName);
                            result = @{@"error": @"Tool crashed"};
                        }
                    } else {
                        result = @{@"error": [NSString stringWithFormat:@"Tool '%@' khong ton tai", toolName]};
                    }

                    if (!result) result = @{};

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([delegate respondsToSelector:@selector(aiDidCallTool:args:result:)]) {
                            [delegate aiDidCallTool:toolName args:args result:result];
                        }
                    });

                    [toolResults addObject:@{@"tool": toolName, @"result": result}];
                }

                // ===== FORMAT KẾT QUẢ THÀNH TEXT =====
                NSMutableString *answer = [NSMutableString string];

                for (NSDictionary *tr in toolResults) {
                    NSString *tool = tr[@"tool"];
                    id res = tr[@"result"];

                    if (![res isKindOfClass:[NSDictionary class]]) continue;

                    NSDictionary *d = (NSDictionary *)res;

                    if (d[@"error"]) {
                        [answer appendFormat:@"Tool %@ loi: %@\n", tool, d[@"error"]];
                        continue;
                    }

                    if ([tool isEqualToString:@"find_concept"]) {
                        NSArray *results = d[@"results"];
                        NSString *game = d[@"game"] ?: @"Unknown";
                        NSString *entityClass = d[@"entity_class"] ?: @"Unknown";
                        NSString *concept = d[@"concept"] ?: @"";

                        [answer appendFormat:@"Game: %@\n", game];
                        [answer appendFormat:@"Entity class: %@\n", entityClass];

                        if ([results isKindOfClass:[NSArray class]] && results.count > 0) {
                            [answer appendFormat:@"Tim thay %lu method cho '%@':\n",
                                (unsigned long)results.count, concept];

                            NSInteger idx = 0;
                            for (NSDictionary *r in results) {
                                if (idx >= 10) break;
                                [answer appendFormat:@"- %@.%@ (RVA %@)\n",
                                    r[@"class"] ?: @"?",
                                    r[@"method"] ?: @"?",
                                    r[@"rva"] ?: @"?"];
                                idx++;
                            }
                        } else {
                            [answer appendFormat:@"Khong tim thay method cho '%@'.\n", concept];
                            [answer appendString:@"Thu hoi cu the hon: 'hack speed', 'hack hp'...\n"];
                        }
                    }
                    else if ([tool isEqualToString:@"search_classes"]) {
                        NSArray *classes = d[@"classes"];
                        if ([classes isKindOfClass:[NSArray class]] && classes.count > 0) {
                            [answer appendFormat:@"Tim thay %lu class:\n", (unsigned long)classes.count];
                            NSInteger idx = 0;
                            for (NSDictionary *c in classes) {
                                if (idx >= 10) break;
                                [answer appendFormat:@"- %@.%@\n",
                                    c[@"namespace"] ?: @"", c[@"name"] ?: @""];
                                idx++;
                            }
                        } else {
                            [answer appendString:@"Khong tim thay class.\n"];
                        }
                    }
                    else if ([tool isEqualToString:@"dump_class_runtime"]) {
                        [answer appendFormat:@"Class: %@\n", d[@"class"] ?: @""];
                        [answer appendFormat:@"- %@ field, %@ method\n",
                            d[@"field_count"] ?: @0, d[@"method_count"] ?: @0];
                    }
                    else if ([tool isEqualToString:@"find_method_global"]) {
                        NSArray *methods = d[@"methods"];
                        if ([methods isKindOfClass:[NSArray class]] && methods.count > 0) {
                            [answer appendFormat:@"Tim thay %lu method:\n", (unsigned long)methods.count];
                            NSInteger idx = 0;
                            for (NSDictionary *m in methods) {
                                if (idx >= 10) break;
                                [answer appendFormat:@"- %@.%@ (RVA %@)\n",
                                    m[@"class"] ?: @"?",
                                    m[@"method"] ?: @"?",
                                    m[@"rva"] ?: @"?"];
                                idx++;
                            }
                        } else {
                            [answer appendString:@"Khong tim thay method.\n"];
                        }
                    }
                    else if ([tool isEqualToString:@"find_method_in_class"]) {
                        NSArray *methods = d[@"methods"];
                        [answer appendFormat:@"Class: %@\n", d[@"class"] ?: @""];
                        if ([methods isKindOfClass:[NSArray class]] && methods.count > 0) {
                            for (NSDictionary *m in methods) {
                                [answer appendFormat:@"- %@ (RVA %@)\n",
                                    m[@"name"] ?: @"?", m[@"rva"] ?: @"?"];
                            }
                        } else {
                            [answer appendString:@"Khong tim thay method.\n"];
                        }
                    }
                    else if ([tool isEqualToString:@"find_field_in_class"]) {
                        NSArray *fields = d[@"fields"];
                        [answer appendFormat:@"Class: %@\n", d[@"class"] ?: @""];
                        if ([fields isKindOfClass:[NSArray class]] && fields.count > 0) {
                            for (NSDictionary *f in fields) {
                                [answer appendFormat:@"- %@ offset %@\n",
                                    f[@"name"] ?: @"?", f[@"offset"] ?: @"?"];
                            }
                        } else {
                            [answer appendString:@"Khong tim thay field.\n"];
                        }
                    }
                    else if ([tool isEqualToString:@"find_classes_by_method"]) {
                        NSArray *classes = d[@"classes"];
                        [answer appendFormat:@"Method '%@' co trong %lu class:\n",
                            d[@"method"] ?: @"", (unsigned long)classes.count];
                        NSInteger idx = 0;
                        for (NSDictionary *c in classes) {
                            if (idx >= 10) break;
                            [answer appendFormat:@"- %@ (RVA %@)\n",
                                c[@"class"] ?: @"?", c[@"rva"] ?: @"?"];
                            idx++;
                        }
                    }
                    else {
                        NSError *e;
                        NSData *jd = [NSJSONSerialization dataWithJSONObject:d options:0 error:&e];
                        if (jd) {
                            NSString *js = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
                            [answer appendFormat:@"%@: %@\n", tool, js];
                        }
                    }
                }

                if (answer.length == 0) {
                    [answer appendString:@"Da chay tool nhung khong co ket qua."];
                }

                NSString *finalAnswer = [answer copy];

                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([delegate respondsToSelector:@selector(aiStreamDidReceiveText:)]) {
                        [delegate aiStreamDidReceiveText:finalAnswer];
                    }
                    if ([delegate respondsToSelector:@selector(aiStreamDidComplete)]) {
                        [delegate aiStreamDidComplete];
                    }
                });
                return;
            }

            // ============ KHÔNG CÓ TOOL CALLS ============
            NSString *content = message[@"content"];
            if (![content isKindOfClass:[NSString class]] || content.length == 0) {
                content = @"[AI khong tra loi]";
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(aiStreamDidReceiveText:)]) {
                    [delegate aiStreamDidReceiveText:content];
                }
                if ([delegate respondsToSelector:@selector(aiStreamDidComplete)]) {
                    [delegate aiStreamDidComplete];
                }
            });

        } @catch (NSException *e) {
            NSLog(@"[AIProvider] callback NSException: %@", e);
            [ws callDelegate:delegate error:
                [NSError errorWithDomain:@"AI" code:-99
                    userInfo:@{NSLocalizedDescriptionKey:
                        [NSString stringWithFormat:@"Loi xu ly: %@", e.reason]}]];
        } @catch (...) {
            NSLog(@"[AIProvider] callback unknown exception");
            [ws callDelegate:delegate error:
                [NSError errorWithDomain:@"AI" code:-99
                    userInfo:@{NSLocalizedDescriptionKey: @"Loi khong xac dinh"}]];
        }
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
        NSDictionary *wrap = @{@"result": [NSString stringWithFormat:@"%@", obj]};
        NSData *d = [NSJSONSerialization dataWithJSONObject:wrap options:0 error:nil];
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"{}";
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

@end
