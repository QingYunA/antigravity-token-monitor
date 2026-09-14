//
//  main.m
//  Antigravity Monitor (macOS Menu Bar Extra)
//
//  Created for Antigravity Token Monitor
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, DisplayMode) {
    DisplayModeQuotaAndTokens = 0, // ⚡ 65.1% · 9.2M
    DisplayModeQuotaOnly      = 1, // ⚡ 65.1%
    DisplayModeIconOnly       = 2  // ⚡
};

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSDictionary *latestStats;
@property (assign, nonatomic) DisplayMode displayMode;
@property (assign, nonatomic) BOOL notifiedLowQuota;
@property (assign, nonatomic) BOOL serverAutoStartAttempted;
@property (assign, nonatomic) long long lastObservedTokens;
@property (strong, nonatomic) NSISO8601DateFormatter *isoFormatter;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.displayMode = DisplayModeQuotaAndTokens;
    self.notifiedLowQuota = NO;
    self.serverAutoStartAttempted = NO;
    self.lastObservedTokens = 0;
    self.isoFormatter = [[NSISO8601DateFormatter alloc] init];

    // Accessory menu bar extra: no Dock icon, never steal window focus
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    [self setupStatusItem];
    [self fetchStats];

    // Periodic polling timer on NSRunLoopCommonModes so UI interaction does not freeze the timer
    self.timer = [NSTimer timerWithTimeInterval:5.0
                                         target:self
                                       selector:@selector(fetchStats)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"⚡ --.-%";
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
        return [NSString stringWithFormat:@"%dd %dh 后刷新", days, hours % 24];
    } else if (hours > 0) {
        return [NSString stringWithFormat:@"%dh %dm 后刷新", hours, minutes];
    } else {
        return [NSString stringWithFormat:@"%dm 后刷新", minutes];
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
                strongSelf.serverAutoStartAttempted = NO;
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

    if (!self.serverAutoStartAttempted) {
        self.serverAutoStartAttempted = YES;
        [self attemptAutoStartServer];
    }
}

- (void)attemptAutoStartServer {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *parentDir = [bundlePath stringByDeletingLastPathComponent];
        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *homeDir = NSHomeDirectory();

        NSArray *candidatePaths = @[
            [parentDir stringByAppendingPathComponent:@"server.py"],
            [parentDir stringByAppendingPathComponent:@"../server.py"],
            [cwd stringByAppendingPathComponent:@"server.py"],
            [homeDir stringByAppendingPathComponent:@".gemini/antigravity/scratch/antigravity-token-monitor/server.py"]
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
                // ignore launch errors
            }
        }
    });
}

#pragma mark - UI Updates

