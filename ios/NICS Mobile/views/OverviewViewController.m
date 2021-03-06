/*|~^~|Copyright (c) 2008-2016, Massachusetts Institute of Technology (MIT)
 |~^~|All rights reserved.
 |~^~|
 |~^~|Redistribution and use in source and binary forms, with or without
 |~^~|modification, are permitted provided that the following conditions are met:
 |~^~|
 |~^~|-1. Redistributions of source code must retain the above copyright notice, this
 |~^~|ist of conditions and the following disclaimer.
 |~^~|
 |~^~|-2. Redistributions in binary form must reproduce the above copyright notice,
 |~^~|this list of conditions and the following disclaimer in the documentation
 |~^~|and/or other materials provided with the distribution.
 |~^~|
 |~^~|-3. Neither the name of the copyright holder nor the names of its contributors
 |~^~|may be used to endorse or promote products derived from this software without
 |~^~|specific prior written permission.
 |~^~|
 |~^~|THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 |~^~|AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 |~^~|IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 |~^~|DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 |~^~|FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 |~^~|DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 |~^~|SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 |~^~|CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 |~^~|OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 |~^~|OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\*/
//
//  ViewController.m
//  SidebarDemo
//
//  Copyright (c) 2013 Appcoda. All rights reserved.
//

#import <GoogleMaps/GoogleMaps.h>
#import "OverviewViewController.h"

@interface OverviewViewController ()

@end

@implementation OverviewViewController
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _dataManager = [DataManager getInstance];
    
    self.navigationItem.hidesBackButton = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SetPullTimersFromOptions) name:@"DidBecomeActive" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startCollabLoadingSpinner) name:@"collabroomStartedLoading" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopCollabLoadingSpinner) name:@"collabroomFinishedLoading" object:nil];
    [self SetPullTimersFromOptions];
    
    [_dataManager.locationManager startUpdatingLocation];
    [_dataManager setOverviewController:self];
    
    _incidentContainerView.layer.borderColor = [UIColor whiteColor].CGColor;
    _incidentContainerView.layer.borderWidth = 2.0f;
    
    _roomContainerView.layer.borderColor = [UIColor whiteColor].CGColor;
    _roomContainerView.layer.borderWidth = 2.0f;
    
    _incidentMenu = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Select Incident",nil) delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    
    _incidentMenu.tag = 50;
    
    NSArray *options = [[[_dataManager getIncidentsList] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    for( NSString *title in options)  {
        [_incidentMenu addButtonWithTitle:title];
    }
    
    [_incidentMenu addButtonWithTitle:NSLocalizedString(@"Cancel",nil)];
    _incidentMenu.cancelButtonIndex = [options count];
    
    NSString *currentIncidentName = [_dataManager getActiveIncidentName];
    if(currentIncidentName != nil){
        _selectedIncident = [[_dataManager getIncidentsList] objectForKey:currentIncidentName];
        [_dataManager requestCollabroomsForIncident:_selectedIncident];
        _selectedIncident.collabrooms = [_dataManager getCollabroomPayloadArray];
        
    }
    
    NSString *currentRoomName = [_dataManager getSelectedCollabroomName];
    if(currentRoomName != nil){
        for(CollabroomPayload *collabroomPayload in _selectedIncident.collabrooms) {
            if([collabroomPayload.name isEqualToString:currentRoomName]){
                _selectedCollabroom = collabroomPayload;
                [_dataManager setSelectedCollabRoomId:collabroomPayload.collabRoomId  collabRoomName:collabroomPayload.name];
            }
        }
    }
    
    if(_selectedIncident == nil) {
        [_selectIncidentButton setTitle:NSLocalizedString(@"Select Incident",nil) forState:UIControlStateNormal];
        [_selectRoomButton setHidden:TRUE];
        [_ChatButtonView setHidden:TRUE];
        [_GeneralMessageButtonView setHidden:TRUE];
        [_ReportsButtonView setHidden:TRUE];
    }else{
        [_selectRoomButton setHidden:FALSE];
        [_selectIncidentButton setTitle:_selectedIncident.incidentname forState:UIControlStateNormal];
        
        NSNotification *IncidentSwitchedNotification = [NSNotification notificationWithName:@"IncidentSwitched" object:_selectedIncident.incidentname];
        
        [_dataManager requestSimpleReportsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings] intValue] immediate:YES];
        [_dataManager requestDamageReportsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings] intValue] immediate:YES];
        [_dataManager requestFieldReportsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings] intValue] immediate:YES];
        [_dataManager requestResourceRequestsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings] intValue] immediate:YES];
        [_dataManager requestMdtRepeatedEvery:[DataManager getMdtUpdateFrequencyFromSettings] immediate:YES];
        [_dataManager requestWfsUpdateRepeatedEvery:[[DataManager getWfsUpdateFrequencyFromSettings] intValue] immediate:YES];
    }
    
    if(_selectedCollabroom == nil){
        [_selectRoomButton setTitle:NSLocalizedString(@"Select Room",nil) forState:UIControlStateNormal];
        [_ChatButtonView setHidden:TRUE];
        [_dataManager setSelectedCollabRoomId:[NSNumber numberWithInt:-1] collabRoomName:@"N/A"];
    }else{
        
        [_dataManager setSelectedCollabRoomId:_selectedCollabroom.collabRoomId collabRoomName:_selectedCollabroom.name];
        
        NSString* incidentNameReplace = [_selectedIncident.incidentname stringByAppendingString:@"-"];
        [_selectRoomButton setTitle:[_selectedCollabroom.name stringByReplacingOccurrencesOfString:incidentNameReplace withString:@""] forState:UIControlStateNormal];
        NSNotification *CollabRoomSwitchedNotification = [NSNotification notificationWithName:@"CollabRoomSwitched" object:_selectedIncident.incidentname];
        
        [_dataManager requestChatMessagesRepeatedEvery:[[DataManager getChatUpdateFrequencyFromSettings] intValue] immediate:YES];
        [_dataManager requestMarkupFeaturesRepeatedEvery:[[DataManager getMapUpdateFrequencyFromSettings] intValue] immediate:YES];
        
        [_selectRoomButton setHidden:FALSE];
        [_ChatButtonView setHidden:FALSE];
        [_GeneralMessageButtonView setHidden:FALSE];
        [_ReportsButtonView setHidden:FALSE];
    }

    _ReportsMenu = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Select Report Type",nil) delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    
    [_ReportsMenu addButtonWithTitle:NSLocalizedString(@"Damage Report",nil)];
