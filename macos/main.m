//
//  main.m
//  Antigravity Monitor (macOS Menu Bar Extra)
//
//  Polished native Apple-grade status bar application inspired by CodexBar.
//  Zero emoji clutter, native custom NSView card, fluid capsule progress bars,
//  San Francisco typography, bilingual (i18n) support, quantum levitation vector logo,
//  and integrated version update checker.
//

#import <Cocoa/Cocoa.h>

#define CARD_WIDTH 310.0

typedef NS_ENUM(NSInteger, DisplayMode) {
    DisplayModeQuotaAndTokens = 0, // [Logo] 65.1% · 9.2M
    DisplayModeQuotaOnly      = 1, // [Logo] 65.1%
    DisplayModeIconOnly       = 2  // [Logo]
};

typedef NS_ENUM(NSInteger, AppLanguage) {
    AppLanguageZH = 0, // 中文
    AppLanguageEN = 1  // English
};

#pragma mark - Localization & Helpers

static AppLanguage CurrentAppLanguage(void) {
    NSString *lang = [[NSUserDefaults standardUserDefaults] stringForKey:@"appLanguage"];
    if ([lang isEqualToString:@"en"]) return AppLanguageEN;
    return AppLanguageZH;
}

static void ToggleAppLanguage(void) {
    if (CurrentAppLanguage() == AppLanguageZH) {
        [[NSUserDefaults standardUserDefaults] setObject:@"en" forKey:@"appLanguage"];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:@"zh" forKey:@"appLanguage"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static NSString *Loc(NSString *zh, NSString *en) {
    return (CurrentAppLanguage() == AppLanguageEN) ? en : zh;
}

static NSImage *CreateAntigravityLogoImage(void) {
    NSSize size = NSMakeSize(16.0, 16.0);
    NSImage *image = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [[NSColor blackColor] setStroke];
        [[NSColor blackColor] setFill];

        // 1. Lower Levitation Cradle (smooth upward parabolic arc)
        NSBezierPath *cradle = [NSBezierPath bezierPath];
        [cradle moveToPoint:NSMakePoint(2.2, 6.8)];
        [cradle curveToPoint:NSMakePoint(13.8, 6.8)
               controlPoint1:NSMakePoint(3.4, 2.4)
               controlPoint2:NSMakePoint(12.6, 2.4)];
        cradle.lineWidth = 1.6;
        cradle.lineCapStyle = NSLineCapStyleRound;
        [cradle stroke];

        // 2. Central Floating Quantum Core (luminous solid sphere)
        NSRect coreRect = NSMakeRect(5.8, 6.8, 4.4, 4.4);
        NSBezierPath *core = [NSBezierPath bezierPathWithOvalInRect:coreRect];
        [core fill];

        // 3. Upper Levitation Halo (delicate curved arc)
        NSBezierPath *halo = [NSBezierPath bezierPath];
        [halo moveToPoint:NSMakePoint(4.6, 11.6)];
        [halo curveToPoint:NSMakePoint(11.4, 11.6)
             controlPoint1:NSMakePoint(6.0, 14.2)
             controlPoint2:NSMakePoint(10.0, 14.2)];
        halo.lineWidth = 1.3;
        halo.lineCapStyle = NSLineCapStyleRound;
        [halo stroke];

        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

static NSString *FormatTokens(long long num) {
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

static NSTextField *CreateLabel(NSString *text, CGFloat fontSize, NSFontWeight weight, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:fontSize weight:weight];
    label.textColor = color ?: [NSColor labelColor];
    label.backgroundColor = [NSColor clearColor];
    label.bezeled = NO;
    label.editable = NO;
    label.selectable = NO;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

#pragma mark - Custom Progress Bar (MetricBarView)

@interface MetricBarView : NSView
@property (nonatomic, assign) double fraction;
@property (nonatomic, strong) NSColor *tintColor;
@end

@implementation MetricBarView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _fraction = 1.0;
        _tintColor = [NSColor systemGreenColor];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect bounds = self.bounds;
    CGFloat radius = bounds.size.height / 2.0;

    // Track background
    NSBezierPath *trackPath = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:radius yRadius:radius];
    [[NSColor colorWithWhite:0.5 alpha:0.18] setFill];
    [trackPath fill];

    // Progress fill
    double f = MAX(0.0, MIN(1.0, self.fraction));
    if (f > 0.0) {
        CGFloat fillW = MAX(radius * 2.0, bounds.size.width * f);
        if (fillW > bounds.size.width) fillW = bounds.size.width;
        NSRect fillRect = NSMakeRect(bounds.origin.x, bounds.origin.y, fillW, bounds.size.height);
        NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:radius yRadius:radius];
        [(self.tintColor ?: [NSColor systemGreenColor]) setFill];
        [fillPath fill];
    }
}

- (void)setFraction:(double)fraction {
    _fraction = fraction;
    [self setNeedsDisplay:YES];
}

- (void)setTintColor:(NSColor *)tintColor {
    _tintColor = tintColor;
    [self setNeedsDisplay:YES];
}

@end

#pragma mark - Metric Row View (MetricRowView)

@interface MetricRowView : NSView
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) MetricBarView *barView;
@property (nonatomic, strong) NSTextField *leftMetaLabel;
@property (nonatomic, strong) NSTextField *rightMetaLabel;
@end

