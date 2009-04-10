//
//  SPPreferenceController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Dec 10, 2008
//  Modified by Ben Perry (benperry.com.au) on Mar 28, 2009
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPPreferenceController.h"
#import "SPWindowAdditions.h"
#import "SPFavoriteTextFieldCell.h"
#import "KeyChain.h"

#define FAVORITES_PB_DRAG_TYPE @"SequelProPreferencesPasteboard"

#define PREFERENCE_TOOLBAR_GENERAL			@"Preference Toolbar General"
#define PREFERENCE_TOOLBAR_TABLES			@"Preference Toolbar Tables"
#define PREFERENCE_TOOLBAR_FAVORITES		@"Preference Toolbar Favorites"
#define PREFERENCE_TOOLBAR_NOTIFICATIONS	@"Preference Toolbar Notifications"
#define PREFERENCE_TOOLBAR_AUTOUPDATE		@"Preference Toolbar Auto Update"
#define PREFERENCE_TOOLBAR_NETWORK			@"Preference Toolbar Network"

#pragma mark -

@interface SPPreferenceController (PrivateAPI)

- (void)_setupToolbar;
- (void)_resizeWindowForContentView:(NSView *)view;
- (void)_updateDefaultFavoritePopup;

@end

#pragma mark -

@implementation SPPreferenceController

// -------------------------------------------------------------------------------
// init
// -------------------------------------------------------------------------------
- (id)init
{
	return [super initWithWindowNibName:@"Preferences"];
}

// -------------------------------------------------------------------------------
// windowDidLoad
// -------------------------------------------------------------------------------
- (void)windowDidLoad
{	
	[self _setupToolbar];
	
	prefs    = [NSUserDefaults standardUserDefaults];
	keychain = [[KeyChain alloc] init];

	SPFavoriteTextFieldCell *tableCell = [[[SPFavoriteTextFieldCell alloc] init] autorelease];
	
	[tableCell setImage:[NSImage imageNamed:@"database"]];
	
	// Replace column's NSTextFieldCell with custom SWProfileTextFieldCell
	[[[favoritesTableView tableColumns] objectAtIndex:0] setDataCell:tableCell];
	
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:FAVORITES_PB_DRAG_TYPE]];
	
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[favoritesTableView reloadData];
	
	[self _updateDefaultFavoritePopup];
}

#pragma mark -
#pragma mark IBAction methods

// -------------------------------------------------------------------------------
// addFavorite:
// -------------------------------------------------------------------------------
- (IBAction)addFavorite:(id)sender
{
	// Create default favorite
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Favorite", @"", @"", @"", @"", @"", nil] 
																	   forKeys:[NSArray arrayWithObjects:@"name", @"host", @"socket", @"user", @"port", @"database", nil]];
	
	[favoritesController addObject:favorite];
	
	[favoritesTableView reloadData];
	[self _updateDefaultFavoritePopup];
}

// -------------------------------------------------------------------------------
// removeFavorite:
// -------------------------------------------------------------------------------
- (IBAction)removeFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		
		// Get selected favorite's details
		NSString *name     = [favoritesController valueForKeyPath:@"selection.name"];
		NSString *user     = [favoritesController valueForKeyPath:@"selection.user"];
		NSString *host     = [favoritesController valueForKeyPath:@"selection.host"];
		NSString *database = [favoritesController valueForKeyPath:@"selection.database"];
		
		// Remove passwords from the Keychain
		[keychain deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro : %@", name]
								account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
		[keychain deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@", name]
								account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
		
		// Reset last used favorite
		if ([favoritesTableView selectedRow] == [prefs integerForKey:@"LastFavoriteIndex"]) {
			[prefs setInteger:0	forKey:@"LastFavoriteIndex"];
		}
		
		// Reset default favorite
		if ([favoritesTableView selectedRow] == [prefs integerForKey:@"DefaultFavorite"]) {
			[prefs setInteger:[prefs integerForKey:@"LastFavoriteIndex"] forKey:@"DefaultFavorite"];
		}

		[favoritesController removeObjectAtArrangedObjectIndex:[favoritesTableView selectedRow]];
		
		[favoritesTableView reloadData];
		[self _updateDefaultFavoritePopup];
	}
}

