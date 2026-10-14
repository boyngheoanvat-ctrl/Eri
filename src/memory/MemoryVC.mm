#import "MemoryVC.h"
#import "MemoryEditor.h"
#import "ToolTheme.h"

@interface MemoryVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UISegmentedControl *typeControl;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIButton *editAllButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<MemoryResult *> *allResults;
@property (nonatomic, strong) NSMutableArray<MemoryResult *> *filteredResults;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) MemValueType currentType;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.allResults = [NSMutableArray array];
    self.filteredResults = [NSMutableArray array];
    self.currentType = MemValueTypeInt32;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    CGFloat y = 8;
    CGFloat pad = 8;

    // Type selector
    self.typeControl = [[UISegmentedControl alloc] initWithItems:@[@"Int32", @"Int64", @"Float", @"Double"]];
    self.typeControl.frame = CGRectMake(pad, y, w - pad * 2, 30);
    self.typeControl.selectedSegmentIndex = 0;
    self.typeControl.backgroundColor = [ToolTheme shared].surface;
    self.typeControl.selectedSegmentTintColor = [ToolTheme shared].accent;
    [self.typeControl setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [[ToolTheme shared] monoFont:10]
    } forState:UIControlStateSelected];
    [self.typeControl addTarget:self action:@selector(typeChanged)
              forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.typeControl];
    y += 36;

    // Value field
    self.valueField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 34)];
    self.valueField.backgroundColor = [ToolTheme shared].surface;
    self.valueField.textColor = [ToolTheme shared].textPrimary;
    self.valueField.font = [[ToolTheme shared] monoFont:11];
    self.valueField.layer.borderWidth = 1;
    self.valueField.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.valueField.layer.cornerRadius = 4;
    self.valueField.placeholder = @"Nhap gia tri can tim...";
    self.valueField.keyboardType = UIKeyboardTypeDecimalPad;
    self.valueField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    self.valueField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:self.valueField];
    y += 40;

    // 3 buttons
    CGFloat btnW = (w - pad * 4) / 3;
    CGFloat btnH = 34;

    self.searchButton = [self makeButton:@"Tim" x:pad y:y w:btnW h:btnH
                                    color:[ToolTheme shared].accent];
    [self.searchButton addTarget:self action:@selector(searchTapped)
                forControlEvents:UIControlEventTouchUpInside];

    self.filterButton = [self makeButton:@"Loc" x:pad * 2 + btnW y:y w:btnW h:btnH
                                    color:[ToolTheme shared].warning];
    [self.filterButton addTarget:self action:@selector(filterTapped)
                forControlEvents:UIControlEventTouchUpInside];

    self.editAllButton = [self makeButton:@"Edit All" x:pad * 3 + btnW * 2 y:y w:btnW h:btnH
                                     color:[ToolTheme shared].danger];
    [self.editAllButton addTarget:self action:@selector(editAllTapped)
                 forControlEvents:UIControlEventTouchUpInside];
    y += 42;

    // Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 18)];
    self.statusLabel.text = @"San sang";
    self.statusLabel.textColor = [ToolTheme shared].textMuted;
    self.statusLabel.font = [[ToolTheme shared] monoFont:10];
    [self.view addSubview:self.statusLabel];
    y += 22;

    // Table
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, y, w, h - y)
                                                     style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [ToolTheme shared].background;
    self.tableView.separatorColor = [ToolTheme shared].divider;
    self.tableView.rowHeight = 50;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.view addSubview:self.tableView];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = [ToolTheme shared].accent;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

- (UIButton *)makeButton:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h color:(UIColor *)color {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, h);
    b.backgroundColor = color;
    b.layer.cornerRadius = 4;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    [self.view addSubview:b];
    return b;
}

- (void)typeChanged {
    NSInteger idx = self.typeControl.selectedSegmentIndex;
    if (idx == 0) self.currentType = MemValueTypeInt32;
    else if (idx == 1) self.currentType = MemValueTypeInt64;
    else if (idx == 2) self.currentType = MemValueTypeFloat;
    else if (idx == 3) self.currentType = MemValueTypeDouble;
}

#pragma mark - Search

