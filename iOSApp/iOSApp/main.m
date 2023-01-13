#import <Foundation/Foundation.h>
#import <FW1/FW1.h>

int main(int argc, char * argv[]) {
    /* Used to test Fix-its
     Expected message:

     "Format specifies type 'char *' but the argument has type 'int'"

     with a diagnostic note saying:

     "Replace '%s' with '%d'"

     and a "Fix" action on the right side
    */
    NSLog(@"%s", 1);

    // Used to make sure FW1 type is available and imported correctly
    // Can also be used to test "jump to definition"
    [[[FW1 alloc] init] foo];

    exit(0);
}
