//
//  SBApplicationExtensions.h
//  OpenTerminal
//
//  Created by John Daniel on 3/23/09.
//  Copyright 2009 Etresoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ScriptingBridge/ScriptingBridge.h>

#import "SBApplicationExtensions.h"

@interface SBApplication (QuietExtensions)

+ (id) quietApplicationWithBundleIdentifier: (NSString *) ident;

@end
