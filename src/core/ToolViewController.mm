- (void)handleResize:(UIPanGestureRecognizer *)g {
    CGPoint p = [g translationInView:self.view];

    if (g.state == UIGestureRecognizerStateBegan) {
        self.isResizing = YES;
        self.dragStartSize = self.panel.frame.size;
        self.dragStartPoint = self.panel.frame.origin;
    }

    if (g.state == UIGestureRecognizerStateChanged) {
        // KHÔNG giới hạn min/max
        CGFloat newW = self.dragStartSize.width + p.x;
        CGFloat newH = self.dragStartSize.height + p.y;

        self.panel.frame = CGRectMake(self.dragStartPoint.x, self.dragStartPoint.y, newW, newH);
        [self updateLayoutForPanelSize:CGSizeMake(newW, newH)];
    }

    if (g.state == UIGestureRecognizerStateEnded ||
        g.state == UIGestureRecognizerStateCancelled) {
        self.isResizing = NO;
    }
}
