//
//  MDMFetchedResultsTableDataSource.m
//
//  Copyright (c) 2014 Matthew Morey.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "MDMFetchedResultsTableDataSource.h"
#import "MDMCoreDataMacros.h"

@interface MDMFetchedResultsTableDataSource ()

@property (nonatomic, weak) UITableView *tableView;

@property (nonatomic, strong) NSMutableIndexSet *deletedSectionIndexes;
@property (nonatomic, strong) NSMutableIndexSet *insertedSectionIndexes;
@property (nonatomic, strong) NSMutableArray *deletedRowIndexPaths;
@property (nonatomic, strong) NSMutableArray *insertedRowIndexPaths;
@property (nonatomic, strong) NSMutableArray *updatedRowIndexPaths;

@end

@implementation MDMFetchedResultsTableDataSource

#pragma mark - Lifecycle

- (id)initWithTableView:(UITableView *)tableView
fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    
    self = [super init];
    if (self) {
        
        _tableView = tableView;
        _fetchedResultsController = fetchedResultsController;
        [self setupFetchedResultsController:fetchedResultsController];
    }
    
    return self;
}

#pragma mark - Private Methods

- (void)setupFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    
    fetchedResultsController.delegate = self;
    BOOL fetchSuccess = [fetchedResultsController performFetch:NULL];
    ZAssert(fetchSuccess, @"Fetch request does not include sort descriptor that uses the section name.");
    [self.tableView reloadData];
}

- (id)itemAtIndexPath:(NSIndexPath *)path {
    
    return [self.fetchedResultsController objectAtIndexPath:path];
}

#pragma mark - Public Setters

- (void)setFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    
    if (_fetchedResultsController != fetchedResultsController) {
        
        _fetchedResultsController = fetchedResultsController;
        [self setupFetchedResultsController:fetchedResultsController];
    }
}

- (void)setPaused:(BOOL)paused {
    
    _paused = paused;
    if (paused) {
        self.fetchedResultsController.delegate = nil;
    } else {
        self.fetchedResultsController.delegate = self;
        [self.fetchedResultsController performFetch:NULL];
        [self.tableView reloadData];
    }
}

#pragma mark - Public Methods

