#import "MemoryVC.h"
#import "ToolTheme.h"
#import "MemoryEditor.h"

@interface MemoryVC () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *refineButton;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UIButton *freezeButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *searchResults;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) NSInteger selectedRowIndex;
@property (nonatomic, assign) BOOL isCurrentAddressFrozen;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    if (!self.searchResults) {
        self.searchResults = [NSMutableArray array];
    }
    self.selectedRowIndex = -1;
    self.isCurrentAddressFrozen = NO;
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
    y += 34;

    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 38)];
    self.searchField.placeholder = @"Nhập giá trị cần tìm (vd: 130)...";
    self.searchField.backgroundColor = [ToolTheme shared].surface;
    self.searchField.textColor = [ToolTheme shared].textPrimary;
    self.searchField.font = [[ToolTheme shared] monoFont:12];
    self.searchField.layer.cornerRadius = 6;
    self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 38)];
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    self.searchField.delegate = self;
    self.searchField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchField];
    y += 46;

    CGFloat spacing = 4;
    CGFloat totalPadding = 16 * 2 + spacing * 4;
    CGFloat btnW = (w - totalPadding) / 5.0;
    CGFloat btnH = 34;
    CGFloat bx = 16;

    self.searchButton = [self makeButton:@"Tìm" x:bx y:y w:btnW h:btnH color:[ToolTheme shared].accent];
    [self.searchButton addTarget:self action:@selector(didTapNewSearch) forControlEvents:UIControlEventTouchUpInside];
    bx += btnW + spacing;

    self.refineButton = [self makeButton:@"Lọc" x:bx y:y w:btnW h:btnH color:[UIColor colorWithRed:0.20 green:0.60 blue:0.40 alpha:1.0]];
    [self.refineButton addTarget:self action:@selector(didTapRefineSearch) forControlEvents:UIControlEventTouchUpInside];
    bx += btnW + spacing;

    self.editButton = [self makeButton:@"Edit" x:bx y:y w:btnW h:btnH color:[UIColor colorWithRed:0.80 green:0.50 blue:0.10 alpha:1.0]];
    [self.editButton addTarget:self action:@selector(didTapEditValue) forControlEvents:UIControlEventTouchUpInside];
    bx += btnW + spacing;

    self.freezeButton = [self makeButton:@"Freeze" x:bx y:y w:btnW h:btnH color:[UIColor colorWithRed:0.30 green:0.40 blue:0.70 alpha:1.0]];
    [self.freezeButton addTarget:self action:@selector(didTapToggleFreeze) forControlEvents:UIControlEventTouchUpInside];
    bx += btnW + spacing;

    self.clearButton = [self makeButton:@"Xóa" x:bx y:y w:btnW h:btnH color:[UIColor colorWithRed:0.60 green:0.30 blue:0.30 alpha:1.0]];
    [self.clearButton addTarget:self action:@selector(didTapClear) forControlEvents:UIControlEventTouchUpInside];
    
    y += 42;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 20)];
    self.statusLabel.textColor = [ToolTheme shared].textMuted;
    self.statusLabel.font = [[ToolTheme shared] monoFont:10];
    [self.statusLabel setText:[NSString stringWithFormat:@"Đã tìm thấy: %lu địa chỉ", (unsigned long)self.searchResults.count]];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];
    y += 22;

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
    b.titleLabel.font = [[ToolTheme shared] monoBoldFont:10];
    b.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:b];
    return b;
}

- (void)didTapNewSearch {
    NSString *text = self.searchField.text;
    if (text.length == 0) return;
    [self.searchField resignFirstResponder];

    NSArray *results = [[MemoryEditor shared] searchValue:text type:MemValueTypeInt32 limit:50];
    [self.searchResults removeAllObjects];
    
    for (MemoryResult *res in results) {
        [self.searchResults addObject:@{
            @"address": [NSString stringWithFormat:@"0x%llX", (uint64_t)res.address],
            @"value": text,
            @"rawAddr": @(res.address)
        }];
    }

    [self.statusLabel setText:[NSString stringWithFormat:@"Tìm thấy: %lu địa chỉ", (unsigned long)self.searchResults.count]];
    [self.tableView reloadData];
}

