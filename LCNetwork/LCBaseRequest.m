//
//  LCBaseRequest.m
//  LCNetwork
//
//  Created by bawn on 6/4/15.
//  Copyright (c) 2015 bawn. All rights reserved.
//

#import "LCBaseRequest.h"
#import "LCNetworkAgent.h"
#import "LCNetworkConfig.h"
#import "TMCache.h"
#import "AFNetworking.h"

@interface LCBaseRequest ()

@property (nonatomic, strong) id cacheJson;
@property (nonatomic, weak) id<LCAPIRequest> child;
@property (nonatomic, strong) NSMutableArray *requestAccessories;
@property (nonatomic, strong) LCNetworkConfig *config;

@end

@implementation LCBaseRequest

- (instancetype)init
{
    self = [super init];
    if (self) {
        if ([self conformsToProtocol:@protocol(LCAPIRequest)]) {
            _child = (id<LCAPIRequest>)self;
        }
        else {
            NSAssert(NO, @"子类必须要实现APIRequest这个protocol");
        }
        _config = [LCNetworkConfig sharedInstance];
      
    }
    return self;
}

- (void)start{
    [self toggleAccessoriesWillStartCallBack];
    [[LCNetworkAgent sharedInstance] addRequest:self];
}

- (void)startWithCompletionBlockWithSuccess:(void (^)(id request))success
                                    failure:(void (^)(id request))failure{
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
    [self start];
}

- (void)startWithBlockSuccess:(void (^)(id))success
                      failure:(void (^)(id))failure{
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
    [self start];
}

- (void)startWithBlockProgress:(void (^)(NSProgress *))progress
                  success:(void (^)(id))success
                  failure:(void (^)(id))failure{
    self.progressBlock = progress;
    self.successCompletionBlock = success;
    self.failureCompletionBlock = failure;
    [self start];
}


- (id)responseJSONObject{
    id responseJSONObject = nil;
    // 统一加工response
    if (self.config.processRule && [self.config.processRule respondsToSelector:@selector(processResponseWithRequest:)]) {
        if (([self.child respondsToSelector:@selector(ignoreUnifiedResponseProcess)] && ![self.child ignoreUnifiedResponseProcess]) ||
            ![self.child respondsToSelector:@selector(ignoreUnifiedResponseProcess)]) {
            responseJSONObject = [self.config.processRule processResponseWithRequest:_responseJSONObject];
            if ([self.child respondsToSelector:@selector(responseProcess:)]){
                responseJSONObject = [self.child responseProcess:responseJSONObject];
            }
            return responseJSONObject;
        }
    }
    
    if ([self.child respondsToSelector:@selector(responseProcess:)]){
        responseJSONObject = [self.child responseProcess:_responseJSONObject];
        return responseJSONObject;
    }
    return _responseJSONObject;
}

- (NSString *)urlString{
    if ([self.child respondsToSelector:@selector(customApiMethodName)]) {
        return [self.child customApiMethodName];
    }
    else{
        NSString *baseUrl = nil;
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ( [self.child respondsToSelector:@selector(isViceUrl)] && [self.child isViceUrl]) {
            baseUrl = self.config.viceBaseUrl;
        }
        #pragma clang diagnostic pop

        if ([self.child respondsToSelector:@selector(useViceUrl)] && [self.child useViceUrl]){
            baseUrl = self.config.viceBaseUrl;
        }
        else{
            baseUrl = self.config.mainBaseUrl;
        }
        if (baseUrl) {
            NSString *urlString = [baseUrl stringByAppendingString:[self.child apiMethodName]];
            if (self.queryArgument && [self.queryArgument isKindOfClass:[NSDictionary class]]) {
                return [urlString stringByAppendingString:[self urlStringForQuery]];
            }
            return urlString;
        }
        return [self.child apiMethodName];
    }
}
- (id)cacheJson{
    if (_cacheJson) {
        return _cacheJson;
    }
    else{
        return [[TMCache sharedCache].diskCache objectForKey:self.urlString];
    }
}


- (void)stop{
    [self toggleAccessoriesWillStopCallBack];
    self.delegate = nil;
    [[LCNetworkAgent sharedInstance] cancelRequest:self];
    [self toggleAccessoriesDidStopCallBack];
}


- (void)clearCompletionBlock {
    self.successCompletionBlock = nil;
    self.failureCompletionBlock = nil;
    self.progressBlock = nil;
}


- (NSString *)urlStringForQuery{
    NSMutableString *urlString = [[NSMutableString alloc] init];
    [urlString appendString:@"?"];
    [self.queryArgument enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [urlString appendFormat:@"%@=%@&", key, obj];
    }];
    [urlString deleteCharactersInRange:NSMakeRange(urlString.length - 1, 1)];
    return [urlString copy];
}


#pragma mark - Request Accessoies

- (void)addAccessory:(id<LCRequestAccessory>)accessory {
    if (!self.requestAccessories) {
        self.requestAccessories = [NSMutableArray array];
    }
    [self.requestAccessories addObject:accessory];
}
@end



@implementation LCBaseRequest (RequestAccessory)

- (void)toggleAccessoriesWillStartCallBack {
    for (id<LCRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStart:)]) {
            [accessory requestWillStart:self];
        }
    }
}

- (void)toggleAccessoriesWillStopCallBack {
    for (id<LCRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestWillStop:)]) {
            [accessory requestWillStop:self];
        }
    }
}

- (void)toggleAccessoriesDidStopCallBack {
    for (id<LCRequestAccessory> accessory in self.requestAccessories) {
        if ([accessory respondsToSelector:@selector(requestDidStop:)]) {
            [accessory requestDidStop:self];
        }
    }
}

@end

