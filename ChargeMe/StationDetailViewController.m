//
//  StationDetailViewController.m
//  ChargeMe
//
//  Created by Tewodros Wondimu on 2/12/15.
//  Copyright (c) 2015 Mary Jenel Myers. All rights reserved.
//

#import "StationDetailViewController.h"
#import "PayPalPaymentViewController.h"
#import "CustomAnnotation.h"
#import <Parse/Parse.h>
#import "Bookmark.h"

@interface StationDetailViewController () <PayPalPaymentDelegate, MKMapViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong, readwrite) PayPalConfiguration *payPalConfig;
@property BOOL acceptCreditCards;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *hoursTextField;

@property NSArray *commentsArray;

@end

@implementation StationDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set up payPalConfig
    _payPalConfig = [[PayPalConfiguration alloc] init];
    _payPalConfig.acceptCreditCards = YES;
    _payPalConfig.merchantName = self.chargingStation.stationName;
    _payPalConfig.merchantPrivacyPolicyURL = [NSURL URLWithString:@"https://www.paypal.com/webapps/mpp/ua/privacy-full"];
    _payPalConfig.merchantUserAgreementURL = [NSURL URLWithString:@"https://www.paypal.com/webapps/mpp/ua/useragreement-full"];

    // setup map
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;

    CLLocationDegrees latitude = self.chargingStation.latitude;
    CLLocationDegrees longitude = self.chargingStation.longitude;

    MKCoordinateRegion region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(latitude, longitude), MKCoordinateSpanMake(0.5, 0.5));
    [self.mapView setRegion:region animated:YES];

    [self loadMap];
    
}

- (void)loadMap
{
    CLLocationDegrees longitude;

    if (self.chargingStation.longitude < 0)
    {
        longitude = self.chargingStation.longitude;
    }
    else
    {
        longitude = -self.chargingStation.longitude;
    }

    CLLocationDegrees latitude = self.chargingStation.latitude;
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);

    CustomAnnotation *annotation = [CustomAnnotation new];
    annotation.chargingStation = self.chargingStation;
    annotation.title = self.chargingStation.stationAddress;
    annotation.subtitle = self.chargingStation.stationName;
    annotation.coordinate = coordinate;

    [self.mapView addAnnotation:annotation];
}


-(MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    // Lets the mapView display the blue dot & circle animation
    if (annotation == mapView.userLocation) return nil;

    MKPinAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:nil];
    pin.canShowCallout = YES;

//    pin.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];

    return pin;
}
- (IBAction)onButtonPressedDirectionsFromCurrentLocation:(id)sender
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(self.chargingStation.latitude, self.chargingStation.longitude);
    MKPlacemark* place = [[MKPlacemark alloc] initWithCoordinate: coordinate addressDictionary: nil];
    MKMapItem* destination = [[MKMapItem alloc] initWithPlacemark: place];
    destination.name = self.chargingStation.stationName;
    NSArray* items = [[NSArray alloc] initWithObjects: destination, nil];
    NSDictionary* options = [[NSDictionary alloc] initWithObjectsAndKeys:
                             MKLaunchOptionsDirectionsModeDriving,
                             MKLaunchOptionsDirectionsModeKey, nil];
    [MKMapItem openMapsWithItems: items launchOptions: options];
}

- (IBAction)onAddToFavoritesButtonPressed:(id)sender {
    
    PFObject *user = [PFUser currentUser];
//        PFRelation *relation = [user relationForKey:@"station_name"];
//        [user saveInBackground];
    PFObject *bookmark = [PFObject objectWithClassName:@"Bookmarks"];
//    bookmark[@"station"] = @"My New Post";
    bookmark[@"user"] = user;
    [bookmark saveInBackground];
}
- (IBAction)onAddCommentButtonPressed:(id)sender {
    
    UIAlertController *alertcontroller = [UIAlertController alertControllerWithTitle:@"Add A Comment!" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertcontroller addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         nil;
     }];
    
    UIAlertAction *okayAction = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
         {
             UITextField *textField = alertcontroller.textFields.firstObject;
             PFObject *myComment = [PFObject objectWithClassName:@"Comment"];
             myComment[@"commentContext"] = textField.text;
//                                     myComment[@"photo"] = self.photoObject;
             myComment[@"user"] = [PFUser currentUser];
             [myComment saveInBackground];
             [self getAllComments];
         }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alertcontroller addAction:okayAction];
    [alertcontroller addAction:cancelAction];
    
    [self presentViewController:alertcontroller animated:YES completion:^{
        nil;
    }];

}

