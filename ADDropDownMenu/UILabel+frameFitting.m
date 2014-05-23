#import "UILabel+frameFitting.h"
 
@implementation UILabel (frameFitting)
 
-(void)resizeToFit{
    float height = [self expectedHeight];
    CGRect newFrame = [self frame];
    newFrame.size.height = ceil(height);
    [self setFrame:newFrame];
}
 
-(float)expectedHeight{
    [self setNumberOfLines:0];
    [self setLineBreakMode:UILineBreakModeWordWrap];
 
    CGSize maximumLabelSize = CGSizeMake(self.frame.size.width,9999);
    
    CGSize expectedLabelSize = [[self text] sizeWithFont:[self font] 
                                            constrainedToSize:maximumLabelSize
                                            lineBreakMode:[self lineBreakMode]]; 
    return expectedLabelSize.height;
}
 
@end