@implementation MetricRowView

- (instancetype)initWithFrame:(NSRect)frame title:(NSString *)title {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat w = frame.size.width;
        
        _titleLabel = CreateLabel(title, 12.0, NSFontWeightMedium, [NSColor labelColor]);
        _titleLabel.frame = NSMakeRect(0, 0, w, 16);
        [self addSubview:_titleLabel];

        _barView = [[MetricBarView alloc] initWithFrame:NSMakeRect(0, 19, w, 5)];
        [self addSubview:_barView];

        _leftMetaLabel = CreateLabel(@"--.-% 剩余", 11.0, NSFontWeightRegular, [NSColor secondaryLabelColor]);
        _leftMetaLabel.frame = NSMakeRect(0, 27, w * 0.55, 14);
        [self addSubview:_leftMetaLabel];

        _rightMetaLabel = CreateLabel(@"", 11.0, NSFontWeightRegular, [NSColor secondaryLabelColor]);
        _rightMetaLabel.alignment = NSTextAlignmentRight;
        _rightMetaLabel.frame = NSMakeRect(w * 0.45, 27, w * 0.55, 14);
        [self addSubview:_rightMetaLabel];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)setRemainingFraction:(double)fraction resetText:(NSString *)resetText {
    self.barView.fraction = fraction;
    
    // Choose color based on remaining fraction
    if (fraction >= 0.30) {
        self.barView.tintColor = [NSColor systemGreenColor];
    } else if (fraction >= 0.15) {
        self.barView.tintColor = [NSColor systemOrangeColor];
    } else {
        self.barView.tintColor = [NSColor systemRedColor];
    }

    self.leftMetaLabel.stringValue = [NSString stringWithFormat:Loc(@"%.1f%% 剩余", @"%.1f%% Left"), fraction * 100.0];
    self.rightMetaLabel.stringValue = resetText ?: @"";
}

@end

#pragma mark - Badge View (BadgeView)

@interface BadgeView : NSView
@property (nonatomic, strong) NSTextField *label;
@end

@implementation BadgeView

- (instancetype)initWithText:(NSString *)text {
    self = [super initWithFrame:NSMakeRect(0, 0, 80, 18)];
    if (self) {
        _label = CreateLabel(text, 9.5, NSFontWeightSemibold, [NSColor secondaryLabelColor]);
        _label.alignment = NSTextAlignmentCenter;
        _label.frame = NSMakeRect(6, 1, 68, 14);
        [self addSubview:_label];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect bounds = self.bounds;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5) xRadius:4.0 yRadius:4.0];
    [[NSColor colorWithWhite:0.5 alpha:0.12] setFill];
    [path fill];
    [[NSColor colorWithWhite:0.5 alpha:0.25] setStroke];
    path.lineWidth = 0.8;
    [path stroke];
}