#pragma mark Tableview Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.commentsArray.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    PFObject *comment = self.commentsArray[indexPath.row];
    cell.textLabel.text = comment[@"commentContext"];
    
    return cell;
}

#pragma mark Helper Methods

- (void)getAllComments {
    //PULL OBJECT "PHOTO
    //SET A QUERY THOUGH THE OBJECT TO FIND THE COMMENT IT'S RELATED TO
    //LOAD IT ON TABLE VIEW
    
    PFQuery *query = [PFQuery queryWithClassName:@"Comment"];
//    [query whereKey:@"photo" equalTo:self.photoObject];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
     {
         self.commentsArray = objects;
         [self.tableView reloadData];
     }];
}
#pragma mark PayPalPaymentDelegate methods

- (IBAction)onCheckInButtonPressed:(UIBarButtonItem *)sender
{
    // Optional: include multiple items
    NSDecimalNumber *charge = [NSDecimalNumber decimalNumberWithString:@"39.99"];
    int hours = [self.hoursTextField.text intValue];
    PayPalItem *item1 = [PayPalItem itemWithName:self.chargingStation.stationName
                                    withQuantity:hours
                                       withPrice:charge
                                    withCurrency:@"USD"
                                         withSku:@"CHS-00037"];
    NSArray *items = @[item1];
    NSDecimalNumber *subtotal = [PayPalItem totalPriceForItems:items];

    // Optional: include payment details
    NSDecimalNumber *shipping = [[NSDecimalNumber alloc] initWithString:@"0.00"];
    float taxValue = floorf(([charge floatValue] * (7.5/100) * 100) / 100);
    NSDecimalNumber *tax = [[NSDecimalNumber alloc] initWithFloat:taxValue];
    PayPalPaymentDetails *paymentDetails = [PayPalPaymentDetails paymentDetailsWithSubtotal:subtotal
                                                                               withShipping:shipping
                                                                                    withTax:tax];

    NSDecimalNumber *total = [[subtotal decimalNumberByAdding:shipping] decimalNumberByAdding:tax];

    PayPalPayment *payment = [[PayPalPayment alloc] init];
    payment.amount = total;
    payment.currencyCode = @"USD";
    payment.shortDescription = @"Charging Station Costs";
    payment.items = items;  // if not including multiple items, then leave payment.items as nil
    payment.paymentDetails = paymentDetails; // if not including payment details, then leave payment.paymentDetails as nil

    if (!payment.processable) {
        // This particular payment will always be processable. If, for
        // example, the amount was negative or the shortDescription was
        // empty, this payment wouldn't be processable, and you'd want
        // to handle that here.
    }

    // Update payPalConfig reaccepting credit cards.
    self.payPalConfig.acceptCreditCards = self.acceptCreditCards;

    PayPalPaymentViewController *paymentViewController = [[PayPalPaymentViewController alloc] initWithPayment:payment configuration:self.payPalConfig delegate:self];
    [self presentViewController:paymentViewController animated:YES completion:nil];
}

- (void)payPalPaymentViewController:(PayPalPaymentViewController *)paymentViewController didCompletePayment:(PayPalPayment *)completedPayment {
    NSLog(@"PayPal Payment Success! %@", [completedPayment description]);

    //    [self sendCompletedPaymentToServer:completedPayment]; // Payment was processed successfully; send to server for verification and fulfillment
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)payPalPaymentDidCancel:(PayPalPaymentViewController *)paymentViewController {
    NSLog(@"PayPal Payment Canceled");
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
