//
//  main.m
//  OpenTerminal
//
//  Created by John Daniel on 3/22/09.
//  Copyright Etresoft 2009. All rights reserved.
//  modifications by lhagan 2009-09-08 to open in same window
//

#import <Cocoa/Cocoa.h>
#import "Terminal.h"
#import "Finder.h"
#import "SBApplicationExtensions.h"

// Find out if the terminal is running to close the blank window.
//bool isTerminalRunning(void);

// Calculate the quoted representation of a path.
NSString * quotePath(NSString * path);

int main(int argc, char *argv[])
  {
  if(NSApplicationLoad())
    {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // Get a default path.
    NSString * path = [@"~" stringByExpandingTildeInPath];
    
    // Connect to the Finder.
    FinderApplication * finder = [SBApplication quietApplicationWithBundleIdentifier: @"com.apple.Finder"];
      
    // Get the open Finder windows.
    SBElementArray * finderWindows = [finder FinderWindows];
    
    // Try to find the frontmost Finder window and the path to its 
    // location.
    if([finderWindows count] > 0)
      {
      // Find the frontmost Finder window.
      FinderFinderWindow * frontmostWindow = nil;
      
      for (FinderFinderWindow * finderWindow in finderWindows)
        {
        if(!frontmostWindow || (finderWindow.index < frontmostWindow.index))
          frontmostWindow = finderWindow;
        }
        
      // Get the path for the frontmost window.
      if(frontmostWindow)
        {
        SBObject * target = frontmostWindow.target;
        FinderItem * item = [target get];
        NSURL * URL = [NSURL URLWithString: item.URL];
        
        path = [URL path];
        }
      }
    
    // Connect to the Terminal. It is running now...maybe with a blank terminal window.
    TerminalApplication * terminal = [SBApplication applicationWithBundleIdentifier: @"com.apple.Terminal"];
    
	// create command to cd to selected folder and clear current Terminal contents
	NSString * command = [NSString stringWithFormat: @"cd %@; clear", quotePath(path)];
		
    // Get the Terminal windows.
    SBElementArray * terminalWindows = [terminal windows];
		
	if ([terminalWindows count] != 0) {
		// FIX ME: needs to find selected window, or choose one, not run on all windows
		for(TerminalWindow * terminalWindow in terminalWindows)
		{
			// activate terminal before it can accept cmd-t (if needed)
			[terminal activate];
			
			// get Terminal tabs
			SBElementArray * windowTabs = [terminalWindow tabs];
			
			// go through tabs until we find the one that's selected
			// if it's busy, open a new tab
			for(TerminalTab * windowTab in windowTabs) {
				
				if ([windowTab selected]) {
					if ([windowTab busy] == FALSE) {
						
						// run the command
						[terminal doScript: command in: windowTab];
					} else {
						
						NSDictionary* errorDict;
						NSAppleEventDescriptor* returnDescriptor = NULL;
						
						// open a new tab
						// there has to be a better way to do this
						NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:
													   @"\
													   tell application \"System Events\"\n\
													   tell process \"Terminal\" to keystroke \"t\" using command down\n\
													   end\n\
													   tell application \"Terminal\"\n\
													   activate\n\
													   end tell"];
						
						returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
						[scriptObject release];
						
						// run the command
						[terminal doScript: command in: terminalWindow];
					}
				}
			}
		}
	} else {
		// run command in new window if none existed
		[terminal doScript: command in: nil];
		[terminal activate];
	}
    
    [pool drain];
    }
  }
  
// Calculate the quoted representation of a path.
// AppleScript has a "quoted form of POSIX path" which isn't quite as
// good as the Finder's drag-n-drop conversion. Here, I will try to
// replicate what the Finder does to convert a Unicode path to something
// the Terminal can understand.
NSString * quotePath(NSString * path)
  {
  // Oh god, not a scanner.
  NSScanner * scanner = [NSScanner scannerWithString: path];
  
  // I don't want to skip the default whitespace.
  [scanner setCharactersToBeSkipped: [NSCharacterSet illegalCharacterSet]];
  
  // Create a character set that will replace any unicode characters that
  // aren't path-friendly.
  NSMutableCharacterSet * punctuation = 
    [NSMutableCharacterSet punctuationCharacterSet];
  
  // Add symbols and whitespace to the list to be replaced.
  [punctuation
    formUnionWithCharacterSet: [NSCharacterSet symbolCharacterSet]];
  [punctuation
    formUnionWithCharacterSet: [NSCharacterSet whitespaceCharacterSet]];
    
  // Important - remove the path delimiter. I don't want this replaced.
  [punctuation removeCharactersInString: @"/"];
  
  // Since I'm doing all the dirty work, I don't need double quotes around
  // the resulting string.
  NSMutableString * quotedPath = [NSMutableString new];
  
  // Create some strings for good and bad sets.
  NSString * good;
  NSString * bad;
  
  while(![scanner isAtEnd])
    {
    // Scan all the good characters I can find.
    if([scanner scanUpToCharactersFromSet: punctuation intoString: & good])
      [quotedPath appendString: good];
      
    // Scan all the bad characters that come next.
    if([scanner scanCharactersFromSet: punctuation intoString: & bad])
    
      // Now escape each bad character.
      for(NSInteger i = 0; i < [bad length]; ++i)
        [quotedPath appendFormat: @"\\%C", [bad characterAtIndex: i]];
    }
    
  return [quotedPath autorelease];
  }