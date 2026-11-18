#import <Foundation/NSObject.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <stdio.h>
int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *name = [NSString stringWithUTF8String:"GFOS"];
    NSArray *items = [NSArray arrayWithObject:name];
    NSDictionary *dict = [NSDictionary dictionaryWithObject:name forKey:name];
    int ok = [name length] == 4 && [items count] == 1 && [dict count] == 1;
    printf("FOUNDATION_CORE_%s len=%lu items=%lu dict=%lu\n",ok?"PASS":"FAIL", (unsigned long)[name length], (unsigned long)[items count], (unsigned long)[dict count]);
    [pool drain];
    return ok ? 0 : 2;
}
