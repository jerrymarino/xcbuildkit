//
//  BuildHelper.h
//  BuildHelper
//
//  Created by Jerry Marino on 11/4/18.
//Copyright © 2018 Jerry Marino. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface BuildHelper : NSObject

+ (instancetype)sharedPlugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;
@end