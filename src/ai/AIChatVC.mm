#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"

@interface AIChatVC () <AIStreamDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *chatScrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextView *chatLogTextView;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UIButton *sendButton;

@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    
    CGRect bounds = self.view.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
    // 1. Khung chứa input và nút gửi ở đáy (chiều cao 50px)
    CGFloat bottomBarHeight = 50;
    CGFloat inputHeight = 36;
    
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, height - bottomBarHeight, width, bottomBarHeight)];
    bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    bottomBar.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.20 alpha:1.0];
    [self.view addSubview:bottomBar];
    
    // 2. Nút Send đặt ở góc phải của bottomBar (chiều rộng 60px, cách lề phải 10px)
    CGFloat sendBtnWidth = 60;
    CGFloat padding = 10;
    
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(width - sendBtnWidth - padding, (bottomBarHeight - inputHeight) / 2, sendBtnWidth, inputHeight);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    self.sendButton.layer.cornerRadius = 6;
    self.sendButton.layer.masksToBounds = YES;
    [self.sendButton addTarget:self action:@selector(didTapSend) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:self.sendButton];
    
    // 3. Ô nhập liệu (inputTextView) nằm bên trái nút Send, cách lề trái 10px
    CGFloat inputWidth = width - sendBtnWidth - (padding * 3);
    self.inputTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, (bottomBarHeight - inputHeight) / 2, inputWidth, inputHeight)];
    self.inputTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.inputTextView.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.28 alpha:1.0];
    self.inputTextView.textColor = [UIColor whiteColor];
    self.inputTextView.font = [UIFont systemFontOfSize:14];
    self.inputTextView.layer.cornerRadius = 6;
    self.inputTextView.layer.masksToBounds = YES;
    self.inputTextView.delegate = self;
    [bottomBar addSubview:self.inputTextView];
    
    // 4. UIScrollView hiển thị nội dung chat phía trên bottomBar
    CGFloat scrollHeight = height - bottomBarHeight;
    self.chatScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, scrollHeight)];
    self.chatScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.chatScrollView];
    
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, scrollHeight)];
    [self.chatScrollView addSubview:self.contentView];
    
    // 5. TextView chứa lịch sử chat
    self.chatLogTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, width - 20, scrollHeight - 20)];
    self.chatLogTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.chatLogTextView.editable = NO;
    self.chatLogTextView.scrollEnabled = NO;
    self.chatLogTextView.backgroundColor = [UIColor clearColor];
    self.chatLogTextView.textColor = [UIColor whiteColor];
    self.chatLogTextView.font = [UIFont systemFontOfSize:13];
    self.chatLogTextView.text = @"[ai] AI Agent ready.\nHoi: hack map, hack speed, tim class...\n";
    [self.contentView addSubview:self.chatLogTextView];
    
    [self updateLayoutContent];
}

- (void)reload {
    [self.view setNeedsLayout];
    [self.contentView setNeedsLayout];
}

#pragma mark - Actions & Logic

- (void)didTapSend {
    NSString *text = [self.inputTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    self.inputTextView.text = @"";
    
    // Hiển thị câu hỏi của user lên khung chat
    NSString *current = self.chatLogTextView.text ?: @"";
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n> %@", current, text];
    [self updateLayoutContent];
    
    // Gửi yêu cầu qua AIProvider
    NSArray *messages = @[@{@"role": @"user", @"content": text}];
    NSArray *tools = @[[[AITool toolNamed:@"find_concept"] openAISchema],
                       [[AITool toolNamed:@"search_classes"] openAISchema],
                       [[AITool toolNamed:@"dump_class_runtime"] openAISchema],
                       [[AITool toolNamed:@"find_method_global"] openAISchema]];
                       
    [[AIProvider shared] sendMessages:messages tools:tools delegate:self];
}

- (void)updateLayoutContent {
    CGSize size = [self.chatLogTextView sizeThatFits:CGSizeMake(self.chatScrollView.bounds.size.width - 20, CGFLOAT_MAX)];
    CGFloat newHeight = MAX(size.height + 20, self.chatScrollView.bounds.size.height);
    
    CGRect frame = self.chatLogTextView.frame;
    frame.size.height = MAX(size.height, self.chatScrollView.bounds.size.height - 20);
    self.chatLogTextView.frame = frame;
    
    self.contentView.frame = CGRectMake(0, 0, self.chatScrollView.bounds.size.width, newHeight);
    self.chatScrollView.contentSize = CGSizeMake(self.chatScrollView.bounds.size.width, newHeight);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:YES];
    });
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    UIScrollView *scrollView = self.chatScrollView;
    if (!scrollView) return;
    
    CGFloat bottomOffset = scrollView.contentSize.height - scrollView.bounds.size.height;
    if (bottomOffset > 0) {
        [scrollView setContentOffset:CGPointMake(0, bottomOffset) animated:animated];
    }
}

#pragma mark - AIStreamDelegate

- (void)aiStreamDidReceiveText:(NSString *)text {
    NSString *current = self.chatLogTextView.text ?: @"";
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", current, text];
    [self updateLayoutContent];
}

- (void)aiStreamDidComplete {
    [self updateLayoutContent];
}

- (void)aiStreamDidFailWithError:(NSError *)error {
    NSString *errStr = [NSString stringWithFormat:@"\n[Lỗi] %@", error.localizedDescription];
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogTextView.text ?: @"", errStr];
    [self updateLayoutContent];
}

- (void)aiDidCallTool:(NSString *)toolName args:(NSDictionary *)args result:(id)result {
    NSString *toolLog = [NSString stringWithFormat:@"\n[tool] %@ -> hoàn tất", toolName];
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n%@", self.chatLogTextView.text ?: @"", toolLog];
    [self updateLayoutContent];
}

@end
