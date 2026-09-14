//
//  main.m
//  Antigravity Monitor (macOS Menu Bar Extra)
//
//  Created for Antigravity Token Monitor
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSDictionary *latestStats;
@property (assign, nonatomic) NSInteger displayMode; // 0: Quota + Tokens, 1: Quota, 2: Tokens, 3: Icon
@property (assign, nonatomic) BOOL notifiedLowQuota;
@property (assign, nonatomic) BOOL serverAutoStartAttempted;
@property (strong, nonatomic) NSISO8601DateFormatter *isoFormatter;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.displayMode = 0;
    self.notifiedLowQuota = NO;
    self.serverAutoStartAttempted = NO;
    self.isoFormatter = [[NSISO8601DateFormatter alloc] init];

    // Ensure running as an accessory / menu bar app (no Dock icon)
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    [self setupStatusItem];
    [self fetchStats];

    // Schedule 5-second polling timer on common run loop modes so menu interaction doesn't pause it
    self.timer = [NSTimer timerWithTimeInterval:5.0
                                         target:self
                                       selector:@selector(fetchStats)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"⚡ --%";
    self.statusItem.button.toolTip = @"Antigravity Token Monitor";
    [self updateMenu];
}

#pragma mark - Formatting Helpers

- (NSString *)formatTokens:(long long)num {
    if (num >= 1000000000LL) {
        return [NSString stringWithFormat:@"%.2fB", (double)num / 1000000000.0];
    } else if (num >= 1000000LL) {
        return [NSString stringWithFormat:@"%.1fM", (double)num / 1000000.0];
    } else if (num >= 1000LL) {
        return [NSString stringWithFormat:@"%.1fK", (double)num / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%lld", num];
    }
}

- (NSString *)formatNumberWithCommas:(long long)num {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:@(num)] ?: [NSString stringWithFormat:@"%lld", num];
}

- (NSString *)formatResetTime:(NSString *)isoString {
    if (!isoString || [isoString isEqualToString:@""]) return @"";
    NSDate *date = [self.isoFormatter dateFromString:isoString];
    if (!date) return @"";

    NSTimeInterval diff = [date timeIntervalSinceDate:[NSDate date]];
    if (diff <= 0) return @"已重置";

    int hours = (int)(diff / 3600);
    int minutes = (int)(((long)diff % 3600) / 60);
    int days = hours / 24;

    if (days > 0) {
        return [NSString stringWithFormat:@"%dd %dh 后重置", days, hours % 24];
    } else if (hours > 0) {
        return [NSString stringWithFormat:@"%dh %dm 后重置", hours, minutes];
    } else {
        return [NSString stringWithFormat:@"%dm 后重置", minutes];
    }
}

- (NSString *)statusEmojiForFraction:(double)fraction {
    if (fraction >= 0.5) return @"🟢";
    if (fraction >= 0.2) return @"🟡";
    return @"🔴";
}

#pragma mark - Network & Auto-start

- (void)fetchStats {
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8765/api/stats"];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 2.5;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !data) {
                [strongSelf handleFetchError:error];
                return;
            }

            NSError *jsonError = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (json && [json isKindOfClass:[NSDictionary class]]) {
                strongSelf.latestStats = json;
                strongSelf.serverAutoStartAttempted = NO; // reset
                [strongSelf updateUIWithStats:json];
            } else {
                [strongSelf handleFetchError:jsonError];
            }
        });
    }];
    [task resume];
}

- (void)handleFetchError:(NSError *)error {
    if (!self.latestStats) {
        self.statusItem.button.title = @"⚡ 离线";
    }
    [self updateMenu];

    // If server is not responding, attempt to auto-launch server.py once
    if (!self.serverAutoStartAttempted) {
        self.serverAutoStartAttempted = YES;
        [self attemptAutoStartServer];
    }
}

- (void)attemptAutoStartServer {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *parentDir = [bundlePath stringByDeletingLastPathComponent];
        
        NSArray *candidatePaths = @[
            [parentDir stringByAppendingPathComponent:@"server.py"],
            [parentDir stringByAppendingPathComponent:@"../server.py"],
            @"/Users/mac/.gemini/antigravity/scratch/antigravity-token-monitor/server.py"
        ];

        NSString *foundScript = nil;
        for (NSString *p in candidatePaths) {
            NSString *stdPath = [p stringByStandardizingPath];
            if ([[NSFileManager defaultManager] fileExistsAtPath:stdPath]) {
                foundScript = stdPath;
                break;
            }
        }

        if (foundScript) {
            NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/usr/bin/python3";
            task.arguments = @[foundScript];
            task.currentDirectoryPath = [foundScript stringByDeletingLastPathComponent];
            @try {
                [task launch];
            } @catch (NSException *e) {
                // ignore
            }
        }
    });
}

#pragma mark - UI Updates