- (id)selectedItem {
    
    NSIndexPath *path = [self.tableView indexPathForSelectedRow];
    
    return path ? [self itemAtIndexPath:path] : nil;
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section {
    
    if (section < [self.fetchedResultsController.sections count]) {

        return [self.fetchedResultsController.sections[section] numberOfObjects];
    }
    
    return 0; // If section doesn't exist return 0
}

- (NSUInteger)numberOfRowsInAllSections {
    
    NSUInteger totalRows = 0;
    NSUInteger totalSections = [self.fetchedResultsController.sections count];
    
    for (NSUInteger section = 0; section < totalSections; section++) {
        totalRows = totalRows + [self numberOfRowsInSection:section];
    }
    
    return totalRows;
}

- (NSIndexPath *)indexPathForObject:(id)object {
    
    return [self.fetchedResultsController indexPathForObject:object];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
   
    return [self numberOfRowsInSection:(NSUInteger)section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSString *reuseIdentifier = self.reuseIdentifier;

    if (reuseIdentifier == nil) {
        ZAssert([self.delegate respondsToSelector:@selector(dataSource:reuseIdentifierForObject:atIndexPath:)], @"You need to set the `reuseIdentifier` property or implement the optional dataSource:reuseIdentifierForObject:atIndexPath: delegate method.");
        reuseIdentifier = [self.delegate dataSource:self reuseIdentifierForObject:object atIndexPath:indexPath];
    }

    id cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    [self.delegate dataSource:self configureCell:cell withObject:object];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
 
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete: {
            [self.delegate dataSource:self deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]
                          atIndexPath:indexPath];
            
            break;
        }
            
        default:
            ALog(@"Missing UITableViewCellEditingStyle case");
            
            break;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self.delegate respondsToSelector:@selector(dataSource:tableView:titleForHeaderInSection:)]) {
        return [self.delegate dataSource:self tableView:tableView titleForHeaderInSection:section];
    } else {
        return nil;
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

// reference: https://gist.github.com/MrRooni/4988922
// http://www.fruitstandsoftware.com/blog/2013/02/19/uitableview-and-nsfetchedresultscontroller-updates-done-right/

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    NSInteger totalChanges = [self.deletedSectionIndexes count] +
    [self.insertedSectionIndexes count] +
    [self.deletedRowIndexPaths count] +
    [self.insertedRowIndexPaths count] +
    [self.updatedRowIndexPaths count];
    if (totalChanges > 50) {
        [self.tableView reloadData];
        return;
    }
    
    [self.tableView beginUpdates];
    
    [self.tableView deleteSections:self.deletedSectionIndexes withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView insertSections:self.insertedSectionIndexes withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [self.tableView deleteRowsAtIndexPaths:self.deletedRowIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
    [self.tableView insertRowsAtIndexPaths:self.insertedRowIndexPaths withRowAnimation:UITableViewRowAnimationRight];
    [self.tableView reloadRowsAtIndexPaths:self.updatedRowIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [self.tableView endUpdates];
    
    // nil out the collections so their ready for their next use.
    self.insertedSectionIndexes = nil;
    self.deletedSectionIndexes = nil;
    self.deletedRowIndexPaths = nil;
    self.insertedRowIndexPaths = nil;
    self.updatedRowIndexPaths = nil;
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id )sectionInfo atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
    
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.insertedSectionIndexes addIndex:sectionIndex];
            break;
        case NSFetchedResultsChangeDelete:
            [self.deletedSectionIndexes addIndex:sectionIndex];
            break;
        default:
            ; // Shouldn't have a default
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    if (type == NSFetchedResultsChangeInsert) {
        if ([self.insertedSectionIndexes containsIndex:newIndexPath.section]) {
            // If we've already been told that we're adding a section for this inserted row we skip it since it will handled by the section insertion.
            return;
        }
        [self.insertedRowIndexPaths addObject:newIndexPath];
    } else if (type == NSFetchedResultsChangeDelete) {
        if ([self.deletedSectionIndexes containsIndex:indexPath.section]) {
            // If we've already been told that we're deleting a section for this deleted row we skip it since it will handled by the section deletion.
            return;
        }
        [self.deletedRowIndexPaths addObject:indexPath];
    } else if (type == NSFetchedResultsChangeMove) {
        if ([self.insertedSectionIndexes containsIndex:newIndexPath.section] == NO) {
            [self.insertedRowIndexPaths addObject:newIndexPath];
        }
        if ([self.deletedSectionIndexes containsIndex:indexPath.section] == NO) {
            [self.deletedRowIndexPaths addObject:indexPath];
        }
    } else if (type == NSFetchedResultsChangeUpdate) {
        [self.updatedRowIndexPaths addObject:indexPath];
    }
}


#pragma mark - Overridden getters

/**
 * Lazily instantiate these collections.
 */

- (NSMutableIndexSet *)deletedSectionIndexes {
    if (_deletedSectionIndexes == nil) {
        _deletedSectionIndexes = [[NSMutableIndexSet alloc] init];
    }
    return _deletedSectionIndexes;
}

- (NSMutableIndexSet *)insertedSectionIndexes {
    if (_insertedSectionIndexes == nil) {
        _insertedSectionIndexes = [[NSMutableIndexSet alloc] init];
    }
    return _insertedSectionIndexes;
}

- (NSMutableArray *)deletedRowIndexPaths {
    if (_deletedRowIndexPaths == nil) {
        _deletedRowIndexPaths = [[NSMutableArray alloc] init];
    }
    return _deletedRowIndexPaths;
}

- (NSMutableArray *)insertedRowIndexPaths {
    if (_insertedRowIndexPaths == nil) {
        _insertedRowIndexPaths = [[NSMutableArray alloc] init];
    }
    return _insertedRowIndexPaths;
}

- (NSMutableArray *)updatedRowIndexPaths {
    if (_updatedRowIndexPaths == nil) {
        _updatedRowIndexPaths = [[NSMutableArray alloc] init];
    }
    return _updatedRowIndexPaths;
}

@end
