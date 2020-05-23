//
//  FWDebugTimeProfiler.m
//  FWDebug
//
//  Created by wuyong on 2020/5/18.
//  Copyright © 2020 wuyong.site. All rights reserved.
//

#import "FWDebugTimeProfiler.h"
#import "FWDebugAppConfig.h"
#import "FWDebugManager+FWDebug.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXNetworkRecorder.h"
#import <sys/sysctl.h>
#import <sys/time.h>
#import <objc/runtime.h>

#pragma mark - FWDebugTimeRecord

@interface FWDebugTimeInfo : NSObject

@property (nonatomic, copy, readonly) NSString *event;
@property (nonatomic, assign, readonly) NSTimeInterval time;
@property (nonatomic, weak, readonly) id userInfo;

@end

@implementation FWDebugTimeInfo

- (instancetype)initWithEvent:(NSString *)event time:(NSTimeInterval)time userInfo:(id)userInfo
{
    self = [super init];
    if (self) {
        _event = event;
        _time = time;
        _userInfo = userInfo;
    }
    return self;
}

@end

@interface FWDebugTimeRecord : NSObject

@property (nonatomic, strong) NSMutableArray<FWDebugTimeInfo *> *timeInfos;

@end

@implementation FWDebugTimeRecord

+ (instancetype)sharedInstance
{
    static FWDebugTimeRecord *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FWDebugTimeRecord alloc] init];
        [sharedInstance recordEvent:@"↧ App.startLaunch" time:[FWDebugTimeProfiler appLaunchedTime] userInfo:nil];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _timeInfos = [NSMutableArray new];
    }
    return self;
}

- (void)recordEvent:(NSString *)event userInfo:(id)userInfo
{
    [self.timeInfos addObject:[[FWDebugTimeInfo alloc] initWithEvent:event time:[FWDebugTimeProfiler currentTime] userInfo:userInfo]];
}

- (void)recordEvent:(NSString *)event time:(NSTimeInterval)time userInfo:(id)userInfo
{
    [self.timeInfos addObject:[[FWDebugTimeInfo alloc] initWithEvent:event time:time userInfo:userInfo]];
}

@end

#pragma mark - FWDebugTimeProfiler

@interface FWDebugTimeProfiler ()

@property (nonatomic, strong) NSArray<FWDebugTimeInfo *> *timeInfos;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, assign) NSUInteger selectedRow;
@property (nonatomic, copy) NSString *costTitle;
@property (nonatomic, copy) NSString *costText;

+ (FWDebugTimeRecord *)timeRecordForObject:(id)object;

@end

#pragma mark - NSObject+FWDebugTimeProfiler

@interface NSObject (FWDebugTimeProfiler)

@end

@implementation NSObject (FWDebugTimeProfiler)

- (BOOL)fwDebugApplication:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[FWDebugTimeRecord sharedInstance] recordEvent:@"↧ App.finishLaunch" userInfo:nil];
    BOOL result = [self fwDebugApplication:application didFinishLaunchingWithOptions:launchOptions];
    [[FWDebugTimeRecord sharedInstance] recordEvent:@"↥ App.finishLaunch" userInfo:nil];
    return result;
}

@end

#pragma mark - UIApplication+FWDebugTimeProfiler

@interface UIApplication (FWDebugTimeProfiler)

@end

@implementation UIApplication (FWDebugTimeProfiler)

- (id)fwDebugInit
{
    [[FWDebugTimeRecord sharedInstance] recordEvent:@"↧ App.initApplication" userInfo:nil];
    return [self fwDebugInit];
}

- (void)fwDebugSetDelegate:(id<UIApplicationDelegate>)delegate
{
    if ([delegate isKindOfClass:[NSObject class]]) {
        [FWDebugManager fwDebugSwizzleMethod:@selector(application:didFinishLaunchingWithOptions:) in:[delegate class] with:@selector(fwDebugApplication:didFinishLaunchingWithOptions:) in:[NSObject class]];
    }
    [self fwDebugSetDelegate:delegate];
}

@end

#pragma mark - UIViewController+FWDebugTimeProfiler

@interface UIViewController (FWDebugTimeProfiler)

@end

@implementation UIViewController (FWDebugTimeProfiler)

