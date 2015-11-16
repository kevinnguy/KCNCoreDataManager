//
//  ViewController.m
//  KCNCoreDataManager
//
//  Created by Kevin Nguy on 8/20/15.
//  Copyright (c) 2015 kevinnguy. All rights reserved.
//

#import "ViewController.h"

#import "KCNCoreDataManager.h"

#import "Person.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[KCNCoreDataManager sharedManager] setupCoreDataStackWithName:@"Test"];
    
    NSArray *array = [[KCNCoreDataManager sharedManager] findFetchRequestWithEntityClass:[Person class] predicate:nil batchSize:0];
    
    [[KCNCoreDataManager sharedManager] saveInBackgroundBlockAndWait:^(NSManagedObjectContext *context) {
        NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Person" inManagedObjectContext:context];
        Person *person = [[Person alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:context];
        [person setValue:@"Kevin" forKey:@"name"];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
