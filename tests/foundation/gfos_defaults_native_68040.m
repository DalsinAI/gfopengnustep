#include <stdio.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>
static void checkpoint(const char *s) {printf("GFOS_DEFAULTS_RW %s\n",s);fflush(stdout);}
int main(int argc,char **argv){
 char *env[]={NULL};GSInitializeProcess(argc,argv,env);
 NSAutoreleasePool *pool=[[NSAutoreleasePool alloc]init];
 checkpoint("before-open"); NSUserDefaults *d=[NSUserDefaults standardUserDefaults]; checkpoint("after-open");
 if (!d) return 2;
 NSString *v=[d stringForKey:@"GFOSProbeRoundTrip"];
 printf("GFOS_DEFAULTS_RW before=%s\n",v?[v UTF8String]:"nil");fflush(stdout);
 checkpoint("before-write");[d setObject:@"roundtrip-68040" forKey:@"GFOSProbeRoundTrip"]; checkpoint("after-write");
 v=[d stringForKey:@"GFOSProbeRoundTrip"];
 printf("GFOS_DEFAULTS_RW after=%s\n",v?[v UTF8String]:"nil");fflush(stdout);
 if (![v isEqualToString:@"roundtrip-68040"]) return 3;
 checkpoint("before-sync"); BOOL saved=[d synchronize];checkpoint("after-sync");
 printf("GFOS_DEFAULTS_RW synchronize=%d\n",saved);fflush(stdout);
 [pool drain];checkpoint("end");return 0;
}
