//
//  FW.m
//  FW1
//
//  Created by Thiago on 2023-01-11.
//  Copyright © 2023 jerry. All rights reserved.
//

#import <FW1/FW1.h>

@implementation FW1

- (void)foo {
    /* Used to test Fix-its
     Expected message:

     "Format specifies type 'char *' but the argument has type 'int'"

     with a diagnostic note saying:

     "Replace '%s' with '%d'"

     and a "Fix" action on the right side
    */
    NSLog(@"%s", 1);
}

@end
