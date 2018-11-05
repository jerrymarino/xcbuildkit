//
//  BuildHelper.m
//  BuildHelper
//
//  Created by Jerry Marino on 11/4/18.
//  Copyright © 2018 Jerry Marino. All rights reserved.
//

#import "BuildHelper.h"

static BuildHelper *sharedPlugin;

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "JGMethodSwizzler.h"

@interface IDEXCBuildServiceBuildOperation : NSObject

- (void)buildOperation:a didUpdateProgressMessage:b forTargetName:c percentComplete:(double)d showInLog:(BOOL)e;
- (void)buildOperationDidStart:a;
- (BOOL)buildOperation:a taskWasUpToDate:b forTarget:c subtaskOf:d;
- (void)buildOperationDidEnd:a metricsData:b;

@end

@interface BuildHelper()

// FIXME: Move this to legit data structure.
@property (nonatomic) id currentOp;
@property (nonatomic) double systemProgress;

@end

@implementation BuildHelper

#pragma mark - Initialization

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    NSArray *allowedLoaders = [plugin objectForInfoDictionaryKey:@"me.delisa.XcodePluginBase.AllowedLoaders"];
    if ([allowedLoaders containsObject:[[NSBundle mainBundle] bundleIdentifier]]) {
        sharedPlugin = [[self alloc] initWithBundle:plugin];
    }
}

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)bundle
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        _bundle = bundle;
        // NSApp may be nil if the plugin is loaded from the xcodebuild command line tool
        if (NSApp && !NSApp.mainMenu) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(applicationDidFinishLaunching:)
                                                         name:NSApplicationDidFinishLaunchingNotification
                                                       object:nil];
        } else {
            [self initializeAndLog];
        }
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    [self initializeAndLog];
}

- (void)initializeAndLog
{
    NSString *name = [self.bundle objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *version = [self.bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *status = [self initialize] ? @"loaded successfully" : @"failed to load";
    NSLog(@"🔌 Plugin %@ %@ %@", name, version, status);
}

#pragma mark - Implementation

// Operation monitoring.
- (void)monitorOperation:(IDEXCBuildServiceBuildOperation *)operation buildOperation:(id /*XCBuild.XCBBuildOperation*/)bOperation
{
    self.currentOp = operation;
    self.systemProgress = 40;
    
    BuildHelper *helper = self;
    NSLog(@"MONITOR %@ %@", operation, [NSThread currentThread]);
    // Monitor the build operation async - or it will not work.
    // Overall, this works well because, the process does nothing interesting
    // as far as Xcode's progress UI is concerned.
    dispatch_async(dispatch_get_main_queue(), ^{
        // Emulate monitoring for progress.
        // In the actual implementation, this method will
        [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer * _Nonnull timer) {
            // Finally, invalidate the current op.
            // Sending updates after the task is don wil cause an issue.
            if (helper.currentOp == nil) {
                [timer invalidate];
                return;
            }

            // Hardcode some dummy progress
            // TBD - consider an API to integrate this into Bazel, Buck, Pants, Shell scripts.
            helper.systemProgress += 3;
            NSLog(@"Inject ad-hoc progress notifaction %@ %@", operation, bOperation);
            NSString *msg = [NSString stringWithFormat:@"Ran ad-hoc progress aware task %d.. ", (int)helper.systemProgress];
            [operation buildOperation:bOperation
                didUpdateProgressMessage:msg
                forTargetName:@"🔥 - Run script"
                percentComplete:helper.systemProgress
                showInLog:NO];
        }];
    });
}

// Schedule a replacement which happens when the framework loads
// Xcode loads this framework async, and generally after the project opens.
- (void)swizzleOnLoad {
    BuildHelper *helper = self;
    [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer * _Nonnull timer) {
        Class c = NSClassFromString(@"IDEXCBuildServiceBuildOperation");
        if (c) {
            NSLog(@"Attempt swizzle on lazy loaded build system classes");
            [timer invalidate];
        } else {
            return;
        }

        [c swizzleInstanceMethod:@selector(buildOperationDidStart:) withReplacement:JGMethodReplacementProviderBlock {
            return JGMethodReplacement(void, id, id operation) {
                NSLog(@"buildOperationDidStart:.. %@", self);
                [helper monitorOperation:self buildOperation:operation];
                JGOriginalImplementation(void, operation);
            };
        }];
        
        [c swizzleInstanceMethod:@selector(buildOperation:didUpdateProgressMessage:forTargetName:percentComplete:showInLog:) withReplacement:JGMethodReplacementProviderBlock {
            return JGMethodReplacement(void, id, id operation, id msg, id tname, double pc, BOOL show) {
                // FIXME: this is blowing up when indexing happens and a build starts
                // Details:  Assertion failed: buildOperation == _buildOp
                NSLog(@"buildOperation:didUpdateProgressMessage:forTargetName:percentComplete:showInLog:.. %@ %@ %@ %@ %@", operation, [msg class], tname, @(pc), @(show));
                JGOriginalImplementation(void, operation, msg, tname, pc, show);
            };
        }];
        
        [c swizzleInstanceMethod:@selector(buildOperationDidEnd:metricsData:) withReplacement:JGMethodReplacementProviderBlock {
            return JGMethodReplacement(void, id, id operation, id mData) {
                NSLog(@"buildOperationDidEnd:metricsData: %@ %@", operation, [mData class]);
                helper.currentOp = nil;
                JGOriginalImplementation(void, operation, mData);
            };
        }];
    }];
}

- (BOOL)initialize
{
    [self swizzleOnLoad];
    
    // Plugin boilerplate ( None of this will be needed for BuildHelper perhaps )
    // Create menu items, initialize UI, etc.
    // Sample Menu Item:
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"Do Action" action:@selector(doMenuAction) keyEquivalent:@""];
        [actionMenuItem setTarget:self];
        [[menuItem submenu] addItem:actionMenuItem];
        return YES;
    } else {
        return NO;
    }
}

// Sample Action, for menu item:
// FIXME: Remove
- (void)doMenuAction
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Hello, World"];
    [alert runModal];
}

void DumpObjcMethods(Class clz) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(clz, &methodCount);
    
    printf("Found %d methods on '%s'\n", methodCount, class_getName(clz));
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        printf("\t'%s' has method named '%s' of encoding '%s'\n",
               class_getName(clz),
               sel_getName(method_getName(method)),
               method_getTypeEncoding(method));
    }
    
    free(methods);
}

@end
