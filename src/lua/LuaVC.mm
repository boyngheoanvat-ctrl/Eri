#import "LuaVC.h"
#import "ToolTheme.h"

@interface LuaVC () <UITextViewDelegate>
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *statusBar;
@property (nonatomic, UIButton *clearButton;
@property (nonatomic, strong) UITextView *editorTextView;
@property (nonatomic, strong) UITextView *outputTextView;
@end

@implementation LuaVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self setupLayout];
}

- (void)setupLayout {
    CGFloat totalW = CGRectGetWidth(self.view.bounds);
    CGFloat totalH = CGRectGetHeight(self.view.bounds);
    if (totalW <= 50) totalW = 450;
    if (totalH <= 50) totalH = 300;
    
    // 1. Header View chứa thanh trạng thái và nút Clear (Cố định chiều cao 36px)
    CGFloat headerH = 36;
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(12, 10, totalW - 24, headerH)];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.headerView];
    
    CGFloat headerW = CGRectGetWidth(self.headerView.bounds);
    CGFloat rightButtonW = 84;
    CGFloat spacing = 8;
    CGFloat barW = headerW - rightButtonW - spacing;
    
    // Thanh trạng thái / Progress bar bên trái
    self.statusBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, barW, headerH)];
    self.statusBar.backgroundColor = [UIColor colorWithRed:0.20 green:0.60 blue:0.40 alpha:1.0];
    self.statusBar.layer.cornerRadius = 6;
    self.statusBar.clipsToBounds = YES;
    self.statusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    [self.headerView addSubview:self.statusBar];
    
    // Nút Clear nằm gọn bên phải, KHÔNG BAO GIỜ bị tràn
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(headerW - rightButtonW, 0, rightButtonW, headerH);
    clearBtn.backgroundColor = [ToolTheme shared].surfaceAlt;
    [clearBtn setTitle:@"Clear" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    clearBtn.layer.cornerRadius = 6;
    clearBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [clearBtn addTarget:self action:@selector(didTapClear) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:clearBtn];
    
    // 2. Editor TextView (Nhập script Lua & ImGui)
    CGFloat editorY = 10 + headerH + 10;
    CGFloat editorH = (totalH - editorY - 140) / 2;
    if (editorH < 80) editorH = 80;
    
    UILabel *editorTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, editorY - 18, totalW - 24, 16)];
    editorTitle.text = @"EDITOR (LUA & IMGUI SCRIPT)";
    editorTitle.textColor = [ToolTheme shared].textMuted;
    editorTitle.font = [[ToolTheme shared] monoBoldFont:10];
    editorTitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:editorTitle];
    
    self.editorTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, editorY, totalW - 24, editorH)];
    self.editorTextView.backgroundColor = [ToolTheme shared].surface;
    self.editorTextView.textColor = [ToolTheme shared].textPrimary;
    self.editorTextView.font = [[ToolTheme shared] monoFont:12];
    self.editorTextView.layer.cornerRadius = 6;
    self.editorTextView.layer.borderWidth = 1;
    self.editorTextView.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.editorTextView.text = @"-- Lua Script with ImGui Menu\nprint(\"Eri Lua & ImGui Ready!\")";
    self.editorTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.editorTextView];
    
    // 3. Console Output TextView
    CGFloat outputY = editorY + editorH + 24;
    CGFloat outputH = totalH - outputY - 12;
    if (outputH < 60) outputH = 60;
    
    UILabel *outputTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, outputY - 18, totalW - 24, 16)];
    outputTitle.text = @"CONSOLE OUTPUT";
    outputTitle.textColor = [ToolTheme shared].textMuted;
    outputTitle.font = [[ToolTheme shared] monoBoldFont:10];
    outputTitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:outputTitle];
    
    self.outputTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, outputY, totalW - 24, outputH)];
    self.outputTextView.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.07 alpha:1.0];
    self.outputTextView.textColor = [UIColor greenColor];
    self.outputTextView.font = [[ToolTheme shared] monoFont:11];
    self.outputTextView.editable = NO;
    self.outputTextView.layer.cornerRadius = 6;
    self.outputTextView.layer.borderWidth = 1;
    self.outputTextView.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.outputTextView.text = @"-- Lua Console --";
    self.outputTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.outputTextView];
}

- (void)didTapClear {
    self.editorTextView.text = @"";
    self.outputTextView.text = @"-- Cleared --";
}

- (void)reload {
    if ([self isViewLoaded]) {
        // Đồng bộ khi chuyển tab
    }
}

@end