- (id)fwDebugInitWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    id object = [self fwDebugInitWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    [FWDebugTimeProfiler recordEvent:@"↥ VC.init" object:object userInfo:nil];
    return object;
}

- (id)fwDebugInitWithCoder:(NSCoder *)coder
{
    id object = [self fwDebugInitWithCoder:coder];
    [FWDebugTimeProfiler recordEvent:@"↥ VC.init" object:object userInfo:nil];
    return object;
}

- (void)fwDebugLoadView
{
    [FWDebugTimeProfiler recordEvent:@"↧ loadView" object:self userInfo:nil];
    [self fwDebugLoadView];
    [FWDebugTimeProfiler recordEvent:@"↥ loadView" object:self userInfo:nil];
}

- (void)fwDebugViewDidLoad
{
    [FWDebugTimeProfiler recordEvent:@"↧ viewDidLoad" object:self userInfo:nil];
    [self fwDebugViewDidLoad];
    [FWDebugTimeProfiler recordEvent:@"↥ viewDidLoad" object:self userInfo:nil];
}

- (void)fwDebugViewWillAppear:(BOOL)animated
{
    [FWDebugTimeProfiler recordEvent:@"↧ viewWillAppear:" object:self userInfo:nil];
    [self fwDebugViewWillAppear:animated];
    [FWDebugTimeProfiler recordEvent:@"↥ viewWillAppear:" object:self userInfo:nil];
}

- (void)fwDebugViewDidAppear:(BOOL)animated
{
    [FWDebugTimeProfiler recordEvent:@"↧ viewDidAppear:" object:self userInfo:nil];
    [self fwDebugViewDidAppear:animated];
    [FWDebugTimeProfiler recordEvent:@"↥ viewDidAppear:" object:self userInfo:nil];
    
    if (![self isKindOfClass:[UINavigationController class]] && ![self isKindOfClass:[UITabBarController class]]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            FWDebugTimeRecord *timeRecord = [FWDebugTimeProfiler timeRecordForObject:self];
            if (timeRecord) [FWDebugTimeRecord.sharedInstance.timeInfos addObjectsFromArray:[timeRecord.timeInfos copy]];
        });
    }
}

@end

#pragma mark - FLEXNetworkRecorder+FWDebugTimeProfiler

@interface FLEXNetworkRecorder (FWDebugTimeProfiler)

@end

@implementation FLEXNetworkRecorder (FWDebugTimeProfiler)

- (void)fwDebugRecordRequest:(NSString *)event requestID:(NSString *)requestID
{
    // TODO: 判断过滤URL
    NSTimeInterval time = [FWDebugTimeProfiler currentTime];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *viewController = [FWDebugManager fwDebugViewController];
        FWDebugTimeRecord *timeRecord = viewController ? [FWDebugTimeProfiler timeRecordForObject:viewController] : [FWDebugTimeRecord sharedInstance];
        [timeRecord recordEvent:event time:time userInfo:requestID];
    });
}

- (void)fwDebugRecordRequestWillBeSentWithRequestID:(NSString *)requestID request:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
    [self fwDebugRecordRequest:@"↧ startRequest" requestID:requestID];
    [self fwDebugRecordRequestWillBeSentWithRequestID:requestID request:request redirectResponse:redirectResponse];
}

- (void)fwDebugRecordLoadingFinishedWithRequestID:(NSString *)requestID responseBody:(NSData *)responseBody
{
    [self fwDebugRecordRequest:@"↥ finishRequest" requestID:requestID];
    [self fwDebugRecordLoadingFinishedWithRequestID:requestID responseBody:responseBody];
}

- (void)fwDebugRecordLoadingFailedWithRequestID:(NSString *)requestID error:(NSError *)error
{
    [self fwDebugRecordRequest:@"↥ failRequest" requestID:requestID];
    [self fwDebugRecordLoadingFailedWithRequestID:requestID error:error];
}

@end

#pragma mark - FWDebugTimeProfiler

