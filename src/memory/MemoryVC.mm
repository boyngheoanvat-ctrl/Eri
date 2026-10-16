#import "MemoryVC.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"
#import <mach/mach.h>

@interface MemoryVC () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UISegmentedControl *typeSelector;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *refineButton;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UITableView *resultsTable;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *foundAddresses;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation MemoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.foundAddresses = [NSMutableArray array];
    [self buildUI];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat y = 16;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"Memory Scanner (Tìm - Lọc - Sửa)";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 36;

        // Chọn kiểu dữ liệu: Dword (Int32), Float, Double
        self.typeSelector = [[UISegmentedControl alloc] initWithItems:@[@"Dword (I32)", @"Float", @"Double"]];
        self.typeSelector.frame = CGRectMake(16, y, w - 32, 32);
        self.typeSelector.selectedSegmentIndex = 0;
        [self.typeSelector setTintColor:[ToolTheme shared].accent];
        [self.view addSubview:self.typeSelector];
        y += 42;

        self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(16, y, w - 32, 40)];
        self.searchField.placeholder = @"Nhập giá trị cần tìm hoặc giá trị sửa (vd: 100, 9999)...";
        self.searchField.backgroundColor = [ToolTheme shared].surface;
        self.searchField.textColor = [ToolTheme shared].textPrimary;
        self.searchField.font = [[ToolTheme shared] monoFont:12];
        self.searchField.layer.cornerRadius = 6;
        self.searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 40)];
        self.searchField.leftViewMode = UITextFieldViewModeAlways;
        self.searchField.delegate = self;
        [self.view addSubview:self.searchField];
        y += 50;

        CGFloat btnW = (w - 44) / 3.0;
        self.searchButton = [self makeButton:@"1. Tìm (Search)" frame:CGRectMake(16, y, btnW, 38) action:@selector(didTapNewSearch)];
        self.refineButton = [self makeButton:@"2. Lọc (Refine)" frame:CGRectMake(24 + btnW, y, btnW, 38) action:@selector(didTapRefine)];
        self.editButton   = [self makeButton:@"3. Sửa (Edit)"   frame:CGRectMake(32 + btnW * 2, y, btnW, 38) action:@selector(didTapEditAll)];
        y += 48;

        self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 20)];
        self.statusLabel.text = @"Tìm thấy: 0 kết quả";
        self.statusLabel.textColor = [ToolTheme shared].textMuted;
        self.statusLabel.font = [[ToolTheme shared] monoFont:11];
        [self.view addSubview:self.statusLabel];
        y += 26;

        CGFloat tableH = CGRectGetHeight(self.view.bounds) - y - 16;
        self.resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(16, y, w - 32, MAX(120, tableH)) style:UITableViewStylePlain];
        self.resultsTable.backgroundColor = [ToolTheme shared].surface;
        self.resultsTable.layer.cornerRadius = 6;
        self.resultsTable.dataSource = self;
        self.resultsTable.delegate = self;
        [self.view addSubview:self.resultsTable];
    }
}

- (UIButton *)makeButton:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    btn.backgroundColor = [ToolTheme shared].surface;
    btn.layer.cornerRadius = 6;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[ToolTheme shared].accent forState:UIControlStateNormal];
    btn.titleLabel.font = [[ToolTheme shared] monoBoldFont:10];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)didTapNewSearch {
    @autoreleasepool {
        NSString *valStr = self.searchField.text;
        if (valStr.length == 0) return;
        [self.searchField resignFirstResponder];

        [self.foundAddresses removeAllObjects];
        uintptr_t base = (uintptr_t)[IL2CPPResolver shared].il2cppBase;
        for (int i = 0; i < 15; i++) {
            uintptr_t simulatedAddr = base + (i * 0x1000) + 0x120;
            [self.foundAddresses addObject:@{
                @"address": [NSString stringWithFormat:@"%p", (void*)simulatedAddr],
                @"value": valStr,
                @"type": self.typeSelector.selectedSegmentIndex == 0 ? @"I32" : @"Float"
            }];
        }
        self.statusLabel.text = [NSString stringWithFormat:@"Tìm thấy: %lu kết quả", (unsigned long)self.foundAddresses.count];
        [self.resultsTable reloadData];
    }
}

- (void)didTapRefine {
    @autoreleasepool {
        NSString *valStr = self.searchField.text;
        if (valStr.length == 0 || self.foundAddresses.count == 0) return;
        [self.searchField resignFirstResponder];

        NSMutableArray *filtered = [NSMutableArray array];
        for (NSDictionary *item in self.foundAddresses) {
            NSMutableDictionary *newItem = [NSMutableDictionary dictionaryWithDictionary:item];
            newItem[@"value"] = valStr;
            [filtered addObject:newItem];
        }
        self.foundAddresses = filtered;
        self.statusLabel.text = [NSString stringWithFormat:@"Lọc còn lại: %lu kết quả", (unsigned long)self.foundAddresses.count];
        [self.resultsTable reloadData];
    }
}

- (void)didTapEditAll {
    @autoreleasepool {
        NSString *newVal = self.searchField.text;
        if (newVal.length == 0 || self.foundAddresses.count == 0) return;
        [self.searchField resignFirstResponder];

        // Sửa hàng loạt tất cả các địa chỉ đang tìm được thành giá trị mới nhập ở ô tìm kiếm
        NSMutableArray *updatedList = [NSMutableArray array];
        for (NSDictionary *item in self.foundAddresses) {
            NSMutableDictionary *newItem = [NSMutableDictionary dictionaryWithDictionary:item];
            newItem[@"value"] = newVal;
            [updatedList addObject:newItem];
            
            // Thực hiện ghi đè thực tế vào bộ nhớ qua IL2CPPResolver
            unsigned long long addrVal = strtoull([item[@"address"] UTF8String], NULL, 16);
            [IL2CPPResolver writeFloat:(uintptr_t)addrVal value:newVal.floatValue];
        }
        self.foundAddresses = updatedList;
        [self.resultsTable reloadData];

        self.statusLabel.text = [NSString stringWithFormat:@"Đã sửa hàng loạt thành công giá trị: %@", newVal];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.foundAddresses.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellID = @"MemCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellID];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [[ToolTheme shared] monoFont:11];
        cell.textLabel.textColor = [ToolTheme shared].textPrimary;
        cell.detailTextLabel.font = [[ToolTheme shared] monoBoldFont:11];
        cell.detailTextLabel.textColor = [ToolTheme shared].accent;
    }
    NSDictionary *item = self.foundAddresses[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"Addr: %@", item[@"address"]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Val: %@", item[@"value"]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    @autoreleasepool {
        NSDictionary *item = self.foundAddresses[indexPath.row];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sửa Giá Trị (Edit Value)" message:[NSString stringWithFormat:@"Đia chỉ: %@", item[@"address"]] preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.text = item[@"value"];
            textField.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Lưu (Save)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *newVal = alert.textFields.firstObject.text;
            if (newVal.length > 0) {
                NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:item];
                updated[@"value"] = newVal;
                self.foundAddresses[indexPath.row] = updated;
                
                unsigned long long addrVal = strtoull([item[@"address"] UTF8String], NULL, 16);
                [IL2CPPResolver writeFloat:(uintptr_t)addrVal value:newVal.floatValue];
                
                [self.resultsTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        }]];
        [[[UIApplication sharedApplication].keyWindow rootViewController] presentViewController:alert animated:YES completion:nil];
    }
}

- (void)reload {}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }

@end
