// Exercises the vendored GeolocationHandler one-time request lifetime (#227):
// the manager is stopped on cancel, only the owning request can cancel, and
// late locations are ignored once cancelled.
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import "../include/geolocator_apple/Handlers/GeolocationHandler.h"
#import "../include/geolocator_apple/Handlers/GeolocationHandler_Test.h"

@interface FakeManager : CLLocationManager
@property(nonatomic) int starts;
@property(nonatomic) int stops;
@end

@implementation FakeManager
- (void)startUpdatingLocation { self.starts++; }
- (void)stopUpdatingLocation { self.stops++; }
@end

static int failures = 0;
#define CHECK(condition, message)                                   \
  do {                                                              \
    if (!(condition)) {                                             \
      fprintf(stderr, "FAILED: %s\n", message);                     \
      failures++;                                                   \
    }                                                               \
  } while (0)

static CLLocation *FreshLocation(void) {
  return [[CLLocation alloc] initWithLatitude:37.5 longitude:127.0];
}

int main(void) {
  @autoreleasepool {
    GeolocationHandler *handler = [[GeolocationHandler alloc] init];
    FakeManager *manager = [[FakeManager alloc] init];
    [handler setOneTimeLocationManagerOverride:manager];
    __block int a = 0, b = 0, c = 0, plain = 0;
    GeolocatorError noError = ^(NSString *code, NSString *description) {};

    // Request "1" is replaced by request "2" before it times out.
    [handler requestPositionWithDesiredAccuracy:kCLLocationAccuracyKilometer
                                      requestId:@"1"
                                  resultHandler:^(CLLocation *l) { a++; }
                                   errorHandler:noError];
    [handler requestPositionWithDesiredAccuracy:kCLLocationAccuracyKilometer
                                      requestId:@"2"
                                  resultHandler:^(CLLocation *l) { b++; }
                                   errorHandler:noError];
    CHECK(manager.starts == 2, "each request starts updates");

    CHECK(![handler cancelOneTimeRequestWithId:@"1"], "an older request cannot cancel");
    CHECK(manager.stops == 0, "the newer lookup keeps running");
    CHECK(![handler cancelOneTimeRequestWithId:nil], "no id cancels nothing");
    CHECK(![handler cancelOneTimeRequestWithId:@"unknown"], "an unknown id cancels nothing");

    [handler locationManager:manager didUpdateLocations:@[ FreshLocation() ]];
    CHECK(b == 1 && a == 0, "the newer request still gets its position");
    CHECK(manager.stops == 1, "the manager stops after a result");

    // Request "3" times out: its own cancel stops the manager and clears handlers.
    [handler requestPositionWithDesiredAccuracy:kCLLocationAccuracyKilometer
                                      requestId:@"3"
                                  resultHandler:^(CLLocation *l) { c++; }
                                   errorHandler:noError];
    CHECK([handler cancelOneTimeRequestWithId:@"3"], "the owner can cancel");
    CHECK(manager.stops == 2, "cancel stops updating location");
    [handler locationManager:manager didUpdateLocations:@[ FreshLocation() ]];
    CHECK(c == 0, "a late location after cancel is ignored");
    CHECK(![handler cancelOneTimeRequestWithId:@"3"], "cancelling twice does nothing");

    // A request without an id keeps working and cannot be cancelled by id.
    [handler requestPositionWithDesiredAccuracy:kCLLocationAccuracyKilometer
                                  resultHandler:^(CLLocation *l) { plain++; }
                                   errorHandler:noError];
    CHECK(![handler cancelOneTimeRequestWithId:@"3"], "a stale id leaves an id-less request");
    [handler locationManager:manager didUpdateLocations:@[ FreshLocation() ]];
    CHECK(plain == 1, "an id-less request still completes");
  }
  if (failures == 0) printf("geolocator_apple handler checks passed\n");
  return failures == 0 ? 0 : 1;
}