- (void)setText:(NSString *)text {
    self.label.stringValue = text ?: @"";
    [self.label sizeToFit];
    CGFloat newW = MAX(56.0, self.label.frame.size.width + 12.0);
    self.frame = NSMakeRect(self.frame.origin.x, self.frame.origin.y, newW, 18.0);
    self.label.frame = NSMakeRect(6, 1, newW - 12.0, 14.0);
    [self setNeedsDisplay:YES];
}

@end

#pragma mark - Polished Menu Card View (AntigravityCardView)

@interface AntigravityCardView : NSView
@property (nonatomic, strong) NSTextField *appNameLabel;
@property (nonatomic, strong) NSTextField *statusSubtitleLabel;
@property (nonatomic, strong) BadgeView *tierBadge;

@property (nonatomic, strong) MetricRowView *gemini5hRow;
@property (nonatomic, strong) MetricRowView *geminiWeeklyRow;
@property (nonatomic, strong) MetricRowView *thirdPartyRow;

@property (nonatomic, strong) NSTextField *usageSectionTitle;
@property (nonatomic, strong) NSTextField *weekUsageLeftLabel;
@property (nonatomic, strong) NSTextField *weekUsageRightLabel;
@property (nonatomic, strong) NSTextField *cacheLeftLabel;
@property (nonatomic, strong) NSTextField *cacheRightLabel;
@property (nonatomic, strong) NSTextField *todayUsageLeftLabel;
@property (nonatomic, strong) NSTextField *todayUsageRightLabel;

@property (nonatomic, strong) NSISO8601DateFormatter *isoFormatter;
@end

@implementation AntigravityCardView

