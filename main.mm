//
//  main.m
//  OpenTerminal
//
//  Created by John Daniel on 3/22/09.
//  Copyright Etresoft 2009. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Terminal.h"
#import "Finder.h"
#import "SBApplicationExtensions.h"

// Find out if the terminal is running to close the blank window.
bool isTerminalRunning(void);

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
    FinderApplication * finder = 
      [SBApplication 
        quietApplicationWithBundleIdentifier: @"com.apple.Finder"];
      
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
     
    // Find out if the Terminal is already running.
    bool terminalRunning = isTerminalRunning();
    
    // Connect to the Terminal. It is running now...maybe with a blank
    // terminal window.
    TerminalApplication * terminal = 
      [SBApplication 
        applicationWithBundleIdentifier: @"com.apple.Terminal"];
        
    // Get the Terminal windows.
    SBElementArray * terminalWindows = [terminal windows];
    
    // If there is only a single window with a single tab, Terminal may 
    // have been just launched. If so, I want to close the window.
    if([terminalWindows count] == 1)
      for(TerminalWindow * terminalWindow in terminalWindows)
        {
        SBElementArray * windowTabs = [terminalWindow tabs];
      
        if([windowTabs count] == 1)
          for(TerminalTab * tab in windowTabs)
          
            // If I started the Terminal, close the open window.
            if(!terminalRunning)
              [terminalWindow 
                closeSaving: TerminalSaveOptionsNo savingIn: nil];
        }
        
    // Create a "cd" command.
    NSString * command = 
      [NSString stringWithFormat: @"cd %@; clear", quotePath(path)];
    
    // Run the script.
    [terminal doScript: command in: nil];
    
    // Wait for "a while" for the script to run and get a new window.
    // I wish there was a better way to do this.
    [NSThread sleepForTimeInterval: 0.1];
    
    // Activate the Terminal. Hopefully, the new window is already open and
    // is will be brought to the front.
    [terminal activate];
    
    [pool drain];
    }
  }

// Determine if the terminal was already running.
bool isTerminalRunning(void)
  {
  ProcessSerialNumber psn = { 0, kNoProcess };
  
  CFStringRef name;
  
  // Uhmmmm. Carbon...
  while(!GetNextProcess(& psn))
    {
    if(!CopyProcessName(& psn, & name))
      {
      bool isTerminal = !CFStringCompare(CFSTR("Terminal"), name, 0);
      
      NSLog((NSString *) name);
      
      CFRelease(name);
      
      if(isTerminal)
        return true;
      }
    }
    
  return false;
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