@implementation FWDebugTimeProfiler

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[FWDebugTimeRecord sharedInstance] recordEvent:@"↧ App.objcLoad" userInfo:nil];
        
        [FWDebugManager fwDebugSwizzleMethod:@selector(init) in:[UIApplication class] with:@selector(fwDebugInit) in:[UIApplication class]];
        [FWDebugManager fwDebugSwizzleMethod:@selector(setDelegate:) in:[UIApplication class] with:@selector(fwDebugSetDelegate:) in:[UIApplication class]];
        
        if ([FWDebugAppConfig traceVCLife]) {
            [FWDebugManager fwDebugSwizzleMethod:@selector(initWithNibName:bundle:) in:[UIViewController class] with:@selector(fwDebugInitWithNibName:bundle:) in:[UIViewController class]];
            [FWDebugManager fwDebugSwizzleMethod:@selector(initWithCoder:) in:[UIViewController class] with:@selector(fwDebugInitWithCoder:) in:[UIViewController class]];
            [FWDebugManager fwDebugSwizzleMethod:@selector(loadView) in:[UIViewController class] with:@selector(fwDebugLoadView) in:[UIViewController class]];
            [FWDebugManager fwDebugSwizzleMethod:@selector(viewDidLoad) in:[UIViewController class] with:@selector(fwDebugViewDidLoad) in:[UIViewController class]];
            [FWDebugManager fwDebugSwizzleMethod:@selector(viewWillAppear:) in:[UIViewController class] with:@selector(fwDebugViewWillAppear:) in:[UIViewController class]];
            [FWDebugManager fwDebugSwizzleMethod:@selector(viewDidAppear:) in:[UIViewController class] with:@selector(fwDebugViewDidAppear:) in:[UIViewController class]];
        }
        
        if ([FWDebugAppConfig traceVCRequest]) {
            [FWDebugManager fwDebugSwizzleMethod:@selector(recordRequestWillBeSentWithRequestID:request:redirectResponse:) in:[FLEXNetworkRecorder class] with:@selector(fwDebugRecordRequestWillBeSentWithRequestID:request:redirectResponse:) in:[FLEXNetworkRecorder class]];
            [FWDebugManager fwDebugSwizzleMethod:@selector(recordLoadingFinishedWithRequestID:responseBody:) in:[FLEXNetworkRecorder class] with:@selector(fwDebugRecordLoadingFinishedWithRequestID:responseBody:) in:[FLEXNetworkRecorder class]];
            [FWDebugManager fwDebugSwizzleMethod:@selector(recordLoadingFailedWithRequestID:error:) in:[FLEXNetworkRecorder class] with:@selector(fwDebugRecordLoadingFailedWithRequestID:error:) in:[FLEXNetworkRecorder class]];
        }
    });
}

+ (double)currentTime
{
    struct timeval t0;
    gettimeofday(&t0, NULL);
    return t0.tv_sec + t0.tv_usec * 1e-6;
}

+ (NSTimeInterval)appLaunchedTime
{
    static NSTimeInterval appLaunchedTime;
    if (appLaunchedTime == 0.f) {
        struct kinfo_proc procInfo;
        size_t structSize = sizeof(procInfo);
        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};

        if (sysctl(mib, sizeof(mib) / sizeof(*mib), &procInfo, &structSize, NULL, 0) != 0) {
            NSLog(@"sysctrl failed");
            appLaunchedTime = [[NSDate date] timeIntervalSince1970];
        } else {
            struct timeval t = procInfo.kp_proc.p_un.__p_starttime;
            appLaunchedTime = t.tv_sec + t.tv_usec * 1e-6;
        }
    }
    return appLaunchedTime;
}

+ (void)recordEvent:(NSString *)event object:(id)object userInfo:(id)userInfo
{
    FWDebugTimeRecord *timeRecord = [self timeRecordForObject:object];
    if (timeRecord) [timeRecord recordEvent:event userInfo:userInfo];
}

