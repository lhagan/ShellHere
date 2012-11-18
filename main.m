//
//  main.m
//  OpenTerminal
//
//  Created by John Daniel on 3/22/09.
//  Copyright Etresoft 2009. All rights reserved.
//
//  Modified 2009-09-08, 2012-11-17 by Luke Hagan <lukehagan.com>
//  to reuse existing Terminal window/tab and open a new tab in current window
//  if current tab is busy.
//

#import <Cocoa/Cocoa.h>
#import "Terminal.h"
#import "Finder.h"
#import "SystemEvents.h"
#import "SBApplicationExtensions.h"

// Calculate the quoted representation of a path.
NSString * quotePath(NSString * path);

// helper function to get terminal's current tab
TerminalTab * getCurrentTab(TerminalApplication * terminal);

int main(int argc, char *argv[])
  {
  if(NSApplicationLoad())
    {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    // Get a default path.
    NSString * path = nil;
    
    // Connect to the Finder.
    FinderApplication * finder = 
      [SBApplication 
        quietApplicationWithBundleIdentifier: @"com.apple.Finder"];
      
    // Get the current selection.
    SBObject * selection = finder.selection;
    
    NSArray * items = [selection get];
    
    // Ignore selection if there are multiple items selected.
    if([items count] == 1)
      {
      FinderItem * item = [items objectAtIndex: 0];
      
      NSString * itemPath = [[NSURL URLWithString: item.URL] path];
      
      NSString * type =
        [[[NSFileManager defaultManager]
          attributesOfItemAtPath: itemPath error: 0]
          fileType];
      
      // If the selected item is a folder, use it as the "here".
      if([type isEqualToString: NSFileTypeDirectory])
        path = itemPath;

      else
        path = [itemPath stringByDeletingLastPathComponent];
      }
    
    // If I don't have a path yet, look through the open Finder windows.
    if(!path)
      {
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
      }

    // Provide a fallback.
    if(!path)
      path = [@"~" stringByExpandingTildeInPath];

    // Connect to the Terminal. It is running now...maybe with a blank
    // terminal window.
    TerminalApplication * terminal = 
      [SBApplication 
        applicationWithBundleIdentifier: @"com.apple.Terminal"];
        
    // Find out if the Terminal is already running.
    //bool terminalWasRunning = [terminal isRunning];
    
    TerminalTab * currentTab = nil;
    
    // get the current tab
    currentTab = getCurrentTab(terminal);
      
    // create command to cd to selected folder and clear current Terminal contents
    NSString * command =
      [NSString
        stringWithFormat: @"cd %@; clear", quotePath(path)];
    
    // Activate the Terminal.
    [terminal activate];
    
    // if tab is busy, open a new tab
    if ([currentTab busy]) {
      
      // Get the System Events application.
      SystemEventsApplication * systemEvents =
        [SBApplication
          applicationWithBundleIdentifier: @"com.apple.SystemEvents"];
      
      // if System Events are enabled, send the Command T keystroke to open a new tab
      if(systemEvents.UIElementsEnabled) {
        [systemEvents keystroke: @"t" using: SystemEventsEMdsCommandDown];
      }
      
      // get the current tab
      currentTab = getCurrentTab(terminal);
    }

    // Run the script.
    [terminal doScript: command in: currentTab];
    
    [pool drain];
    }
    
  return 0;
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

//
// helper function to get terminal's current tab
//
TerminalTab * getCurrentTab(TerminalApplication * terminal) {
  TerminalTab * currentTab = nil;
  
  // Get the Terminal windows.
  SBElementArray * terminalWindows = [terminal windows];
  
  // find frontmost Terminal window
  TerminalWindow * frontmostWindow = nil;
  for(TerminalWindow * terminalWindow in terminalWindows) {
    if(!frontmostWindow || (terminalWindow.index < frontmostWindow.index))
        frontmostWindow = terminalWindow;
    }
      
  // find current tab
  SBElementArray * windowTabs = [frontmostWindow tabs];
  for(TerminalTab * tab in windowTabs) {
      if ([tab selected]) {
        currentTab = tab;
      }
  }
  return currentTab;
}