//    [_ReportsMenu addButtonWithTitle:NSLocalizedString(@"Resource Request",nil)];
//    [_ReportsMenu addButtonWithTitle:NSLocalizedString(@"Field Report",nil)];
    [_ReportsMenu addButtonWithTitle:NSLocalizedString(@"Weather Report",nil)];
    [_ReportsMenu addButtonWithTitle:NSLocalizedString(@"Cancel",nil)];
    
    _ReportsMenu.tag = 60;
}

//gets called everytime the app is brought back to the forground regardless of what view is currently open
//do not call immediate:yes heres
-(void)SetPullTimersFromOptions{
    [_dataManager requestChatMessagesRepeatedEvery:[[DataManager getChatUpdateFrequencyFromSettings] intValue] immediate:NO];
    [_dataManager requestSimpleReportsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings]intValue] immediate:NO];
    [_dataManager requestDamageReportsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings]intValue] immediate:NO];
    [_dataManager requestFieldReportsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings]intValue] immediate:NO];
    [_dataManager requestResourceRequestsRepeatedEvery:[[DataManager getReportsUpdateFrequencyFromSettings]intValue] immediate:NO];
    [_dataManager requestMarkupFeaturesRepeatedEvery:[[DataManager getMapUpdateFrequencyFromSettings]intValue] immediate:NO];
    [_dataManager requestMdtRepeatedEvery:[DataManager getMdtUpdateFrequencyFromSettings] immediate:NO];
    [_dataManager requestWfsUpdateRepeatedEvery:[[DataManager getWfsUpdateFrequencyFromSettings]intValue] immediate:NO];
    //    [_dataManager requestActiveAssignmentRepeatedEvery:30];
    
}

- (IBAction)selectIncidentButtonPressed:(UIButton *)button {
    [_incidentMenu showInView:self.parentViewController.view];
}

