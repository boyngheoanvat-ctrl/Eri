static void buildUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g.didInitUI) return;
        
        CGRect scr = [UIScreen mainScreen].bounds;
        
        // Tạo Window cao nhất — cao hơn cả thông báo hệ thống
        g_topWindow = [[UIWindow alloc] initWithFrame:scr];
        g_topWindow.windowLevel = UIWindowLevelStatusBar + 5000; // ⬅️ Cao hơn mọi thứ
        g_topWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController* vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        g_topWindow.rootViewController = vc;
        
        [g_topWindow makeKeyAndVisible];
        
        // ⚠️ Bắt buộc gọi layout lại
        [g_topWindow layoutIfNeeded];
        
        g.didInitUI = true;
        
        // === ICON ===
        g_iconBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, 200, 56, 56)];
        g_iconBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.1 blue:0.25 alpha:0.95];
        g_iconBtn.layer.cornerRadius = 28;
        g_iconBtn.layer.borderWidth = 3;
        g_iconBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.5 alpha:1].CGColor;
        g_iconBtn.layer.zPosition = MAXFLOAT; // Luôn trên cùng
        [g_iconBtn setTitle:@"🎮" forState:UIControlStateNormal];
        g_iconBtn.titleLabel.font = [UIFont systemFontOfSize:28];
        [g_iconBtn addAction:[UIAction actionWithHandler:^(UIAction*){ toggleMenu(); }] 
                  forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:g_iconBtn];
        
        // === MENU ===
        g_menuPanel = [[UIView alloc] initWithFrame:CGRectMake(85, 120, 290, 340)];
        g_menuPanel.backgroundColor = [UIColor colorWithRed:0.08 green:0.06 blue:0.12 alpha:0.96];
        g_menuPanel.layer.cornerRadius = 20;
        g_menuPanel.layer.borderWidth = 2.5;
        g_menuPanel.layer.borderColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.5 alpha:1].CGColor;
        g_menuPanel.layer.zPosition = MAXFLOAT - 1;
        
        // Nút đóng
        UIButton* btnClose = [[UIButton alloc] initWithFrame:CGRectMake(240, 8, 40, 32)];
        [btnClose setTitle:@"✕" forState:UIControlStateNormal];
        [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btnClose.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        [btnClose addAction:[UIAction actionWithHandler:^(UIAction*){ toggleMenu(); }] 
                  forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:btnClose];
        
        // Tiêu đề
        UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 220, 28)];
        title.text = @"✨ AutoDance AU2 ✨";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:17];
        [g_menuPanel addSubview:title];
        
        // Nút Auto Arrow
        g_btnArrow = [[UIButton alloc] initWithFrame:CGRectMake(15, 55, 260, 52)];
        [g_btnArrow setTitle:@"⚡ Auto Arrow: TẮT" forState:UIControlStateNormal];
        [g_btnArrow setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = [UIColor darkGrayColor];
        g_btnArrow.layer.cornerRadius = 14;
        [g_btnArrow addAction:[UIAction actionWithHandler:^(UIAction*){
            g.arrow = !g.arrow; if(!g.arrow) restoreAll(); updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnArrow];
        
        // Nút Auto Taiko
        g_btnTaiko = [[UIButton alloc] initWithFrame:CGRectMake(15, 119, 260, 52)];
        [g_btnTaiko setTitle:@"🥁 Auto Taiko: TẮT" forState:UIControlStateNormal];
        [g_btnTaiko setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = [UIColor darkGrayColor];
        g_btnTaiko.layer.cornerRadius = 14;
        [g_btnTaiko addAction:[UIAction actionWithHandler:^(UIAction*){
            g.taiko = !g.taiko; if(!g.taiko) restoreAll(); updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnTaiko];
        
        // Nút Mini+Crazy
        g_btnMini = [[UIButton alloc] initWithFrame:CGRectMake(15, 183, 260, 52)];
        [g_btnMini setTitle:@"🔥 Mini+Crazy: TẮT" forState:UIControlStateNormal];
        [g_btnMini setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnMini.backgroundColor = [UIColor darkGrayColor];
        g_btnMini.layer.cornerRadius = 14;
        [g_btnMini addAction:[UIAction actionWithHandler:^(UIAction*){
            g.mini = !g.mini; if(!g.mini) { g.scored.clear(); restoreAll(); } updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnMini];
        
        // Nút Reset
        UIButton* bReset = [[UIButton alloc] initWithFrame:CGRectMake(15, 247, 260, 46)];
        [bReset setTitle:@"🔄 Tắt hết & Khôi phục" forState:UIControlStateNormal];
        [bReset setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        bReset.backgroundColor = [UIColor colorWithRed:0.9 green:0.15 blue:0.2 alpha:1];
        bReset.layer.cornerRadius = 14;
        [bReset addAction:[UIAction actionWithHandler:^(UIAction*){
            g.arrow = g.taiko = g.mini = false; restoreAll(); updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:bReset];
        
        // Gợi ý
        UILabel* hint = [[UILabel alloc] initWithFrame:CGRectMake(15, 300, 260, 35)];
        hint.text = @"🎮 ẩn/hiện Menu | Vào màn hình chơi → kích hoạt";
        hint.textColor = [UIColor lightGrayColor];
        hint.font = [UIFont systemFontOfSize:11.5];
        hint.textAlignment = NSTextAlignmentCenter;
        [g_menuPanel addSubview:hint];
        
        [vc.view addSubview:g_menuPanel];
    });
}