- (void)updateUIWithStats:(NSDictionary *)stats {
    NSDictionary *quota = stats[@"quota"];
    NSDictionary *summary = stats[@"summary"];
    
    // Find Gemini 5h quota fraction
    double gemini5hFraction = -1.0;
    NSArray *groups = quota[@"groups"];
    if ([groups isKindOfClass:[NSArray class]]) {
        for (NSDictionary *g in groups) {
            NSArray *buckets = g[@"buckets"];
            if ([buckets isKindOfClass:[NSArray class]]) {
                for (NSDictionary *b in buckets) {
                    if ([b[@"bucketId"] isEqualToString:@"gemini-5h"]) {
                        gemini5hFraction = [b[@"remainingFraction"] doubleValue];
                        break;
                    }
                }
            }
        }
    }

    // Get total output tokens
    long long outputTokens = [summary[@"output_tokens"] longLongValue];
    if (outputTokens == 0) {
        outputTokens = [summary[@"total_tokens"] longLongValue];
    }

    // Check low-quota notification
    if (gemini5hFraction >= 0.0 && gemini5hFraction <= 0.15) {
        if (!self.notifiedLowQuota) {
            self.notifiedLowQuota = YES;
            [self sendNotificationWithTitle:@"Antigravity 额度预警"
                                    message:[NSString stringWithFormat:@"Gemini 5小时额度仅剩 %.1f%%，建议放缓调用或切换模型。", gemini5hFraction * 100.0]];
        }
    } else if (gemini5hFraction > 0.25) {
        self.notifiedLowQuota = NO; // Reset alert threshold
    }

    // Update Status Item Title based on displayMode
    NSString *quotaStr = (gemini5hFraction >= 0.0) ? [NSString stringWithFormat:@"%.0f%%", gemini5hFraction * 100.0] : @"--%";
    NSString *tokenStr = [self formatTokens:outputTokens];

    switch (self.displayMode) {
        case 0: // Quota + Tokens
            self.statusItem.button.title = [NSString stringWithFormat:@"⚡ %@ · %@", quotaStr, tokenStr];
            break;
        case 1: // Quota only
            self.statusItem.button.title = [NSString stringWithFormat:@"⚡ %@", quotaStr];
            break;
        case 2: // Tokens only
            self.statusItem.button.title = [NSString stringWithFormat:@"⚡ %@", tokenStr];
            break;
        case 3: // Icon only
            self.statusItem.button.title = @"⚡";
            break;
        default:
            self.statusItem.button.title = [NSString stringWithFormat:@"⚡ %@", quotaStr];
            break;
    }

    [self updateMenu];
}

#pragma mark - Menu Construction