+ (FWDebugTimeRecord *)timeRecordForObject:(id)object
{
    if (!object) return nil;
    FWDebugTimeRecord *record = objc_getAssociatedObject(object, _cmd);
    if (!record) {
        record = [[FWDebugTimeRecord alloc] init];
        objc_setAssociatedObject(object, _cmd, record, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return record;
}

- (instancetype)initWithObject:(id)object
{
    self = [super init];
    if (self) {
        _timeInfos = [[FWDebugTimeProfiler timeRecordForObject:object].timeInfos sortedArrayUsingComparator:^NSComparisonResult(FWDebugTimeInfo *obj1, FWDebugTimeInfo *obj2) {
            return obj1.time > obj2.time;
        }];
        self.title = NSStringFromClass([object class]);
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _timeInfos = [FWDebugTimeRecord.sharedInstance.timeInfos sortedArrayUsingComparator:^NSComparisonResult(FWDebugTimeInfo *obj1, FWDebugTimeInfo *obj2) {
            return obj1.time > obj2.time;
        }];
        self.title = @"Time Profiler";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateFormat = @"mm:ss.SSS";
    self.dateFormatter.timeZone = [NSTimeZone localTimeZone];
    
    self.tableView.allowsMultipleSelection = YES;
    self.selectedRow = NSNotFound;
    self.costTitle = @"Total";
    self.costText = @"";
}

#pragma mark - UITableView

- (BOOL)isLastIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.row == self.timeInfos.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.timeInfos.count > 0 ? self.timeInfos.count + 1 : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isLastIndexPath:indexPath]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell2"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell2"];
            cell.textLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.textLabel.text = self.costTitle;
        if (self.costText.length > 0) {
            cell.detailTextLabel.text = self.costText;
        } else {
            FWDebugTimeInfo *firstTime = self.timeInfos.firstObject;
            FWDebugTimeInfo *lastTime = self.timeInfos.lastObject;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.3lfms", (lastTime.time - firstTime.time) * 1000];
        }
        return cell;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
        cell.textLabel.font = [UIFont systemFontOfSize:12];
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.numberOfLines = 0;
    }
    FWDebugTimeInfo *prevTime = self.timeInfos[indexPath.row > 0 ? indexPath.row - 1 : 0];
    FWDebugTimeInfo *recordTime = self.timeInfos[indexPath.row];
    NSString *timeText = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:recordTime.time]];
    cell.accessoryType = recordTime.userInfo ? UITableViewCellAccessoryDetailButton : UITableViewCellAccessoryNone;
    cell.textLabel.text = recordTime.event;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n+%.3lfms", timeText, (recordTime.time - prevTime.time) * 1000];
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    id object = self.timeInfos[indexPath.row].userInfo;
    if (!object) return;
    
    // TODO: 跳转请求详情
    FLEXObjectExplorerViewController *viewController = [FLEXObjectExplorerFactory explorerViewControllerForObject:object];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isLastIndexPath:indexPath]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    NSUInteger selectedRow = indexPath.row;
    if (self.selectedRow == NSNotFound) {
        for (NSIndexPath *aIndexPath in [tableView indexPathsForSelectedRows]) {
            if ([aIndexPath compare:indexPath] == NSOrderedSame) {
                continue;
            }
            [tableView deselectRowAtIndexPath:aIndexPath animated:YES];
        }
        self.costTitle = @"Select another time";
        self.costText = @"-";
        self.selectedRow = selectedRow;
    } else {
        NSUInteger minRow = MIN(self.selectedRow, selectedRow);
        NSUInteger maxRow = MAX(self.selectedRow, selectedRow);
        for (NSUInteger aRow = minRow; aRow <= maxRow; aRow++) {
            NSIndexPath *indexPathToSelect = [NSIndexPath indexPathForRow:aRow inSection:0];
            [tableView selectRowAtIndexPath:indexPathToSelect animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
        FWDebugTimeInfo *startTime = self.timeInfos[minRow];
        FWDebugTimeInfo *endTime = self.timeInfos[maxRow];
        self.costTitle = @"Cost";
        self.costText = [NSString stringWithFormat:@"%.3lfms", (endTime.time - startTime.time) * 1000];
        self.selectedRow = NSNotFound;
    }
    [tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.timeInfos.count inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isLastIndexPath:indexPath]) return;
    
    NSUInteger selectedRow = indexPath.row;
    if (self.selectedRow == NSNotFound) {
        for (NSIndexPath *aIndexPath in [tableView indexPathsForSelectedRows]) {
            [tableView deselectRowAtIndexPath:aIndexPath animated:YES];
        }
        [tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        self.costTitle = @"Select another time";
        self.costText = @"-";
        self.selectedRow = selectedRow;
    } else {
        self.costTitle = @"Total";
        self.costText = @"";
        self.selectedRow = NSNotFound;
    }
    [tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.timeInfos.count inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

@end