- (BOOL)isFlipped {
    return YES;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isoFormatter = [[NSISO8601DateFormatter alloc] init];
        CGFloat paddingX = 14.0;
        CGFloat contentW = CARD_WIDTH - (paddingX * 2.0);
        CGFloat y = 12.0;

        // 1. Header: App title, subtitle, tier badge
        _appNameLabel = CreateLabel(@"Antigravity", 14.0, NSFontWeightBold, [NSColor labelColor]);
        _appNameLabel.frame = NSMakeRect(paddingX, y, contentW - 90, 18);
        [self addSubview:_appNameLabel];

        _tierBadge = [[BadgeView alloc] initWithText:@"Google AI Pro"];
        _tierBadge.frame = NSMakeRect(CARD_WIDTH - paddingX - 80, y - 1, 80, 18);
        [self addSubview:_tierBadge];

        y += 20.0;
        _statusSubtitleLabel = CreateLabel(Loc(@"正在连接本地语言服务...", @"Connecting to Language Server..."), 11.0, NSFontWeightRegular, [NSColor secondaryLabelColor]);
        _statusSubtitleLabel.frame = NSMakeRect(paddingX, y, contentW, 14);
        [self addSubview:_statusSubtitleLabel];

        y += 20.0;
        // Divider 1
        [self addDividerAtY:y width:contentW paddingX:paddingX];
        y += 10.0;

        // 2. Metrics Section (5-hour, Weekly, 3P)
        _gemini5hRow = [[MetricRowView alloc] initWithFrame:NSMakeRect(paddingX, y, contentW, 44) title:Loc(@"Gemini 5 小时限额", @"Gemini 5-Hour Limit")];
        [self addSubview:_gemini5hRow];
        y += 48.0;

        _geminiWeeklyRow = [[MetricRowView alloc] initWithFrame:NSMakeRect(paddingX, y, contentW, 44) title:Loc(@"Gemini 每周限额", @"Gemini Weekly Limit")];
        [self addSubview:_geminiWeeklyRow];
        y += 48.0;

        _thirdPartyRow = [[MetricRowView alloc] initWithFrame:NSMakeRect(paddingX, y, contentW, 44) title:Loc(@"Claude & GPT 额度", @"Claude & GPT Quota")];
        [self addSubview:_thirdPartyRow];
        y += 48.0;

        // Divider 2
        [self addDividerAtY:y width:contentW paddingX:paddingX];
        y += 10.0;

        // 3. Usage & Spend Section (Token-first sequence)
        _usageSectionTitle = CreateLabel(Loc(@"用量与活动 (Usage & Activity)", @"Usage & Activity"), 11.0, NSFontWeightSemibold, [NSColor secondaryLabelColor]);
        _usageSectionTitle.frame = NSMakeRect(paddingX, y, contentW, 14);
        [self addSubview:_usageSectionTitle];
        y += 18.0;

        // Row 1: Last 7 Days Token Usage
        _weekUsageLeftLabel = CreateLabel(Loc(@"近 7 天 Token 消耗", @"Last 7 Days Tokens"), 11.5, NSFontWeightRegular, [NSColor labelColor]);
        _weekUsageLeftLabel.frame = NSMakeRect(paddingX, y, contentW * 0.45, 15);
        [self addSubview:_weekUsageLeftLabel];

        _weekUsageRightLabel = CreateLabel(@"0 ($0.00)", 11.5, NSFontWeightMedium, [NSColor labelColor]);
        _weekUsageRightLabel.alignment = NSTextAlignmentRight;
        _weekUsageRightLabel.frame = NSMakeRect(paddingX + contentW * 0.45, y, contentW * 0.55, 15);
        [self addSubview:_weekUsageRightLabel];
        y += 18.0;

        // Row 2: Cache Hit Rate & Savings
        _cacheLeftLabel = CreateLabel(Loc(@"上下文缓存命中率", @"Context Cache Rate"), 11.0, NSFontWeightRegular, [NSColor secondaryLabelColor]);
        _cacheLeftLabel.frame = NSMakeRect(paddingX, y, contentW * 0.45, 14);
        [self addSubview:_cacheLeftLabel];

        _cacheRightLabel = CreateLabel(@"0.0% (省下 $0.00)", 11.0, NSFontWeightRegular, [NSColor secondaryLabelColor]);
        _cacheRightLabel.alignment = NSTextAlignmentRight;
        _cacheRightLabel.frame = NSMakeRect(paddingX + contentW * 0.45, y, contentW * 0.55, 14);
        [self addSubview:_cacheRightLabel];
        y += 17.0;

        // Row 3: Today's Token Usage
        _todayUsageLeftLabel = CreateLabel(Loc(@"今日 Token 消耗", @"Today's Tokens"), 11.0, NSFontWeightRegular, [NSColor secondaryLabelColor]);
        _todayUsageLeftLabel.frame = NSMakeRect(paddingX, y, contentW * 0.45, 14);
        [self addSubview:_todayUsageLeftLabel];

        _todayUsageRightLabel = CreateLabel(@"0 ($0.00)", 11.0, NSFontWeightRegular, [NSColor secondaryLabelColor]);
        _todayUsageRightLabel.alignment = NSTextAlignmentRight;
        _todayUsageRightLabel.frame = NSMakeRect(paddingX + contentW * 0.45, y, contentW * 0.55, 14);
        [self addSubview:_todayUsageRightLabel];
    }
    return self;
}