// -------------------------------------------------------------------------------
// duplicateFavorite:
// -------------------------------------------------------------------------------
- (IBAction)duplicateFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:[favoritesTableView selectedRow]]];
		
		[favoritesController addObject:favorite];
		
		[favoritesTableView reloadData];
		[self _updateDefaultFavoritePopup];
	}
}

// -------------------------------------------------------------------------------
// saveFavorite:
// -------------------------------------------------------------------------------
- (IBAction)saveFavorite:(id)sender
{
	
}


// -------------------------------------------------------------------------------
// updateDefaultFavorite:
// -------------------------------------------------------------------------------
- (IBAction)updateDefaultFavorite:(id)sender
{
	if ([defaultFavoritePopup indexOfSelectedItem] == 0) {
		[prefs setBool:YES forKey:@"SelectLastFavoriteUsed"];
	} else {
		[prefs setBool:NO forKey:@"SelectLastFavoriteUsed"];

		// Minus 2 from index to account for the "Last Used" and separator items
		[prefs setInteger:[defaultFavoritePopup indexOfSelectedItem]-2 forKey:@"DefaultFavorite"];
	}
}


#pragma mark -
#pragma mark Toolbar item IBAction methods

// -------------------------------------------------------------------------------
// displayGeneralPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayGeneralPreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
	[self _resizeWindowForContentView:generalView];
}

// -------------------------------------------------------------------------------
// displayTablePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayTablePreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_TABLES];
	[self _resizeWindowForContentView:tablesView];
}

// -------------------------------------------------------------------------------
// displayFavoritePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayFavoritePreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_FAVORITES];
	[self _resizeWindowForContentView:favoritesView];
	
	// Set the default favorite popup back to preference
	if (sender == [defaultFavoritePopup lastItem]) {
		if (![prefs boolForKey:@"SelectLastFavoriteUsed"]) {
			[defaultFavoritePopup selectItemAtIndex:[prefs integerForKey:@"DefaultFavorite"]+2];
		} else {
			[defaultFavoritePopup selectItemAtIndex:0];
		}
	}
}

// -------------------------------------------------------------------------------
// displayNotificationPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNotificationPreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_NOTIFICATIONS];
	[self _resizeWindowForContentView:notificationsView];
}

// -------------------------------------------------------------------------------
// displayAutoUpdatePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayAutoUpdatePreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_AUTOUPDATE];
	[self _resizeWindowForContentView:autoUpdateView];
}

// -------------------------------------------------------------------------------
// displayNetworkPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNetworkPreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_NETWORK];
	[self _resizeWindowForContentView:networkView];
}

#pragma mark -
#pragma mark TableView datasource methods

// -------------------------------------------------------------------------------
// numberOfRowsInTableView:
// -------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[favoritesController arrangedObjects] count];
}

// -------------------------------------------------------------------------------
// tableView:objectValueForTableColumn:row:
// -------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return [[[favoritesController arrangedObjects] objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

#pragma mark -
#pragma mark TableView drag & drop datasource methods

// -------------------------------------------------------------------------------
// tableView:writeRows:toPasteboard:
// -------------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	int originalRow;
	NSArray *pboardTypes;
	
	if ([rows count] == 1) {
		pboardTypes = [NSArray arrayWithObject:FAVORITES_PB_DRAG_TYPE];
		originalRow = [[rows objectAtIndex:0] intValue];
		
		[pboard declareTypes:pboardTypes owner:nil];
		[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:FAVORITES_PB_DRAG_TYPE];
		
		return YES;
	} 
	else {		
		return NO;
	}
}

// -------------------------------------------------------------------------------
// tableView:validateDrop:proposedRow:proposedDropOperation:
// -------------------------------------------------------------------------------
- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{	
	int originalRow;
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	
	if (([pboardTypes count] > 1) && (row != -1)) {
		if (([pboardTypes containsObject:FAVORITES_PB_DRAG_TYPE]) && (operation == NSTableViewDropAbove)) {
			originalRow = [[[info draggingPasteboard] stringForType:FAVORITES_PB_DRAG_TYPE] intValue];
						
			if ((row != originalRow) && (row != (originalRow + 1))) {
				return NSDragOperationMove;
			}
		}
	}
	
	return NSDragOperationNone;
}

