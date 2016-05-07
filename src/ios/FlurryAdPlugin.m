//
//  FlurryAdPlugin.m
//  TestAdMobCombo
//
//  Created by Xie Liming on 14-10-31.
//
//

#import "FlurryAdPlugin.h"

#import "Flurry.h"
#import "FlurryAds.h"
#import "FlurryAdDelegate.h"

#define TEST_APIKEY  @"2DYY249X5G798HMF3MTH"

#define AD_INTERSTITIAL     @"INTERSTITIAL_MAIN_VIEW"
#define AD_BANNER_TOP       @"TOP_BANNER"
#define AD_BANNER_BOTTOM    @"BOTTOM_BANNER"


@interface FlurryAdPlugin()<FlurryAdDelegate>

@property (assign) FlurryAdSize adSize;
@property (nonatomic, retain) NSString* adSpace;
@property (nonatomic, retain) NSString* adSpaceInterstitial;
@property (assign) BOOL inited;

- (void) validateSession:(NSString*)adId;

@end


@implementation FlurryAdPlugin

- (void)pluginInitialize
{
    [super pluginInitialize];
    
    self.inited = NO;
    self.adSize = BANNER_BOTTOM;
    self.adSpace = AD_BANNER_BOTTOM;
    self.adSpaceInterstitial = AD_INTERSTITIAL;
}

- (void) validateSession:(NSString *)adId
{
    if(! self.inited) {
        [Flurry startSession:adId];
        
        [FlurryAds setAdDelegate:self];
        [FlurryAds initialize:[self getViewController]];

        self.inited = YES;
    }
}

- (NSString*) __getProductShortName { return @"FlurryAds"; }
- (NSString*) __getTestBannerId { return TEST_APIKEY; }
- (NSString*) __getTestInterstitialId { return TEST_APIKEY; }

- (void) parseOptions:(NSDictionary *)options
{
    [super parseOptions:options];

    [FlurryAds enableTestAds:self.isTesting];
    
    if(self.isTesting) {
        self.testTraffic = true;
        
        if(self.logVerbose) {
            [Flurry setDebugLogEnabled:YES];
            [Flurry setEventLoggingEnabled:YES];
            [Flurry setBackgroundSessionEnabled:YES];
        }
        self.adSpaceInterstitial = AD_INTERSTITIAL;
    }
    
    if(self.adPosition <= POS_TOP_RIGHT) {
        self.adSize = BANNER_TOP;
        if(self.isTesting) {
            self.adSpace = AD_BANNER_TOP;
        }
    } else {
        self.adSize = BANNER_BOTTOM;
        if(self.isTesting) {
            self.adSpace = AD_BANNER_BOTTOM;
        }
    }
    
    // get ad space for banner
    if (!self.isTesting) {
        if (options[@"bannerName"]) {
            self.adSpace = options[@"bannerName"];
        }
        if (options[@"interstitialName"]) {
            self.adSpaceInterstitial = options[@"interstitialName"];
        }
    }
}

- (UIView*) __createAdView:(NSString*)adId {
    [self validateSession:adId];
    
    CGRect rect = [[self getView] bounds];
    rect.size.height = 50;
    UIView* v = [[UIView alloc] initWithFrame:rect];
    return v;
}

- (int) __getAdViewWidth:(UIView*)view {
    return view.frame.size.width;
}

- (int) __getAdViewHeight:(UIView*)view {
    return view.frame.size.height;
}

- (void) __loadAdView:(UIView*)view {
    if(! view) return;
    
    [FlurryAds fetchAndDisplayAdForSpace:self.adSpace view:view viewController:[self getViewController] size:self.adSize];
}

- (void) __pauseAdView:(UIView*)view {
}

- (void) __resumeAdView:(UIView*)view {
}

- (void) __destroyAdView:(UIView*)view {
    if(! view) return;
    
    [FlurryAds removeAdFromSpace:self.adSpace];
    [view removeFromSuperview];
}