- (void)updateMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;

    NSDictionary *stats = self.latestStats;
    NSDictionary *quota = stats[@"quota"];
    NSDictionary *summary = stats[@"summary"];
    NSDictionary *today = stats[@"today"];

    // 1. Header: Status & PID
    BOOL isOnline = (stats != nil);
    NSNumber *pidNum = quota[@"pid"];
    NSString *headerTitle = isOnline ?
        [NSString stringWithFormat:@"● Antigravity 监控在线 (PID: %@)", pidNum ?: @"-"] :
        @"○ Antigravity 监控离线 (正在重连...)";
    
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:headerTitle action:nil keyEquivalent:@""];
    headerItem.enabled = NO;
    [menu addItem:headerItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // 2. Quotas Section
    NSMenuItem *quotaSection = [[NSMenuItem alloc] initWithTitle:@"⏱️ 实时限额 (Quotas)" action:nil keyEquivalent:@""];
    quotaSection.enabled = NO;
    [menu addItem:quotaSection];

    if (quota && [quota[@"groups"] isKindOfClass:[NSArray class]]) {
        for (NSDictionary *g in quota[@"groups"]) {
            for (NSDictionary *b in g[@"buckets"]) {
                NSString *bName = b[@"displayName"] ?: b[@"bucketId"];
                double rem = [b[@"remainingFraction"] doubleValue];
                NSString *resetStr = [self formatResetTime:b[@"resetTime"]];
                NSString *emoji = [self statusEmojiForFraction:rem];

                NSString *itemText;
                if ([b[@"bucketId"] isEqualToString:@"gemini-5h"]) {
                    itemText = [NSString stringWithFormat:@"   %@ Gemini 5h 限额: %.1f%% (%@)", emoji, rem * 100.0, resetStr];
                } else if ([b[@"bucketId"] isEqualToString:@"gemini-weekly"]) {
                    itemText = [NSString stringWithFormat:@"   %@ Gemini 周限额: %.1f%% (%@)", emoji, rem * 100.0, resetStr];
                } else if ([b[@"bucketId"] isEqualToString:@"3p-5h"]) {
                    itemText = [NSString stringWithFormat:@"   %@ Claude/GPT 5h: %.1f%% (%@)", emoji, rem * 100.0, resetStr];
                } else {
                    itemText = [NSString stringWithFormat:@"   %@ %@: %.1f%%", emoji, bName, rem * 100.0];
                }

                NSMenuItem *bItem = [[NSMenuItem alloc] initWithTitle:itemText action:nil keyEquivalent:@""];
                bItem.enabled = NO;
                [menu addItem:bItem];
            }
        }
    } else {
        NSMenuItem *noQuota = [[NSMenuItem alloc] initWithTitle:@"   暂无配额数据" action:nil keyEquivalent:@""];
        noQuota.enabled = NO;
        [menu addItem:noQuota];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    // 3. Tokens & Usage Section
    NSMenuItem *tokenSection = [[NSMenuItem alloc] initWithTitle:@"📊 Token 统计" action:nil keyEquivalent:@""];
    tokenSection.enabled = NO;
    [menu addItem:tokenSection];

    if (summary) {
        long long total = [summary[@"total_tokens"] longLongValue];
        long long prompt = [summary[@"prompt_tokens"] longLongValue];
        long long output = [summary[@"output_tokens"] longLongValue];
        double cacheRate = [summary[@"cache_discount_rate"] doubleValue];
        double estCost = [summary[@"estimated_cost_usd"] doubleValue];
        double savedCost = [summary[@"saved_cost_usd"] doubleValue];

        NSString *totalLine = [NSString stringWithFormat:@"   总计 Token: %@", [self formatNumberWithCommas:total]];
        NSMenuItem *totalItem = [[NSMenuItem alloc] initWithTitle:totalLine action:nil keyEquivalent:@""];
        totalItem.enabled = NO;
        [menu addItem:totalItem];

        NSString *ioLine = [NSString stringWithFormat:@"   Prompt: %@  |  Output: %@", [self formatTokens:prompt], [self formatTokens:output]];
        NSMenuItem *ioItem = [[NSMenuItem alloc] initWithTitle:ioLine action:nil keyEquivalent:@""];
        ioItem.enabled = NO;
        [menu addItem:ioItem];

        NSString *cacheLine = [NSString stringWithFormat:@"   缓存命中: %.1f%% (节省 $%.2f)", cacheRate * 100.0, savedCost];
        NSMenuItem *cacheItem = [[NSMenuItem alloc] initWithTitle:cacheLine action:nil keyEquivalent:@""];
        cacheItem.enabled = NO;
        [menu addItem:cacheItem];

        NSString *costLine = [NSString stringWithFormat:@"   预估总费用: $%.2f", estCost];
        NSMenuItem *costItem = [[NSMenuItem alloc] initWithTitle:costLine action:nil keyEquivalent:@""];
        costItem.enabled = NO;
        [menu addItem:costItem];

        if (today && [today[@"total_tokens"] longLongValue] > 0) {
            long long todayTokens = [today[@"total_tokens"] longLongValue];
            double todayCost = [today[@"estimated_cost_usd"] doubleValue];
            NSString *todayLine = [NSString stringWithFormat:@"   今日消耗: %@ (~$%.2f)", [self formatTokens:todayTokens], todayCost];
            NSMenuItem *todayItem = [[NSMenuItem alloc] initWithTitle:todayLine action:nil keyEquivalent:@""];
            todayItem.enabled = NO;
            [menu addItem:todayItem];
        }
    } else {
        NSMenuItem *noSummary = [[NSMenuItem alloc] initWithTitle:@"   暂无消耗数据" action:nil keyEquivalent:@""];
        noSummary.enabled = NO;
        [menu addItem:noSummary];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    // 4. Action Items
    NSMenuItem *webItem = [[NSMenuItem alloc] initWithTitle:@"🌐 打开完整 Web 仪表盘..."
                                                     action:@selector(openDashboard:)
                                              keyEquivalent:@"o"];
    webItem.target = self;
    [menu addItem:webItem];

    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"🔄 立即刷新数据"
                                                         action:@selector(refreshClicked:)
                                                  keyEquivalent:@"r"];
    refreshItem.target = self;
    [menu addItem:refreshItem];

    // Display mode switcher
    NSArray *modes = @[@"配额 + Token", @"仅显示配额", @"仅显示 Token", @"仅显示图标"];
    NSString *currentModeName = modes[self.displayMode % modes.count];
    NSString *modeTitle = [NSString stringWithFormat:@"🔀 顶栏格式: %@", currentModeName];
    NSMenuItem *modeItem = [[NSMenuItem alloc] initWithTitle:modeTitle
                                                      action:@selector(toggleDisplayMode:)
                                               keyEquivalent:@""];
    modeItem.target = self;
    [menu addItem:modeItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // 5. Quit Item
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出 Antigravity Monitor"
                                                      action:@selector(quitApp:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

#pragma mark - Actions

- (void)openDashboard:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://127.0.0.1:8765"]];
}

- (void)refreshClicked:(id)sender {
    [self fetchStats];
}

- (void)toggleDisplayMode:(id)sender {
    self.displayMode = (self.displayMode + 1) % 4;
    if (self.latestStats) {
        [self updateUIWithStats:self.latestStats];
    } else {
        [self updateMenu];
    }
}

- (void)quitApp:(id)sender {
    [NSApp terminate:nil];
}

- (void)sendNotificationWithTitle:(NSString *)title message:(NSString *)msg {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *escapedMsg = [msg stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        NSString *escapedTitle = [title stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        NSString *script = [NSString stringWithFormat:@"display notification \"%@\" with title \"%@\"", escapedMsg, escapedTitle];

        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/osascript";
        task.arguments = @[@"-e", script];
        @try {
            [task launch];
        } @catch (NSException *e) {
            // ignore
        }
    });
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