- (void)applyLocalization {
    _gemini5hRow.titleLabel.stringValue = Loc(@"Gemini 5 小时限额", @"Gemini 5-Hour Limit");
    _geminiWeeklyRow.titleLabel.stringValue = Loc(@"Gemini 每周限额", @"Gemini Weekly Limit");
    _thirdPartyRow.titleLabel.stringValue = Loc(@"Claude & GPT 额度", @"Claude & GPT Quota");
    _usageSectionTitle.stringValue = Loc(@"用量与活动 (Usage & Activity)", @"Usage & Activity");
    _weekUsageLeftLabel.stringValue = Loc(@"近 7 天 Token 消耗", @"Last 7 Days Tokens");
    _cacheLeftLabel.stringValue = Loc(@"上下文缓存命中率", @"Context Cache Rate");
    _todayUsageLeftLabel.stringValue = Loc(@"今日 Token 消耗", @"Today's Tokens");
    [self setNeedsDisplay:YES];
}

- (void)addDividerAtY:(CGFloat)y width:(CGFloat)width paddingX:(CGFloat)paddingX {
    NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(paddingX, y, width, 1.0)];
    divider.boxType = NSBoxSeparator;
    [self addSubview:divider];
}

- (NSString *)formatResetCountdown:(NSString *)isoString {
    if (!isoString || [isoString isEqualToString:@""]) return @"";
    NSDate *date = [self.isoFormatter dateFromString:isoString];
    if (!date) return @"";

    NSTimeInterval diff = [date timeIntervalSinceDate:[NSDate date]];
    if (diff <= 0) return Loc(@"已重置", @"Reset");

    int hours = (int)(diff / 3600);
    int minutes = (int)(((long)diff % 3600) / 60);
    int days = hours / 24;

    if (days > 0) {
        return [NSString stringWithFormat:Loc(@"%dd %dh 后重置", @"%dd %dh left"), days, hours % 24];
    } else if (hours > 0) {
        return [NSString stringWithFormat:Loc(@"%dh %dm 后重置", @"%dh %dm left"), hours, minutes];
    } else {
        return [NSString stringWithFormat:Loc(@"%dm 后重置", @"%dm left"), minutes];
    }
}