- (NSObject*) __createInterstitial:(NSString*)adId {
    [self validateSession:adId];
    
    UIView* v = [self getView];
    return v;
}

- (void) __loadInterstitial:(NSObject*)interstitial {
    UIView* view = (UIView*) interstitial;
    [FlurryAds fetchAdForSpace:self.adSpaceInterstitial frame:view.bounds size:FULLSCREEN];
}

- (void) __showInterstitial:(NSObject*)interstitial {
    UIView* view = (UIView*) interstitial;
    [FlurryAds displayAdForSpace:self.adSpaceInterstitial onView:view viewControllerForPresentation:[self getViewController]];
}

- (void) __destroyInterstitial:(NSObject*)interstitial {
    [FlurryAds removeAdFromSpace:self.adSpaceInterstitial];
}

#pragma mark FlurryAdDelegate implementation

- (void) spaceDidReceiveAd:(NSString*)adSpace {
    BOOL isInterstitial = [adSpace isEqualToString:self.adSpaceInterstitial];
    NSString* adType = isInterstitial ? ADTYPE_INTERSTITIAL : ADTYPE_BANNER;
    [self fireAdEvent:EVENT_AD_LOADED withType:adType];
    
    if(isInterstitial) {
        if (self.interstitial && self.autoShowInterstitial) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self __showInterstitial:self.interstitial];
            });
        }
    } else {
        if((! self.bannerVisible) && self.autoShowBanner) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self __showBanner:self.adPosition atX:self.posX atY:self.posY];
            });
        }
    }
}

- (void) spaceDidFailToReceiveAd:(NSString*) adSpace error:(NSError *)error {
    NSString* adType = [adSpace isEqualToString:self.adSpaceInterstitial] ? ADTYPE_INTERSTITIAL : ADTYPE_BANNER;
    [self fireAdErrorEvent:EVENT_AD_FAILLOAD withCode:(int)error.code withMsg:[error localizedDescription] withType:adType];
}

- (void) spaceDidFailToRender:(NSString *)adSpace error:(NSError *)error {
    NSString* adType = [adSpace isEqualToString:self.adSpaceInterstitial] ? ADTYPE_INTERSTITIAL : ADTYPE_BANNER;
    [self fireAdErrorEvent:EVENT_AD_FAILLOAD withCode:(int)error.code withMsg:[error localizedDescription] withType:adType];
}

- (void) spaceWillLeaveApplication:(NSString *)adSpace {
    NSString* adType = [adSpace isEqualToString:self.adSpaceInterstitial] ? ADTYPE_INTERSTITIAL : ADTYPE_BANNER;
    [self fireAdEvent:EVENT_AD_LEAVEAPP withType:adType];
}

- (BOOL) spaceShouldDisplay:(NSString*)adSpace interstitial:(BOOL)interstitial {
    return TRUE;
}

- (void) spaceDidRender:(NSString *)adSpace interstitial:(BOOL)interstitial {
    NSString* adType = interstitial ? ADTYPE_INTERSTITIAL : ADTYPE_BANNER;
    [self fireAdEvent:EVENT_AD_PRESENT withType:adType];
}

- (void) spaceWillDismiss:(NSString *)adSpace {
    NSString* adType = [adSpace isEqualToString:self.adSpaceInterstitial] ? ADTYPE_INTERSTITIAL : ADTYPE_BANNER;
    [self fireAdEvent:EVENT_AD_WILLDISMISS withType:adType];
}

- (void)spaceDidDismiss:(NSString *)adSpace interstitial:(BOOL)interstitial {
    NSString* adType = interstitial ? ADTYPE_INTERSTITIAL : ADTYPE_BANNER;
    [self fireAdEvent:EVENT_AD_DISMISS withType:adType];
}

#pragma mark Cleanup

- (void)dealloc {
    [FlurryAds setAdDelegate:nil];
}


@end