- (void)updateUIWithStats:(NSDictionary *)stats {
    NSDictionary *quota = stats[@"quota"];
    NSDictionary *summary = stats[@"summary"];
    
    // Extract 5h fraction
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

    // Extract total output or total tokens
    long long outputTokens = [summary[@"output_tokens"] longLongValue];
    if (outputTokens == 0) {
        outputTokens = [summary[@"total_tokens"] longLongValue];
    }
    long long totalTokens = [summary[@"total_tokens"] longLongValue];

    // Low Quota Alert: only trigger when <= 15% AND continuous consumption is active
    if (gemini5hFraction >= 0.0 && gemini5hFraction <= 0.15) {
        if (self.lastObservedTokens > 0 && totalTokens > self.lastObservedTokens) {
            if (!self.notifiedLowQuota) {
                self.notifiedLowQuota = YES;
                [self sendNotificationWithTitle:@"Antigravity 额度预警"
                                        message:[NSString stringWithFormat:@"Gemini 5小时额度仅剩 %.1f%%，建议放缓调用或切换模型。", gemini5hFraction * 100.0]];
            }
        }
    } else if (gemini5hFraction > 0.25) {
        self.notifiedLowQuota = NO;
    }
    self.lastObservedTokens = totalTokens;

    // Status Item Title: exact 1 decimal digit precision (e.g. 65.1%)
    NSString *quotaStr = (gemini5hFraction >= 0.0) ? [NSString stringWithFormat:@"%.1f%%", gemini5hFraction * 100.0] : @"--.-%";
    NSString *tokenStr = [self formatTokens:outputTokens];

    switch (self.displayMode) {
        case DisplayModeQuotaAndTokens:
            self.statusItem.button.title = [NSString stringWithFormat:@"⚡ %@ · %@", quotaStr, tokenStr];
            break;
        case DisplayModeQuotaOnly:
            self.statusItem.button.title = [NSString stringWithFormat:@"⚡ %@", quotaStr];
            break;
        case DisplayModeIconOnly:
            self.statusItem.button.title = @"⚡";
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

    // 1. Header: Language Server Status & PID
    BOOL isLSConnected = (quota != nil && [quota[@"status"] isEqualToString:@"ok"]);
    NSNumber *pidNum = quota[@"pid"];
    NSString *headerTitle = isLSConnected ?
        [NSString stringWithFormat:@"● Antigravity 运行中 (PID: %@)", pidNum ?: @"-"] :
        @"○ Antigravity 离线 (未检测到进程)";
    
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:headerTitle action:nil keyEquivalent:@""];
    headerItem.enabled = NO;
    [menu addItem:headerItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // 2. Quotas Section
    NSMenuItem *quotaSection = [[NSMenuItem alloc] initWithTitle:@"⏱️ 额度监控" action:nil keyEquivalent:@""];
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
                    itemText = [NSString stringWithFormat:@"   Gemini 5h 剩余:  %.1f%% %@ (%@)", rem * 100.0, emoji, resetStr];
                } else if ([b[@"bucketId"] isEqualToString:@"gemini-weekly"]) {
                    itemText = [NSString stringWithFormat:@"   Gemini 周剩余:   %.1f%% %@ (%@)", rem * 100.0, emoji, resetStr];
                } else if ([b[@"bucketId"] isEqualToString:@"3p-5h"]) {
                    itemText = [NSString stringWithFormat:@"   3P (Claude/GPT): %.1f%% %@", rem * 100.0, emoji];
                } else {
                    itemText = [NSString stringWithFormat:@"   %@: %.1f%% %@", bName, rem * 100.0, emoji];
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
    NSMenuItem *tokenSection = [[NSMenuItem alloc] initWithTitle:@"📊 Token 消耗" action:nil keyEquivalent:@""];
    tokenSection.enabled = NO;
    [menu addItem:tokenSection];

    if (summary) {
        long long total = [summary[@"total_tokens"] longLongValue];
        long long prompt = [summary[@"prompt_tokens"] longLongValue];
        long long output = [summary[@"output_tokens"] longLongValue];
        long long cached = [summary[@"cached_tokens"] longLongValue];
        
        // Calculate true cache discount rate and fetch costs using exact backend keys
        double cacheRate = (total > 0) ? ((double)cached / (double)total) * 100.0 : 0.0;
        double estCost = [summary[@"cost_usd"] doubleValue];
        double savedCost = [summary[@"saved_usd"] doubleValue];

        NSString *totalLine = [NSString stringWithFormat:@"   总消耗 Token:    %@", [self formatNumberWithCommas:total]];
        NSMenuItem *totalItem = [[NSMenuItem alloc] initWithTitle:totalLine action:nil keyEquivalent:@""];
        totalItem.enabled = NO;
        [menu addItem:totalItem];

        NSString *ioLine = [NSString stringWithFormat:@"   Prompt / Output: %@ / %@", [self formatTokens:prompt], [self formatTokens:output]];
        NSMenuItem *ioItem = [[NSMenuItem alloc] initWithTitle:ioLine action:nil keyEquivalent:@""];
        ioItem.enabled = NO;
        [menu addItem:ioItem];

        NSString *cacheLine = [NSString stringWithFormat:@"   Context 缓存节省: %.1f%% (省下 $%.2f)", cacheRate, savedCost];
        NSMenuItem *cacheItem = [[NSMenuItem alloc] initWithTitle:cacheLine action:nil keyEquivalent:@""];
        cacheItem.enabled = NO;
        [menu addItem:cacheItem];

        NSString *costLine = [NSString stringWithFormat:@"   预估总费用:       $%.2f", estCost];
        NSMenuItem *costItem = [[NSMenuItem alloc] initWithTitle:costLine action:nil keyEquivalent:@""];
        costItem.enabled = NO;
        [menu addItem:costItem];
    } else {
        NSMenuItem *noSummary = [[NSMenuItem alloc] initWithTitle:@"   暂无消耗数据" action:nil keyEquivalent:@""];
        noSummary.enabled = NO;
        [menu addItem:noSummary];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    // 4. Action Items
    NSMenuItem *webItem = [[NSMenuItem alloc] initWithTitle:@"🌐 打开 Web 完整仪表盘..."
                                                     action:@selector(openDashboard:)
                                              keyEquivalent:@"o"];
    webItem.target = self;
    [menu addItem:webItem];

    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"🔄 立即刷新数据"
                                                         action:@selector(refreshClicked:)
                                                  keyEquivalent:@"r"];
    refreshItem.target = self;
    [menu addItem:refreshItem];

    // Display mode switcher (3 modes: 配额+Token / 仅配额 / 仅图标)
    NSArray *modes = @[@"配额 + Token", @"仅配额", @"仅图标"];
    NSString *currentModeName = modes[self.displayMode % modes.count];
    NSString *modeTitle = [NSString stringWithFormat:@"🔀 切换顶栏显示 (%@)", currentModeName];
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
    self.displayMode = (DisplayMode)((self.displayMode + 1) % 3);
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
