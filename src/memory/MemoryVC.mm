#import "MemoryVC.h"
#import "ToolTheme.h"

@interface MemoryVC () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *refineButton;
@property (nonatomic, strong) UIButton *editAllButton; // Đổi từ clearButton thành editAllButton
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *searchResults;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    if (!self.searchResults) {
        self.searchResults = [NSMutableArray array];
    }
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 16;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
    title.text = @"Memory Scanner & Editor";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:title];
    y += 36;

    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
    self.searchField.placeholder = @"Nhập giá trị cần tìm hoặc giá trị Edit All...";
    self.searchField.backgroundColor = [ToolTheme shared].surface;
    self.searchField.textColor = [ToolTheme shared].textPrimary;
    self.searchField.font = [[ToolTheme shared] monoFont:12];
    self.searchField.layer.cornerRadius = 6;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.delegate = self;
    self.searchField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchField];
    y += 50;

    CGFloat btnW = (w - 40) / 3.0;
    
    self.searchButton = [self makeButton:@"Tìm Mới" x:16 y:y w:btnW h:36 color:[ToolTheme shared].accent];
    [self.searchButton addTarget:self action:@selector(didTapNewSearch) forControlEvents:UIControlEventTouchUpInside];

    self.refineButton = [self makeButton:@"Lọc Tiếp" x:24 + btnW y:y w:btnW h:36 color:[UIColor colorWithRed:0.20 green:0.60 blue:0.40 alpha:1.0]];
    [self.refineButton addTarget:self action:@selector(didTapRefineSearch) forControlEvents:UIControlEventTouchUpInside];

    // Nút Edit All (thay cho nút Xóa cũ)
    self.editAllButton = [self makeButton:@"Edit All" x:32 + btnW * 2 y:y w:btnW h:36 color:[UIColor colorWithRed:0.80 green:0.50 blue:0.20 alpha:1.0]];
    [self.editAllButton addTarget:self action:@selector(didTapEditAll) forControlEvents:UIControlEventTouchUpInside];
    
    y += 46;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 20)];
    self.statusLabel.textColor = [ToolTheme shared].textMuted;
    self.statusLabel.font = [[ToolTheme shared] monoFont:10];
    [self.statusLabel setText:[NSString stringWithFormat:@"Đã tìm thấy: %lu địa chỉ", (unsigned long)self.searchResults.count]];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];
    y += 24;

    CGFloat tableH = CGRectGetHeight(self.view.bounds) - y - 16;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(16, y, w - 32, MAX(100, tableH)) style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
}

- (UIButton *)makeButton:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h color:(UIColor *)color {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, h);
    b.backgroundColor = color;
    b.layer.cornerRadius = 6;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    b.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:b];
    return b;
}

- (void)didTapNewSearch {
    NSString *text = self.searchField.text;
    if (text.length == 0) return;
    [self.searchField resignFirstResponder];

    [self.searchResults removeAllObjects];
    for (int i = 0; i < 15; i++) {
        uint64_t fakeAddr = 0x100000000 + (i * 0x48) + (arc4random_uniform(0xFF) & 0xF);
        [self.searchResults addObject:@{
            @"address": [NSString stringWithFormat:@"0x%llX", fakeAddr],
            @"value": text
        }];
    }

    [self.statusLabel setText:[NSString stringWithFormat:@"Đã tìm thấy: %lu địa chỉ cho giá trị '%@'", (unsigned long)self.searchResults.count, text]];
    [self.tableView reloadData];
}

- (void)didTapRefineSearch {
    NSString *text = self.searchField.text;
    if (text.length == 0 || self.searchResults.count == 0) return;
    [self.searchField resignFirstResponder];

    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *item in self.searchResults) {
        if (arc4random_uniform(2) == 0) {
            [filtered addObject:@{
                @"address": item[@"address"],
                @"value": text
            }];
        }
    }
    self.searchResults = filtered;
    [self.statusLabel setText:[NSString stringWithFormat:@"Đã lọc còn lại: %lu địa chỉ", (unsigned long)self.searchResults.count]];
    [self.tableView reloadData];
}

- (void)didTapEditAll {
    NSString *newVal = self.searchField.text;
    if (newVal.length == 0 || self.searchResults.count == 0) {
        [self.statusLabel setText:@"[Lỗi] Không có kết quả hoặc chưa nhập giá trị mới để Edit!"];
        return;
    }
    [self.searchField resignFirstResponder];

    // Cập nhật giá trị mới cho toàn bộ danh sách kết quả đang hiển thị
    NSMutableArray *updated = [NSMutableArray array];
    for (NSDictionary *item in self.searchResults) {
        [updated addObject:@{
            @"address": item[@"address"],
            @"value": newVal
        }];
    }
    self.searchResults = updated;
    [self.statusLabel setText:[NSString stringWithFormat:@"[Thành công] Đã đổi toàn bộ giá trị thành: %@", newVal]];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellID = @"MemCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellID];
        cell.backgroundColor = [ToolTheme shared].surface;
        cell.textLabel.textColor = [ToolTheme shared].textPrimary;
        cell.textLabel.font = [[ToolTheme shared] monoFont:11];
        cell.detailTextLabel.textColor = [ToolTheme shared].accent;
        cell.detailTextLabel.font = [[ToolTheme shared] monoBoldFont:11];
    }
    NSDictionary *item = self.searchResults[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"Addr: %@", item[@"address"]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Val: %@", item[@"value"]];
    return cell;
}

- (void)reload {
    [self.tableView reloadData];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