- (void)searchTapped {
    NSString *value = self.valueField.text;
    if (value.length == 0) return;

    [self.view endEditing:YES];
    [self.allResults removeAllObjects];
    [self.filteredResults removeAllObjects];
    [self.tableView reloadData];

    self.statusLabel.text = @"Dang tim...";
    [self.spinner startAnimating];
    self.searchButton.enabled = NO;

    MemValueType type = self.currentType;
    __weak typeof(self) ws = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<MemoryResult *> *found = [[MemoryEditor shared]
            searchValue:value type:type limit:200];

        dispatch_async(dispatch_get_main_queue(), ^{
            [ws.allResults addObjectsFromArray:found];
            [ws.filteredResults addObjectsFromArray:found];
            [ws.tableView reloadData];
            ws.statusLabel.text = [NSString stringWithFormat:@"Tim thay %lu ket qua",
                                    (unsigned long)found.count];
            [ws.spinner stopAnimating];
            ws.searchButton.enabled = YES;
        });
    });
}

#pragma mark - Filter

- (void)filterTapped {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Loc ket qua" message:@"Chi hien gia tri trong khoang"
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Min (>=)";
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Max (<=)";
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Ap dung"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *minStr = alert.textFields[0].text;
        NSString *maxStr = alert.textFields[1].text;

        [self.filteredResults removeAllObjects];
        for (MemoryResult *r in self.allResults) {
            double v = r.stringValue.doubleValue;
            if (minStr.length > 0 && v < minStr.doubleValue) continue;
            if (maxStr.length > 0 && v > maxStr.doubleValue) continue;
            [self.filteredResults addObject:r];
        }
        [self.tableView reloadData];
        self.statusLabel.text = [NSString stringWithFormat:@"Loc: %lu ket qua",
                                  (unsigned long)self.filteredResults.count];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Xoa loc"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [self.filteredResults removeAllObjects];
        [self.filteredResults addObjectsFromArray:self.allResults];
        [self.tableView reloadData];
        self.statusLabel.text = [NSString stringWithFormat:@"%lu ket qua",
                                  (unsigned long)self.filteredResults.count];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Huy"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Edit All

- (void)editAllTapped {
    if (self.filteredResults.count == 0) {
        self.statusLabel.text = @"Khong co ket qua de sua";
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:@"Sua %lu dia chi",
                                   (unsigned long)self.filteredResults.count]
                         message:@"Nhap gia tri moi cho TAT CA dia chi"
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Gia tri moi";
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Sua tat ca"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        NSString *newValue = alert.textFields.firstObject.text;
        if (newValue.length == 0) return;

        NSInteger count = [[MemoryEditor shared]
            editAll:self.filteredResults
            value:newValue
            type:self.currentType];

        for (MemoryResult *r in self.filteredResults) {
            r.stringValue = newValue;
        }

        [self.tableView reloadData];
        self.statusLabel.text = [NSString stringWithFormat:@"Da sua %ld dia chi thanh %@",
                                  (long)count, newValue];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Huy"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.filteredResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell" forIndexPath:ip];
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];

    MemoryResult *r = self.filteredResults[ip.row];
    CGFloat cw = CGRectGetWidth(tv.bounds);

    UILabel *addr = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 200, 16)];
    addr.text = [NSString stringWithFormat:@"0x%llX", (uint64_t)r.address];
    addr.textColor = [ToolTheme shared].accent;
    addr.font = [[ToolTheme shared] monoFont:11];
    [cell.contentView addSubview:addr];

    UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(10, 26, 200, 16)];
    val.text = [NSString stringWithFormat:@"Value: %@", r.stringValue];
    val.textColor = [ToolTheme shared].textPrimary;
    val.font = [[ToolTheme shared] monoFont:11];
    [cell.contentView addSubview:val];

    UILabel *edit = [[UILabel alloc] initWithFrame:CGRectMake(cw - 60, 16, 50, 16)];
    edit.text = @"Edit";
    edit.textColor = [ToolTheme shared].warning;
    edit.textAlignment = NSTextAlignmentRight;
    edit.font = [[ToolTheme shared] monoBoldFont:11];
    [cell.contentView addSubview:edit];

    cell.backgroundColor = [UIColor clearColor];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    MemoryResult *r = self.filteredResults[ip.row];
    [self showEditDialogFor:r];
}

- (void)showEditDialogFor:(MemoryResult *)r {
    NSString *title = [NSString stringWithFormat:@"0x%llX", (uint64_t)r.address];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:title
                         message:@"Nhap gia tri moi"
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = r.stringValue;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Luu"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *newVal = alert.textFields.firstObject.text;
        BOOL ok = [[MemoryEditor shared] writeValue:newVal at:r.address type:r.type];
        r.stringValue = newVal;
        [self.tableView reloadData];
        self.statusLabel.text = ok ? @"Sua thanh cong" : @"Sua that bai";
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Huy"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reload { [self.tableView reloadData]; }

@end