- (IBAction)selectRoomButtonPressed:(UIButton *)button {
    NSMutableDictionary *collabrooms = [NSMutableDictionary new];
    _selectedIncident.collabrooms = _selectedIncident.collabrooms;
    
    for(CollabroomPayload *collabroomPayload in _selectedIncident.collabrooms) {
        [collabrooms setObject:collabroomPayload.collabRoomId forKey:collabroomPayload.name];
    }
    
    
    if(_selectedIncident.collabrooms != nil) {
        [_dataManager clearCollabRoomList];
        
        for(CollabroomPayload *payload in _selectedIncident.collabrooms) {
            [_dataManager addCollabroom:payload];
        }
    }
    
    NSArray * sortedCollabrooms = [[collabrooms allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    _collabroomMenu = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Select Room",nil) delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    
    NSString *replaceString = @"";
    replaceString = [_selectedIncident.incidentname stringByAppendingString:@"-"];
    
    for( NSString *title in sortedCollabrooms)  {
        [_collabroomMenu addButtonWithTitle:[title stringByReplacingOccurrencesOfString:replaceString withString:@""]];
    }
    
    [_collabroomMenu addButtonWithTitle:NSLocalizedString(@"Cancel",nil)];
    _collabroomMenu.cancelButtonIndex = [sortedCollabrooms count];
    
    [_collabroomMenu showInView:self.parentViewController.view];
}
- (IBAction)ReportsButtonPressed:(id)sender {
    [_ReportsMenu showInView:self.parentViewController.view];
}

- (IBAction)nicsHelpButtonPressed:(id)sender {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://public.nics.ll.mit.edu/nicshelp/"]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [_dataManager.locationManager stopUpdatingLocation];
}

//fix for ghosting effect on ios7
- (void)willPresentActionSheet:(UIActionSheet *)actionSheet {
    actionSheet.backgroundColor = [UIColor blackColor];
    for (UIView *subview in actionSheet.subviews) {
        subview.backgroundColor = [UIColor blackColor];
    }
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *replaceString = @"";
    
    if(actionSheet.tag == 50) {
        if(buttonIndex != _incidentMenu.cancelButtonIndex) {
            
            _selectedIncident = [[_dataManager getIncidentsList] objectForKey:[actionSheet buttonTitleAtIndex:buttonIndex]];
            
            [_dataManager requestCollabroomsForIncident:_selectedIncident];
            _selectedIncident.collabrooms = [_dataManager getCollabroomPayloadArray];
            
            [_dataManager setSelectedCollabRoomId:@-1 collabRoomName:@"N/A"];
            _selectedCollabroom = nil;
        }
    }else if(actionSheet.tag == 60){
        
//        enum ReportTypesMenu reportType = buttonIndex;
        
        switch (buttonIndex) {
            case 0:
                [self performSegueWithIdentifier:@"segue_damage_report" sender:self];
                break;
//            case 1:
//                [self performSegueWithIdentifier:@"segue_resource_request" sender:self];
//                break;
//            case 2:
//                 [self performSegueWithIdentifier:@"segue_field_report" sender:self];
//                break;
            case 1:
                [self performSegueWithIdentifier:@"segue_weather_report" sender:self];
                break;
            default:
                break;
        }

    
    }else {
        replaceString = [_selectedIncident.incidentname stringByAppendingString:@"-"];
        if(buttonIndex != _collabroomMenu.cancelButtonIndex) {
//            _selectedCollabroom = [[_dataManager getCollabroomList] objectForKey:[[_dataManager getCollabroomNamesList] objectForKey:[replaceString stringByAppendingString:[actionSheet buttonTitleAtIndex:buttonIndex]]]];
            NSString* selectedRoom = [actionSheet buttonTitleAtIndex:buttonIndex];
            _selectedCollabroom = [[_dataManager getCollabroomList] objectForKey:[[_dataManager getCollabroomNamesList] objectForKey:selectedRoom]];
        }
    }
    
    if(_selectedIncident != nil) {
        [_dataManager setActiveIncident:_selectedIncident];
        
        [_roomContainerView setHidden:NO];
        [_selectRoomButton setHidden:NO];
        
        [_GeneralMessageButtonView setHidden:NO];
        [_ReportsButtonView setHidden:NO];
        
        [_selectIncidentButton setTitle: _selectedIncident.incidentname forState:UIControlStateNormal];
    } else {
        [_selectIncidentButton setTitle: NSLocalizedString(@"Select Incident",nil) forState:UIControlStateNormal];
        
//        [_roomContainerView setHidden:YES];
        [_selectRoomButton setHidden:YES];
        
        [_GeneralMessageButtonView setHidden:YES];
        [_ReportsButtonView setHidden:YES];
    }
    
    if(_selectedCollabroom != nil) {
        [_dataManager setSelectedCollabRoomId:_selectedCollabroom.collabRoomId collabRoomName:_selectedCollabroom.name];
        
        [_ChatButtonView setHidden:NO];
        [_MapButtonView setHidden:NO];
        
        NSString* abreviatedCollabRoomName = [_selectedCollabroom.name stringByReplacingOccurrencesOfString:[_selectedIncident.incidentname stringByAppendingString:@"-"] withString:@""];
        
        [_selectRoomButton setTitle:abreviatedCollabRoomName forState:UIControlStateNormal];
    } else {
        [_selectRoomButton setTitle: NSLocalizedString(@"Select Room",nil) forState:UIControlStateNormal];
        
        [_ChatButtonView setHidden:YES];
//        [_MapButtonView setHidden:YES];
    }
}

-(void)startCollabLoadingSpinner{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [_collabroomsLoadingIndicator startAnimating];
    });
    
}

-(void)stopCollabLoadingSpinner{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [_collabroomsLoadingIndicator stopAnimating];
        _selectedIncident.collabrooms = [_dataManager getCollabroomPayloadArray];
    });
    
}
@end
