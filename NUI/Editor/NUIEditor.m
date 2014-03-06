//
//  NUIEditor.n
//  Shopping
//
//  Created by Tony Mann on 3/4/14.
//  Copyright (c) 2014 TheFind. All rights reserved.
//

#import "NUIEditor.h"
#import "NUISettings.h"
#import "NUIRenderer.h"
#import "NUIStyleParser.h"

@interface NUIEditor ()
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *resetButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *mailButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationBarItem;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSString *originalText;
@property (strong, nonatomic) UIActionSheet *resetActionSheet;
@property (strong, nonatomic) UIActionSheet *confirmSaveActionSheet;
@property (strong, nonatomic) UIActionSheet *deleteActionSheet;
@property (nonatomic) BOOL dirty;
@end

@implementation NUIEditor

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.path = [NUISettings stylesheetPath];
    self.originalText  = [NSString stringWithContentsOfFile:self.path
                                                 encoding:NSUTF8StringEncoding
                                                    error:NULL];
    self.textView.text = self.originalText;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShowOrHide:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShowOrHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [self updateControls];
}

- (IBAction)saveButtonWasTapped:(id)sender
{
    [self saveChanges];
}

- (IBAction)resetButtonWasTapped:(id)sender
{
    self.resetActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                         delegate:self
                                                cancelButtonTitle:@"Cancel"
                                           destructiveButtonTitle:@"Reset To Original"
                                                otherButtonTitles:nil];
    
    [self.resetActionSheet showFromBarButtonItem:self.resetButton animated:YES];
}

- (IBAction)mailButtonWasTapped:(id)sender
{
    MFMailComposeViewController *mailer = [MFMailComposeViewController new];
    mailer.mailComposeDelegate = self;
    
    NSString *subject = [NSString stringWithFormat:@"%@ stylesheet", [NUISettings stylesheetName]];
    [mailer setSubject:subject];

    [mailer addAttachmentData:[self.textView.text dataUsingEncoding:NSUTF8StringEncoding]
                     mimeType:@"text/plain"
                     fileName:[NSString stringWithFormat:@"%@.nss", [NUISettings stylesheetName]]];

    [self presentViewController:mailer animated:YES completion:nil];
}

- (IBAction)deleteButtonWasTapped:(id)sender
{
    self.deleteActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                         delegate:self
                                                cancelButtonTitle:nil
                                           destructiveButtonTitle:@"Delete Custom Stylesheet"
                                                otherButtonTitles:nil];
    
    [self.deleteActionSheet showFromBarButtonItem:self.deleteButton animated:YES];
}

- (IBAction)doneButtonWasTapped:(id)sender
{
    if (self.dirty) {
        self.confirmSaveActionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                  delegate:self
                                                         cancelButtonTitle:@"Cancel"
                                                    destructiveButtonTitle:@"Don't Save"
                                                         otherButtonTitles:@"Save Changes", nil];
        
        [self.confirmSaveActionSheet showFromBarButtonItem:self.doneButton animated:YES];
    } else {
        [self close];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (actionSheet == self.resetActionSheet) {
        self.textView.text = [NSString stringWithContentsOfFile:[NUISettings stylesheetBundlePath]
                                                       encoding:NSUTF8StringEncoding
                                                          error:NULL];
        self.dirty = YES;
        [self updateControls];
    } else if (actionSheet == self.confirmSaveActionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            if (buttonIndex == actionSheet.destructiveButtonIndex) {
                [self close];
            } else {
                if ([self saveChanges]) {
                    [self close];
                }
            }
        }
    } else if (actionSheet == self.deleteActionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:self.path error:&error];
            
            if (error) {
                NSLog(@"Could not delete stylesheet: %@", error.localizedDescription);
            } else {
                self.path = [NUISettings stylesheetBundlePath];
                [NUIRenderer stylesheetFileChanged:self.path];
                [self close];
            }
        }
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (!self.dirty) {
        self.dirty = YES;
        [self updateControls];
    }
}

- (void)keyboardWillShowOrHide:(NSNotification *)notification
{
    NSDictionary* userInfo = [notification userInfo];
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    CGRect keyboardFrame;
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:animationDuration];
    [UIView setAnimationCurve:animationCurve];
    CGFloat delta = keyboardFrame.size.height;
    
    if (notification.name == UIKeyboardWillHideNotification)
        delta = -delta;
    
    [self.toolbar setFrame:CGRectMake(self.toolbar.frame.origin.x, self.toolbar.frame.origin.y - delta, self.toolbar.frame.size.width, self.toolbar.frame.size.height)];
    [self.textView setFrame:CGRectMake(self.textView.frame.origin.x, self.textView.frame.origin.y, self.textView.frame.size.width, self.textView.frame.size.height - delta)];
    [UIView commitAnimations];
}

#pragma mark -

- (BOOL)saveChanges
{
    if (![self reloadStyles]) {
        [self showSaveErrorMessage:@"Stylesheet has syntax errors"];
        return NO;
    }
    
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:[NUISettings stylesheetsDirectory]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    
    if (error != nil) {
        [self showSaveErrorMessage:[NSString stringWithFormat:@"Error creating stylesheets directory: %@", error]];
        return NO;
    }
    
    self.path = [NUISettings stylesheetFilePath];
    error = nil;
    [self.textView.text writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (error != nil) {
        [self showSaveErrorMessage:[NSString stringWithFormat:@"Error saving stylesheet: %@", error]];
        return NO;
    }
    
    self.dirty = NO;
    [self updateControls];
    
    return YES;
}
    
- (BOOL)reloadStyles
{
    if ([self.self.textView.text isEqualToString:self.originalText])
        return YES;
    
    BOOL parsed = [NUISettings loadStylesheetFromString:self.textView.text];
    
    if (!parsed)
        return NO;
    
    @try {
        [NUIRenderer rerenderImmediately];
    }
    @catch (NSException *exception) {
        [NUIRenderer stylesheetFileChanged:self.path];
        return NO;
    }
    
    return YES;
}

- (void)updateControls
{
    BOOL isCustomStylesheet = [self.path isEqualToString:[NUISettings stylesheetFilePath]];
    
    self.deleteButton.enabled = isCustomStylesheet;
    self.resetButton.enabled  = self.dirty || isCustomStylesheet;
    self.saveButton.enabled   = self.dirty;
    
    NSString *title = [NUISettings stylesheetName];
    
    if (self.dirty)
        title = [title stringByAppendingString:@" •"];
    
    self.navigationBarItem.title = title;
}

- (void)showSaveErrorMessage:(NSString *)message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Cannot save"
                                                        message:message
                                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

- (void)close
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