// -------------------------------------------------------------------------------
// tableView:acceptDrop:row:dropOperation:
// -------------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{	
	int originalRow;
	int destinationRow;
	NSMutableDictionary *draggedRow;
	
	originalRow = [[[info draggingPasteboard] stringForType:FAVORITES_PB_DRAG_TYPE] intValue];
	destinationRow = row;
	
	if (destinationRow > originalRow) {
		destinationRow--;
	}
	
	draggedRow = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:originalRow]];
	
	[favoritesController removeObjectAtArrangedObjectIndex:originalRow];
	[favoritesController insertObject:draggedRow atArrangedObjectIndex:destinationRow];
	
	[favoritesTableView reloadData];
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRow] byExtendingSelection:NO];
	
	// Update default favorite to take on new value
	if ([prefs integerForKey:@"LastFavoriteIndex"] == originalRow) {
		[prefs setInteger:destinationRow forKey:@"LastFavoriteIndex"];
	}
	
	// Update default favorite to take on new value
	if ([prefs integerForKey:@"DefaultFavorite"] == originalRow) {
		[prefs setInteger:destinationRow forKey:@"DefaultFavorite"];
	}
	[self _updateDefaultFavoritePopup];
	
	return YES;
}


#pragma mark -
#pragma mark TableView delegate methods
	
// -------------------------------------------------------------------------------
// tableView:willDisplayCell:forTableColumn:row:
// -------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)index
{
	if ([cell isKindOfClass:[SPFavoriteTextFieldCell class]]) {
		[cell setFavoriteName:[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"name"]];
		[cell setFavoriteHost:[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"host"]];
	}
}

// -------------------------------------------------------------------------------
// tableViewSelectionDidChange:
// -------------------------------------------------------------------------------
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{	
	if ([[favoritesTableView selectedRowIndexes] count] > 0) {
		[favoritesController setSelectionIndexes:[favoritesTableView selectedRowIndexes]];		
	}

	NSString *keychainName = [NSString stringWithFormat:@"Sequel Pro : %@", [favoritesController valueForKeyPath:@"selection.name"]];
	NSString *keychainAccount = [NSString stringWithFormat:@"%@@%@/%@",
								 [favoritesController valueForKeyPath:@"selection.user"],
								 [favoritesController valueForKeyPath:@"selection.host"],
								 [favoritesController valueForKeyPath:@"selection.database"]];

	[passwordField setStringValue:[keychain getPasswordForName:keychainName account:keychainAccount]];
}

#pragma mark -
#pragma mark Toolbar delegate methods

// -------------------------------------------------------------------------------
// toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
// -------------------------------------------------------------------------------
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{		
    if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_GENERAL]) {
        return generalItem;
    }
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_TABLES]) {
		return tablesItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_FAVORITES]) {
		return favoritesItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_NOTIFICATIONS]) {
		return notificationsItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_AUTOUPDATE]) {
		return autoUpdateItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_NETWORK]) {
		return networkItem;
	}
	
    return [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
}

// -------------------------------------------------------------------------------
// toolbarAllowedItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_AUTOUPDATE, PREFERENCE_TOOLBAR_NETWORK, nil];
}

// -------------------------------------------------------------------------------
// toolbarDefaultItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_AUTOUPDATE, PREFERENCE_TOOLBAR_NETWORK, nil];
}

// -------------------------------------------------------------------------------
// toolbarSelectableItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_AUTOUPDATE, PREFERENCE_TOOLBAR_NETWORK, nil];
}

// -------------------------------------------------------------------------------
// dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
	[keychain release], keychain = nil;
	
	[super dealloc];
}

@end

#pragma mark -

@implementation SPPreferenceController (PrivateAPI)