- (void)didTapRefineSearch {
    NSString *text = self.searchField.text;
    if (text.length == 0 || self.searchResults.count == 0) return;
    [self.searchField resignFirstResponder];

    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *item in self.searchResults) {
        vm_address_t addr = [item[@"rawAddr"] unsignedLongLongValue];
        NSString *currentVal = [[MemoryEditor shared] readValueAt:addr type:MemValueTypeInt32];
        if ([currentVal isEqualToString:text]) {
            [filtered addObject:item];
        }
    }
    self.searchResults = filtered;
    [self.statusLabel setText:[NSString stringWithFormat:@"Lọc còn: %lu địa chỉ", (unsigned long)self.searchResults.count]];
    [self.tableView reloadData];
}

- (void)didTapEditValue {
    NSString *text = self.searchField.text;
    if (text.length == 0 || self.selectedRowIndex < 0 || self.selectedRowIndex >= self.searchResults.count) {
        [self.statusLabel setText:@"[Lỗi] Chọn 1 dòng và nhập giá trị mới để Edit!"];
        return;
    }
    [self.searchField resignFirstResponder];
    
    NSMutableDictionary *item = [self.searchResults[self.selectedRowIndex] mutableCopy];
    vm_address_t addr = [item[@"rawAddr"] unsignedLongLongValue];
    
    BOOL success = [[MemoryEditor shared] writeValue:text at:addr type:MemValueTypeInt32];
    if (success) {
        item[@"value"] = text;
        self.searchResults[self.selectedRowIndex] = item;
        [self.statusLabel setText:[NSString stringWithFormat:@"Đã ghi giá trị tại %@", item[@"address"]]];
    } else {
        [self.statusLabel setText:@"[Lỗi] Không thể ghi bộ nhớ (Protected)"];
    }
    
    [self.tableView reloadData];
}

- (void)didTapToggleFreeze {
    if (self.selectedRowIndex < 0 || self.selectedRowIndex >= self.searchResults.count) {
        [self.statusLabel setText:@"[Lỗi] Vui lòng chọn 1 dòng để Freeze/Unfreeze!"];
        return;
    }
    [self.searchField resignFirstResponder];
    
    NSDictionary *item = self.searchResults[self.selectedRowIndex];
    vm_address_t addr = [item[@"rawAddr"] unsignedLongLongValue];
    NSString *val = self.searchField.text.length > 0 ? self.searchField.text : item[@"value"];
    
    self.isCurrentAddressFrozen = !self.isCurrentAddressFrozen;
    
    [[MemoryEditor shared] freezeAddress:addr value:val type:MemValueTypeInt32 shouldFreeze:self.isCurrentAddressFrozen];
    
    if (self.isCurrentAddressFrozen) {
        [self.freezeButton setBackgroundColor:[UIColor colorWithRed:0.80 green:0.20 blue:0.20 alpha:1.0]];
        [self.statusLabel setText:[NSString stringWithFormat:@"Đã ĐÓNG BĂNG tại %@", item[@"address"]]];
    } else {
        [self.freezeButton setBackgroundColor:[UIColor colorWithRed:0.30 green:0.40 blue:0.70 alpha:1.0]];
        [self.statusLabel setText:[NSString stringWithFormat:@"Đã HỦY ĐÓNG BĂNG tại %@", item[@"address"]]];
    }
}

- (void)didTapClear {
    [self.searchResults removeAllObjects];
    self.searchField.text = @"";
    self.selectedRowIndex = -1;
    self.isCurrentAddressFrozen = NO;
    [self.freezeButton setBackgroundColor:[UIColor colorWithRed:0.30 green:0.40 blue:0.70 alpha:1.0]];
    [self.statusLabel setText:@"Đã xóa kết quả quét."];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedRowIndex = indexPath.row;
    NSDictionary *item = self.searchResults[indexPath.row];
    self.searchField.text = item[@"value"];
    [self.statusLabel setText:[NSString stringWithFormat:@"Đã chọn: %@", item[@"address"]]];
}

- (void)reload {
    [self.tableView reloadData];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
