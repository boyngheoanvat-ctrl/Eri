- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    if (!self.overlayController.enabled) return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    CGContextSetLineWidth(context, 1.5);
    CGContextSetStrokeColorWithColor(context, [ToolTheme shared].success.CGColor);
    
    // Luôn vẽ fallback tâm màn hình nếu bật Master Enable để chắc chắn ESP có hiển thị
    CGFloat boxW = 70;
    CGFloat boxH = 130;
    CGFloat boxX = (rect.size.width - boxW) / 2.0;
    CGFloat boxY = (rect.size.height - boxH) / 2.0;
    
    if (self.overlayController.showBox) {
        CGContextStrokeRect(context, CGRectMake(boxX, boxY, boxW, boxH));
    }
    
    if (self.overlayController.showLine) {
        CGContextMoveToPoint(context, rect.size.width / 2.0, rect.size.height);
        CGContextAddLineToPoint(context, boxX + boxW / 2.0, boxY + boxH);
        CGContextStrokePath(context);
    }
    
    UIFont *font = [[ToolTheme shared] monoFont:9];
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [ToolTheme shared].textPrimary
    };
    
    if (self.overlayController.showName) {
        [@"[Eri] Player" drawAtPoint:CGPointMake(boxX, boxY - 14) withAttributes:attrs];
    }
    
    if (self.overlayController.showHP) {
        CGFloat hpBarX = boxX - 6;
        CGFloat hpBarW = 4;
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1 green:0 blue:0 alpha:0.6].CGColor);
        CGContextFillRect(context, CGRectMake(hpBarX, boxY, hpBarW, boxH));
        CGContextSetFillColorWithColor(context, [ToolTheme shared].success.CGColor);
        CGContextFillRect(context, CGRectMake(hpBarX, boxY + boxH * 0.2, hpBarW, boxH * 0.8));
    }
}