// -------------------------------------------------------------------------------
// _setupToolbar
//
// Constructs the preferences' window toolbar.
// -------------------------------------------------------------------------------
- (void)_setupToolbar
{
	toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Preference Toolbar"] autorelease];
	
	// General preferences
	generalItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
    
	[generalItem setLabel:NSLocalizedString(@"General", @"")];
    [generalItem setImage:[NSImage imageNamed:@"toolbar-preferences-general"]];
    [generalItem setTarget:self];
    [generalItem setAction:@selector(displayGeneralPreferences:)];
	
	// Table preferences
	tablesItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_TABLES];
	
	[tablesItem setLabel:NSLocalizedString(@"Tables", @"")];
	[tablesItem setImage:[NSImage imageNamed:@"toolbar-preferences-tables"]];
	[tablesItem setTarget:self];
	[tablesItem setAction:@selector(displayTablePreferences:)];
	
	// Favorite preferences
	favoritesItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_FAVORITES];
	
	[favoritesItem setLabel:NSLocalizedString(@"Favorites", @"")];
    [favoritesItem setImage:[NSImage imageNamed:@"toolbar-preferences-favorites"]];
    [favoritesItem setTarget:self];
    [favoritesItem setAction:@selector(displayFavoritePreferences:)];
	
	// Notification preferences
	notificationsItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_NOTIFICATIONS];
	
	[notificationsItem setLabel:NSLocalizedString(@"Notifications", @"")];
    [notificationsItem setImage:[NSImage imageNamed:@"toolbar-preferences-notifications"]];
    [notificationsItem setTarget:self];
    [notificationsItem setAction:@selector(displayNotificationPreferences:)];

	// AutoUpdate preferences
	autoUpdateItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_AUTOUPDATE];
	
	[autoUpdateItem setLabel:NSLocalizedString(@"Auto Update", @"")];
    [autoUpdateItem setImage:[NSImage imageNamed:@"toolbar-preferences-autoupdate"]];
    [autoUpdateItem setTarget:self];
    [autoUpdateItem setAction:@selector(displayAutoUpdatePreferences:)];
	
	// Network preferences
	networkItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_NETWORK];
	
	[networkItem setLabel:NSLocalizedString(@"Network", @"")];
    [networkItem setImage:[NSImage imageNamed:@"toolbar-preferences-network"]];
    [networkItem setTarget:self];
    [networkItem setAction:@selector(displayNetworkPreferences:)];
    
	[toolbar setDelegate:self];
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
	[toolbar setAllowsUserCustomization:NO];
	
	[preferencesWindow setToolbar:toolbar];
	[preferencesWindow setShowsToolbarButton:NO];
	
	[self displayGeneralPreferences:nil];
}

// -------------------------------------------------------------------------------
// _resizeWindowForContentView:
//
// Resizes the window to the size of the supplied view.
// -------------------------------------------------------------------------------
- (void)_resizeWindowForContentView:(NSView *)view
{
	// remove all current views
  NSEnumerator *en = [[[preferencesWindow contentView] subviews] objectEnumerator];
  NSView *subview;
  while (subview = [en nextObject]) {
    [subview removeFromSuperview];
  }
  
  // resize window
  [preferencesWindow resizeForContentView:view titleBarVisible:YES];
  
  // add view
  [[preferencesWindow contentView] addSubview:view];
  [view setFrameOrigin:NSMakePoint(0, 0)];
}



// -------------------------------------------------------------------------------
// _updateDefaultFavoritePopup:
//
// Build the default favorite popup button
// -------------------------------------------------------------------------------
- (void)_updateDefaultFavoritePopup;
{
	[defaultFavoritePopup removeAllItems];
	
	// Use the last used favorite
	[defaultFavoritePopup addItemWithTitle:@"Last Used"];
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	
	// Load in current favorites
	[defaultFavoritePopup addItemsWithTitles:[[favoritesController arrangedObjects] valueForKeyPath:@"name"]];
	
	// Add item to switch to edit favorites pane
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	[defaultFavoritePopup addItemWithTitle:@"Edit Favorites…"];
	[[[defaultFavoritePopup menu] itemWithTitle:@"Edit Favorites…"] setAction:@selector(displayFavoritePreferences:)];
	[[[defaultFavoritePopup menu] itemWithTitle:@"Edit Favorites…"] setTarget:self];
	
	// Select the default favorite from prefs
	if (![prefs boolForKey:@"SelectLastFavoriteUsed"]) {
		[defaultFavoritePopup selectItemAtIndex:[prefs integerForKey:@"DefaultFavorite"] + 2];
	} else {
		[defaultFavoritePopup selectItemAtIndex:0];
	}
}



@end
