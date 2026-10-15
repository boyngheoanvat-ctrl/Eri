#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"
#import "ToolTheme.h"
#import "GameFingerprint.h"

@interface AIChatVC () <AIStreamDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *chatScrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextView *chatLogTextView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSMutableArray<NSString *> *chatHistory;

@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.chatHistory = [NSMutableArray array];
    
    CGRect bounds = self.view.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
    CGFloat bottomBarHeight = 50;
    CGFloat inputHeight = 36;
    
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, height - bottomBarHeight, width, bottomBarHeight)];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.bottomBar.backgroundColor = [ToolTheme shared].surface;
    [self.view addSubview:self.bottomBar];
    
    CGFloat sendBtnWidth = 60;
    CGFloat padding = 10;
    
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(width - sendBtnWidth - padding, (bottomBarHeight - inputHeight) / 2, sendBtnWidth, inputHeight);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [ToolTheme shared].accent;
    self.sendButton.layer.cornerRadius = 6;
    self.sendButton.layer.masksToBounds = YES;
    [self.sendButton addTarget:self action:@selector(didTapSend) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.sendButton];
    
    CGFloat inputWidth = width - sendBtnWidth - (padding * 3);
    self.inputTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, (bottomBarHeight - inputHeight) / 2, inputWidth, inputHeight)];
    self.inputTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.inputTextView.backgroundColor = [ToolTheme shared].background;
    self.inputTextView.textColor = [ToolTheme shared].textPrimary;
    self.inputTextView.font = [UIFont systemFontOfSize:14];
    self.inputTextView.layer.cornerRadius = 6;
    self.inputTextView.layer.masksToBounds = YES;
    self.inputTextView.delegate = self;
    [self.bottomBar addSubview:self.inputTextView];
    
    CGFloat scrollHeight = height - bottomBarHeight;
    self.chatScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, scrollHeight)];
    self.chatScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.chatScrollView];
    
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, scrollHeight)];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.chatScrollView addSubview:self.contentView];
    
    self.chatLogTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, width - 20, scrollHeight - 20)];
    self.chatLogTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.chatLogTextView.editable = NO;
    self.chatLogTextView.scrollEnabled = NO;
    self.chatLogTextView.backgroundColor = [UIColor clearColor];
    self.chatLogTextView.textColor = [ToolTheme shared].textPrimary;
    self.chatLogTextView.font = [UIFont systemFontOfSize:13];
    self.chatLogTextView.text = @"[AI Agent] Sẵn sàng phân tích ngữ cảnh đa game...\nHỏi: hack map, camera xa, speed...\n";
    [self.contentView addSubview:self.chatLogTextView];
    
    [self updateLayoutContent];
}

- (void)didTapSend {
    NSString *text = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    self.inputTextView.text = @"";
    [self.chatHistory addObject:text];
    
    NSString *current = self.chatLogTextView.text ?: @"";
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n> %@", current, text];
    [self updateLayoutContent];
    
    NSArray<NSDictionary *> *foundMethods = [[GameFingerprint shared] findMethodsForConcept:text maxResults:5];
    
    if (foundMethods.count > 0) {
        NSMutableString *resultLog = [NSMutableString stringWithString:@"\n[AI Analysis] Tìm thấy phương thức khớp:\n"];
        for (NSDictionary *m in foundMethods) {
            [resultLog appendFormat:@"- %@.%@ (RVA %@)\n", m[@"class"], m[@"method"], m[@"rva"]];
        }
        self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogTextView.text, resultLog];
        [self updateLayoutContent];
        [self checkAndPushScriptToLua];
    } else {
        self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n[AI] Không tìm thấy RVA phù hợp cho yêu cầu này.", self.chatLogTextView.text];
        [self updateLayoutContent];
    }
}

- (void)updateLayoutContent {
    CGFloat currentWidth = self.chatScrollView.bounds.size.width;
    if (currentWidth <= 0) currentWidth = self.view.bounds.size.width;
    
    CGSize size = [self.chatLogTextView sizeThatFits:CGSizeMake(currentWidth - 20, CGFLOAT_MAX)];
    CGFloat newHeight = MAX(size.height + 20, self.chatScrollView.bounds.size.height);
    
    CGRect frame = self.chatLogTextView.frame;
    frame.size.width = currentWidth - 20;
    frame.size.height = MAX(size.height, self.chatScrollView.bounds.size.height - 20);
    self.chatLogTextView.frame = frame;
    
    self.contentView.frame = CGRectMake(0, 0, currentWidth, newHeight);
    self.chatScrollView.contentSize = CGSizeMake(currentWidth, newHeight);
}

- (void)checkAndPushScriptToLua {
    NSString *chatText = self.chatLogTextView.text;
    if (chatText.length == 0) return;
    
    // Tách lấy ý định và khối phản hồi mới nhất tại câu hỏi hiện tại
    NSArray *components = [chatText componentsSeparatedByString:@"> "];
    NSString *latestQuery = [components.lastObject lowercaseString] ?: @"";
    NSString *latestResponse = components.lastObject ?: chatText;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"-\\s*([a-zA-Z0-9_.]+)\\.([a-zA-Z0-9_]+)\\s*\\(RVA\\s+(0x[a-fA-F0-9]+)\\)" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:latestResponse options:0 range:NSMakeRange(0, latestResponse.length)];
    
    if (matches.count > 0) {
        NSTextCheckingResult *selectedMatch = matches.firstObject;
        
        // Khớp thông minh RVA dựa đúng vào từ khóa của câu lệnh hiện tại (Hỗ trợ chuyển game linh hoạt)
        for (NSTextCheckingResult *m in matches) {
            NSString *fullMatchStr = [latestResponse substringWithRange:m.range];
            if ([latestQuery containsString:@"camera"] && ([fullMatchStr containsString:@"FOV"] || [fullMatchStr containsString:@"Camera"])) {
                selectedMatch = m;
                break;
            } else if ([latestQuery containsString:@"map"] && ([fullMatchStr containsString:@"CanSight"] || [fullMatchStr containsString:@"IsVisible"])) {
                selectedMatch = m;
                break;
            } else if ([latestQuery containsString:@"speed"] && [fullMatchStr containsString:@"Speed"]) {
                selectedMatch = m;
                break;
            }
        }
        
        NSString *cls = [latestResponse substringWithRange:[selectedMatch rangeAtIndex:1]];
        NSString *meth = [latestResponse substringWithRange:[selectedMatch rangeAtIndex:2]];
        NSString *rva = [latestResponse substringWithRange:[selectedMatch rangeAtIndex:3]];
        
        NSString *autoScript = [NSString stringWithFormat:
            @"-- ==========================================\n"
             @"-- AI Dynamic Multi-Game Mod Script\n"
             @"-- Target: %@.%@\n"
             @"-- RVA: %@\n"
             @"-- ==========================================\n\n"
             @"print('[AI Dynamic] Nạp đúng RVA theo ngữ cảnh: %@.%@ -> %@')\n"
             @"local targetRVA = \"%@\"\n\n"
             @"if il2cpp.patch_memory then\n"
             @"    il2cpp.patch_memory(targetRVA, \"20008052C0035FD6\")\n"
             @"    print('[LuaEngine] Patch RAM thành công cho game hiện tại!')\n"
             @"else\n"
             @"    print('[LuaEngine] Target RVA: ' .. targetRVA)\n"
             @"end\n",
            cls, meth, rva, cls, meth, rva, rva
        ];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"PushScriptToLuaNotification"
                                                                object:nil
                                                              userInfo:@{@"script": autoScript}];
        });
    }
}

@end