- (void)updateWithStats:(NSDictionary *)stats {
    NSDictionary *quota = stats[@"quota"];
    NSDictionary *summary = stats[@"summary"];

    BOOL isLSConnected = (quota != nil && [quota[@"status"] isEqualToString:@"ok"]);
    NSNumber *pidNum = quota[@"pid"];

    if (isLSConnected) {
        self.statusSubtitleLabel.stringValue = [NSString stringWithFormat:Loc(@"Language Server 运行中 · PID %@", @"Language Server Active · PID %@"), pidNum ?: @"-"];
        self.statusSubtitleLabel.textColor = [NSColor secondaryLabelColor];
    } else {
        self.statusSubtitleLabel.stringValue = Loc(@"Language Server 离线 (未检测到进程)", @"Language Server Offline (Process not found)");
        self.statusSubtitleLabel.textColor = [NSColor systemOrangeColor];
    }

    NSString *userTier = quota[@"user_tier"] ?: @"Google AI Pro";
    [self.tierBadge setText:userTier];

    // Parse Buckets
    double gemini5hFraction = 1.0;
    NSString *gemini5hReset = @"";
    double geminiWeeklyFraction = 1.0;
    NSString *geminiWeeklyReset = @"";
    double thirdPartyFraction = 1.0;
    NSString *thirdPartyReset = @"";

    if (quota && [quota[@"groups"] isKindOfClass:[NSArray class]]) {
        for (NSDictionary *g in quota[@"groups"]) {
            for (NSDictionary *b in g[@"buckets"]) {
                NSString *bId = b[@"bucketId"] ?: @"";
                double rem = [b[@"remainingFraction"] doubleValue];
                NSString *countdown = [self formatResetCountdown:b[@"resetTime"]];

                if ([bId isEqualToString:@"gemini-5h"]) {
                    gemini5hFraction = rem;
                    gemini5hReset = countdown;
                } else if ([bId isEqualToString:@"gemini-weekly"]) {
                    geminiWeeklyFraction = rem;
                    geminiWeeklyReset = countdown;
                } else if ([bId isEqualToString:@"3p-5h"] || [bId isEqualToString:@"3p-weekly"]) {
                    thirdPartyFraction = rem;
                    thirdPartyReset = countdown;
                }
            }
        }
    }

    [self.gemini5hRow setRemainingFraction:gemini5hFraction resetText:gemini5hReset];
    [self.geminiWeeklyRow setRemainingFraction:geminiWeeklyFraction resetText:geminiWeeklyReset];
    [self.thirdPartyRow setRemainingFraction:thirdPartyFraction resetText:thirdPartyReset];

    // Usage & Summary (Usage-first sequence)
    NSDictionary *last7d = stats[@"last_7d"];
    NSDictionary *today = stats[@"today"];

    if (summary) {
        long long total = [summary[@"total_tokens"] longLongValue];
        long long cached = [summary[@"cached_tokens"] longLongValue];
        double savedUsd = [summary[@"saved_usd"] doubleValue];

        double cacheRate = (total > 0) ? ((double)cached / (double)total) * 100.0 : 0.0;

        // Row 1: Last 7 Days Token Usage
        long long weekTokens = [last7d[@"total_tokens"] longLongValue];
        double weekCost = [last7d[@"cost_usd"] doubleValue];
        if (weekTokens == 0) {
            weekTokens = total;
            weekCost = [summary[@"cost_usd"] doubleValue];
        }
        self.weekUsageRightLabel.stringValue = [NSString stringWithFormat:@"%@ ($%.2f)", FormatTokens(weekTokens), weekCost];

        // Row 2: Cache Hit Rate & Savings
        self.cacheRightLabel.stringValue = [NSString stringWithFormat:Loc(@"%.1f%% (省下 $%.2f)", @"%.1f%% (Saved $%.2f)"), cacheRate, savedUsd];

        // Row 3: Today's Token Usage
        long long todayTokens = [today[@"total_tokens"] longLongValue];
        double todayCost = [today[@"cost_usd"] doubleValue];
        self.todayUsageRightLabel.stringValue = [NSString stringWithFormat:@"%@ ($%.2f)", FormatTokens(todayTokens), todayCost];
    }
}

- (void)updateOffline {
    self.statusSubtitleLabel.stringValue = Loc(@"本地监控服务离线 (正在自动重连...)", @"Local Monitor Service Offline (Reconnecting...)");
    self.statusSubtitleLabel.textColor = [NSColor systemRedColor];
}

@end

#pragma mark - App Delegate (AppDelegate)

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSDictionary *latestStats;
@property (strong, nonatomic) AntigravityCardView *cardView;
@property (assign, nonatomic) DisplayMode displayMode;
@property (assign, nonatomic) BOOL notifiedLowQuota;
@property (assign, nonatomic) BOOL serverAutoStartAttempted;
@property (assign, nonatomic) long long lastObservedTokens;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.displayMode = DisplayModeQuotaAndTokens;
    self.notifiedLowQuota = NO;
    self.serverAutoStartAttempted = NO;
    self.lastObservedTokens = 0;

    // Accessory menu bar extra: no Dock icon, never steal window focus
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    // Card frame: 310 x 286
    self.cardView = [[AntigravityCardView alloc] initWithFrame:NSMakeRect(0, 0, CARD_WIDTH, 286.0)];

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
    self.statusItem.button.image = CreateAntigravityLogoImage();
    self.statusItem.button.imagePosition = NSImageLeft;
    self.statusItem.button.title = @" --.-%";
    self.statusItem.button.toolTip = @"Antigravity Token Monitor";
    [self buildMenu];
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
        self.statusItem.button.title = Loc(@" 离线", @" Offline");
        [self.cardView updateOffline];
    }

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
                // ignore
            }
        }
    });
}

#pragma mark - UI Updates

