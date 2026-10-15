#import "AIChatVC.h"
#import "AIProvider.h"
#import "AITool.h"
#import "ToolTheme.h"

@interface AIChatVC () <AIStreamDelegate, UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *chatScrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextView *chatLogTextView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UITextView *inputTextView;
@property (nonatomic, strong) UIButton *sendButton;

@end

@implementation AIChatVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
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
    self.chatLogTextView.text = @"[ai] AI Agent ready.\nHoi: hack map, hack speed, tim class...\n";
    [self.contentView addSubview:self.chatLogTextView];
    
    [self updateLayoutContent];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
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
    
    NSString *current = self.chatLogTextView.text ?: @"";
    self.chatLogTextView.text = [NSString stringWithFormat:@"%@\n> %@", current, text];
    [self updateLayoutContent];
    
    [AITool registerAll];
    
    NSMutableArray *tools = [NSMutableArray array];
    NSArray *toolNames = @[@"find_concept", @"search_classes", @"dump_class_runtime", @"find_method_global"];
    for (NSString *name in toolNames) {
        AITool *t = [AITool toolNamed:name];
        if (t) {
            NSDictionary *schema = [t openAISchema];
            if (schema) {
                [tools addObject:schema];
            }
        }
    }
    
    NSArray *messages = @[@{@"role": @"user", @"content": text}];
    [[AIProvider shared] sendMessages:messages tools:tools delegate:self];
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
