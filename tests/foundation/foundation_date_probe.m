#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#include <stdio.h>
#include <stddef.h>
int main(int argc, char **argv)
{
    char *env[] = { NULL };
    GSInitializeProcess(argc, argv, env);
    printf("DATE_PROBE_00_START\n"); fflush(stdout);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    printf("DATE_PROBE_01_POOL\n"); fflush(stdout);
    NSDate *when = [NSDate dateWithTimeIntervalSinceNow:5.0];
    printf("DATE_PROBE_02_CREATED %d\n",when != nil); fflush(stdout);
    double dt = [when timeIntervalSinceNow];
    printf("DATE_PROBE_03_INTERVAL %d\n",dt > 0.0); fflush(stdout);
    NSData *data = [NSData dataWithBytes:"ping" length:4];
    printf("DATE_PROBE_04_DATA %d\n",data != nil); fflush(stdout);
    NSMutableArray *arr = [NSMutableArray arrayWithObject:data];
    printf("DATE_PROBE_05_ARRAY %lu\n", (unsigned long)[arr count]); fflush(stdout);
    [pool drain];
    printf("DATE_PROBE_PASS\n"); fflush(stdout);
    return 0;
}
