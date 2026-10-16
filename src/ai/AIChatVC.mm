- (void)sendTapped {
    NSString *text = self.inputField.text;
    if (text.length == 0 || self.isWaiting) return;

    [self.items addObject:@{@"type": @"user", @"text": text}];
    self.inputField.text = @"";
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];

    self.isWaiting = YES;
    self.currentAIResponse = [NSMutableString string];
    self.sendButton.enabled = NO;
    self.sendButton.alpha = 0.5;
    [self.spinner startAnimating];

    NSMutableArray *history = [NSMutableArray array];
    NSInteger maxHistory = 6;
    NSInteger start = MAX(0, (NSInteger)self.items.count - maxHistory);
    for (NSInteger i = start; i < (NSInteger)self.items.count; i++) {
        NSDictionary *item = self.items[i];
        NSString *type = item[@"type"];
        if ([type isEqualToString:@"user"]) {
            [history addObject:@{@"role": @"user", @"content": item[@"text"]}];
        } else if ([type isEqualToString:@"ai"]) {
            [history addObject:@{@"role": @"assistant", @"content": item[@"text"]}];
        }
    }

    NSMutableArray *tools = [NSMutableArray array];
    for (AITool *t in [AITool allTools]) {
        [tools addObject:[t openAISchema]];
    }

    __weak typeof(self) ws = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        NSString *game = @"Unknown";
        @try {
            game = [[GameFingerprint shared] detectedGame];
        } @catch (NSException *e) {
            game = @"Unknown";
        }

        NSString *sysPrompt = [NSString stringWithFormat:
            @"Bạn là AI agent hack game IL2CPP iOS và Reverse Engineer chuyên nghiệp dùng Ghidra.\n"
            @"- Khi cần phân tích mã lệnh tĩnh, dịch ngược hàm hoặc offset, hãy sử dụng tool `analyze_ghidra`.\n"
            @"- Khi người dùng yêu cầu đưa mã qua tab Lua, hãy đặt toàn bộ mã nguồn trong thẻ ```lua ... ```.\n"
            @"- Khi người dùng yêu cầu đưa mã qua tab C++, hãy đặt toàn bộ mã nguồn trong thẻ ```cpp ... ```.\n"
            @"Game hiện tại: %@\n", game];

        NSMutableArray *messages = [NSMutableArray array];
        [messages addObject:@{@"role": @"system", @"content": sysPrompt}];
        [messages addObjectsFromArray:history];

        [[AIProvider shared] sendMessages:messages tools:tools delegate:ws];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (ws.isWaiting) {
            ws.isWaiting = NO;
            ws.sendButton.enabled = YES;
            ws.sendButton.alpha = 1.0;
            [ws.spinner stopAnimating];
            [ws.items addObject:@{@"type": @"error", @"text": @"Timeout 60s"}];
            [ws.tableView reloadData];
            [ws scrollToBottomAnimated:YES];
        }
    });
}
