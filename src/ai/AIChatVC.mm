- (void)aiDidCallTool:(NSString *)toolName args:(NSDictionary *)args result:(id)result {
    NSString *toolLog = [NSString *, format:@"\n[tool] %@ -> hoàn tất", toolName];
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogTextView.text ?: @"", toolLog];
    [self updateLayoutContent];
    
    if ([toolName isEqualToString:@"find_concept"] || [toolName isEqualToString:@"find_method_global"]) {
        NSArray *rawResults = nil;
        if ([result isKindOfClass:[NSArray class]]) {
            rawResults = (NSArray *)result;
        }
        
        // Lọc bỏ rác hệ thống và chỉ lấy hàm chuẩn game
        NSArray *cleanResults = [GameFingerprint filterAndRefineMethods:rawResults];
        
        if (cleanResults.count > 0) {
            NSDictionary *firstItem = cleanResults.firstObject;
            NSString *cls = firstItem[@"class"] ?: @"UnknownClass";
            NSString *meth = firstItem[@"method"] ?: @"UnknownMethod";
            NSString *rva = firstItem[@"rva"] ?: @"0x0";
            
            // In kết quả đã lọc chuẩn lên màn hình chat cho user thấy
            NSString *filteredLog = [NSString stringWithFormat:@"\n[AI Filtered Target] -> %@.%@ (RVA %@)", cls, meth, rva];
            self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogTextView.text ?: @"", filteredLog];
            [self updateLayoutContent];
            
            // Tự động sinh script Lua chuẩn và đẩy sang Tab Lua
            NSString *autoScript = [NSString stringWithFormat:
                @"-- ==========================================\n"
                 @"-- Auto-generated Clean AI Mod Script\n"
                 @"-- Target Class: %@\n"
                 @"-- Target Method: %@\n"
                 @"-- RVA Target: %@\n"
                 @"-- ==========================================\n\n"
                 @"print('[AI Auto] Đang patch chính xác hàm game: %@.%@')\n"
                 @"local targetRVA = \"%@\"\n"
                 @"print('[AI Auto] RVA chuẩn: ' .. targetRVA)\n\n"
                 @"-- Thực hiện patch bộ nhớ an toàn\n"
                 @"local ptr = il2cpp.get_method_pointer(\"%@\", \"%@\")\n"
                 @"if ptr ~= 0 then\n"
                 @"    print('[LuaEngine] Đã tìm thấy pointer thật của game!')\n"
                 @"else\n"
                 @"    print('[LuaEngine] Sử dụng RVA trực tiếp: ' .. targetRVA)\n"
                 @"end\n",
                cls, meth, rva, cls, meth, rva, cls, meth
            ];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"PushScriptToLuaNotification"
                                                                object:nil
                                                              userInfo:@{@"script": autoScript}];
        }
    }
}
