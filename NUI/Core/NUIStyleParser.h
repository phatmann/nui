//
//  NUIStyleParser.h
//  NUIDemo
//
//  Created by Tom Benner on 12/4/12.
//  Copyright (c) 2012 Tom Benner. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NUIStyleSheet;

@interface NUIStyleParser : NSObject

- (NSMutableDictionary*)getStylesFromString:(NSString *)content;
- (NSMutableDictionary*)getStylesFromBundle:(NSString*)name;
- (NSMutableDictionary*)getStylesFromPath:(NSString*)path;

@end