- (void)updateUIWithStats:(NSDictionary *)stats {
    NSDictionary *quota = stats[@"quota"];
    NSDictionary *summary = stats[@"summary"];

    // Update custom card view
    [self.cardView updateWithStats:stats];

    // Extract 5h quota fraction
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

    // Output tokens
    long long outputTokens = [summary[@"output_tokens"] longLongValue];
    if (outputTokens == 0) outputTokens = [summary[@"total_tokens"] longLongValue];
    long long totalTokens = [summary[@"total_tokens"] longLongValue];

    // Low quota notification with continuous consumption guard
    if (gemini5hFraction >= 0.0 && gemini5hFraction <= 0.15) {
        if (self.lastObservedTokens > 0 && totalTokens > self.lastObservedTokens) {
            if (!self.notifiedLowQuota) {
                self.notifiedLowQuota = YES;
                [self sendNotificationWithTitle:Loc(@"Antigravity 额度预警", @"Antigravity Quota Alert")
                                        message:[NSString stringWithFormat:Loc(@"Gemini 5小时额度仅剩 %.1f%%，建议放缓调用或切换模型。", @"Gemini 5-hour quota is down to %.1f%%. Consider slowing down or switching models."), gemini5hFraction * 100.0]];
            }
        }
    } else if (gemini5hFraction > 0.25) {
        self.notifiedLowQuota = NO;
    }
    self.lastObservedTokens = totalTokens;

    // Top Bar Title Formatting (Clean typography with native vector template logo)
    NSString *quotaStr = (gemini5hFraction >= 0.0) ? [NSString stringWithFormat:@"%.1f%%", gemini5hFraction * 100.0] : @"--.-%";
    NSString *tokenStr = FormatTokens(outputTokens);

    switch (self.displayMode) {
        case DisplayModeQuotaAndTokens:
            self.statusItem.button.title = [NSString stringWithFormat:@" %@ · %@", quotaStr, tokenStr];
            break;
        case DisplayModeQuotaOnly:
            self.statusItem.button.title = [NSString stringWithFormat:@" %@", quotaStr];
            break;
        case DisplayModeIconOnly:
            self.statusItem.button.title = @"";
            break;
    }
}

#pragma mark - Menu Construction

- (void)buildMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;

    // 1. Embed the sleek native card view directly in the top menu item
    NSMenuItem *cardItem = [[NSMenuItem alloc] init];
    cardItem.view = self.cardView;
    [menu addItem:cardItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // 2. Action Items
    NSMenuItem *webItem = [[NSMenuItem alloc] initWithTitle:Loc(@"打开 Web 完整仪表盘...", @"Open Web Dashboard...")
                                                     action:@selector(openDashboard:)
                                              keyEquivalent:@"o"];
    webItem.target = self;
    [menu addItem:webItem];

    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:Loc(@"立即刷新数据", @"Refresh Stats Now")
                                                         action:@selector(refreshClicked:)
                                                  keyEquivalent:@"r"];
    refreshItem.target = self;
    [menu addItem:refreshItem];

    NSArray *modeNamesZh = @[@"配额 + Token", @"仅配额", @"仅图标"];
    NSArray *modeNamesEn = @[@"Quota + Tokens", @"Quota Only", @"Icon Only"];
    NSString *currentMode = (CurrentAppLanguage() == AppLanguageEN) ? modeNamesEn[self.displayMode % 3] : modeNamesZh[self.displayMode % 3];
    NSString *modeTitle = [NSString stringWithFormat:Loc(@"切换顶栏格式 (%@)", @"Display Mode (%@)"), currentMode];
    NSMenuItem *modeItem = [[NSMenuItem alloc] initWithTitle:modeTitle
                                                      action:@selector(toggleDisplayMode:)
                                               keyEquivalent:@""];
    modeItem.target = self;
    [menu addItem:modeItem];

    // Language toggle item
    NSString *langTitle = Loc(@"切换语言 (中文 ➔ English)", @"Switch Language (English ➔ 中文)");
    NSMenuItem *langItem = [[NSMenuItem alloc] initWithTitle:langTitle
                                                      action:@selector(toggleLanguage:)
                                               keyEquivalent:@"l"];
    langItem.target = self;
    [menu addItem:langItem];

    // Check updates item
    NSMenuItem *updateItem = [[NSMenuItem alloc] initWithTitle:Loc(@"检查更新...", @"Check for Updates...")
                                                        action:@selector(checkForUpdates:)
                                                 keyEquivalent:@"u"];
    updateItem.target = self;
    [menu addItem:updateItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // 3. Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:Loc(@"退出 Antigravity Monitor", @"Quit Antigravity Monitor")
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
    [self buildMenu];
    if (self.latestStats) {
        [self updateUIWithStats:self.latestStats];
    }
}

