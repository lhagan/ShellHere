//
//  SBApplicationExtensions.mm
//  OpenTerminal
//
//  Created by John Daniel on 3/23/09.
//  Copyright 2009 Etresoft. All rights reserved.
//

#import "SBApplicationExtensions.h"

@implementation SBApplication (QuietExtensions)

+ (id) quietApplicationWithBundleIdentifier: (NSString *) ident
{
    int old_stderr = dup(STDERR_FILENO);
    
    close(STDERR_FILENO);
    
    int fd = open("/dev/null", O_WRONLY);
    
    dup2(fd, STDERR_FILENO);
    
    close(fd);
    
    id application = [SBApplication applicationWithBundleIdentifier: ident];
    
    close(STDERR_FILENO);
    
    dup2(old_stderr, STDERR_FILENO);
    
    close(old_stderr);
    
    return application;
}

@end