- (void)toggleLanguage:(id)sender {
    ToggleAppLanguage();
    [self.cardView applyLocalization];
    [self buildMenu];
    if (self.latestStats) {
        [self updateUIWithStats:self.latestStats];
    }
}

- (void)checkForUpdates:(id)sender {
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8765/api/check_update"];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 4.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !data) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = Loc(@"检查更新失败", @"Update Check Failed");
                alert.informativeText = Loc(@"未能连接到本地更新服务，请确认监控服务正在运行。", @"Could not connect to update service. Please ensure the monitor service is active.");
                [alert addButtonWithTitle:Loc(@"确定", @"OK")];
                [alert runModal];
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL hasUpdate = [json[@"has_update"] boolValue];
            NSString *curVer = json[@"current_version"] ?: @"1.2.0";
            NSString *latVer = json[@"latest_version"] ?: curVer;
            NSString *notes = (CurrentAppLanguage() == AppLanguageEN) ? (json[@"release_notes_en"] ?: json[@"release_notes"]) : json[@"release_notes"];

            NSAlert *alert = [[NSAlert alloc] init];
            if (hasUpdate) {
                alert.messageText = Loc([NSString stringWithFormat:@"发现新版本 %@", latVer], [NSString stringWithFormat:@"New Version %@ Available", latVer]);
                alert.informativeText = Loc([NSString stringWithFormat:@"当前版本: %@\n\n更新说明:\n%@\n\n是否立即更新并重启应用？", curVer, notes ?: @""], [NSString stringWithFormat:@"Current version: %@\n\nRelease notes:\n%@\n\nUpdate and restart now?", curVer, notes ?: @""]);
                [alert addButtonWithTitle:Loc(@"立即更新", @"Update Now")];
                [alert addButtonWithTitle:Loc(@"稍后提醒", @"Later")];
                NSModalResponse res = [alert runModal];
                if (res == NSAlertFirstButtonReturn) {
                    [strongSelf performAutoUpdate];
                }
            } else {
                alert.messageText = Loc(@"已是最新版本", @"You're Up to Date");
                alert.informativeText = Loc([NSString stringWithFormat:@"当前版本 v%@ 为最新版本，包含最新特性与性能优化。", curVer], [NSString stringWithFormat:@"Current version v%@ is the latest release with all the newest features.", curVer]);
                [alert addButtonWithTitle:Loc(@"确定", @"OK")];
                [alert runModal];
            }
        });
    }];
    [task resume];
}

- (void)performAutoUpdate {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *projectDir = [bundlePath stringByDeletingLastPathComponent];
    NSString *rootScript = [[projectDir stringByAppendingPathComponent:@"../update.sh"] stringByStandardizingPath];

    if (![[NSFileManager defaultManager] fileExistsAtPath:rootScript]) {
        rootScript = [@"~/.gemini/antigravity/scratch/antigravity-token-monitor/update.sh" stringByExpandingTildeInPath];
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:rootScript]) {
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/bash";
        task.arguments = @[rootScript];
        @try {
            [task launch];
        } @catch (NSException *e) {}
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
