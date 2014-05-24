//
//  ADDropDownMenuView.m
//  ADDropDownMenuDemo
//
//  Created by Anton Domashnev on 16.12.13.
//  Copyright (c) 2013 Anton Domashnev. All rights reserved.
//

#import "ADDropDownMenuView.h"
#import "ADDropDownMenuItemView.h"
#import <QuartzCore/QuartzCore.h>

#define SEPARATOR_VIEW_HEIGHT 1
#define BOARDER_VIEW_WIDTH 1
#define DIM_VIEW_TAG 1919101910

@interface ADDropDownMenuView()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong, readwrite) NSMutableArray *itemsViews;
@property (nonatomic, strong) NSMutableArray *separators;
@property (nonatomic, strong) NSMutableArray *borders;

@property (nonatomic, unsafe_unretained, readwrite) BOOL isOpen;
@property (nonatomic, unsafe_unretained) BOOL isAnimating;
@property (nonatomic, unsafe_unretained) BOOL shouldContractOnTouchesEnd;

@property (nonatomic, strong) NSArray *initialItems;

@end

@implementation ADDropDownMenuView

- (instancetype)initAtOrigin:(CGPoint)origin withItemsViews:(NSArray *)itemsViews{
    
    NSAssert(itemsViews.count > 0, @"ADDropDownMenuView should have atleast one item view");
	
	CGRect frame = {
		.origin = origin,
		.size = CGSizeMake(((ADDropDownMenuItemView *)[itemsViews firstObject]).frame.size.width,
						   [ADDropDownMenuView contractedHeightForItemsViews:itemsViews])
	};
    
    if(self = [super initWithFrame: frame]){
		[self setup:itemsViews];
	}
    
    return self;
}

- (void)setup:(NSArray *)itemsViews {
	self.backgroundColor = [UIColor clearColor];
	self.itemsViews = [itemsViews mutableCopy];
	self.separators = [NSMutableArray array];
	self.borders = [NSMutableArray array];
	self.menuAnimationDuration = 0.3f;
	self.disableDimView = NO;
	self.orderedMenuList = NO;
	
	[self addDimView];
	[self addContainerView];
	[self addItemsViewsAndSeparatorsAndBorders];
	[self selectItem: [self.itemsViews firstObject]];
	self.initialItems = [NSArray arrayWithArray:itemsViews];
}

#pragma mark - Properties

- (void)setSeparatorColor:(UIColor *)separatorColor{
    
    _separatorColor = separatorColor;
    [self.separators enumerateObjectsUsingBlock:^(UIView *separatorView, NSUInteger idx, BOOL *stop) {
        separatorView.backgroundColor = separatorColor;
    }];
}

- (void)setBorderColor:(UIColor *)borderColor {
	
	_borderColor = borderColor;
	[self.borders enumerateObjectsUsingBlock:^(UIView *borderView, NSUInteger idx, BOOL *stop) {
		borderView.backgroundColor = borderColor;
	}];
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    
    CGPoint locationPoint = [[touches anyObject] locationInView:self];
    UIView *itemView = [self hitTest:locationPoint withEvent:event];
    if([itemView isKindOfClass: [ADDropDownMenuItemView class]]){
        [self highlightItem: (ADDropDownMenuItemView *)itemView];
        [self expand];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    
    CGPoint locationPoint = [[touches anyObject] locationInView:self];
    UIView* itemView = [self hitTest:locationPoint withEvent:event];
    if([itemView isKindOfClass: [ADDropDownMenuItemView class]]){
        [self highlightItem: (ADDropDownMenuItemView *)itemView];
    }
    else{
        [self highlightItem: nil];
    }
    
    self.shouldContractOnTouchesEnd = YES;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView: self];
    if(touchLocation.y > 0){
        [self userDidEndTouches:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    
    if(!self.isAnimating){
        [self userDidEndTouches:touches withEvent:event];
    }
}

- (void)userDidEndTouches:(NSSet *)touches withEvent:(UIEvent *)event{
    
    CGPoint locationPoint = [[touches anyObject] locationInView:self];
    UIView* itemView = [self hitTest:locationPoint withEvent:event];
    
    if(itemView.tag == DIM_VIEW_TAG){
        self.shouldContractOnTouchesEnd = NO;
        [self selectItem: [self.itemsViews firstObject]];
        [self contract];
    }
    else{
        if(self.shouldContractOnTouchesEnd){
            
            if([itemView isKindOfClass: [ADDropDownMenuItemView class]]){
                self.shouldContractOnTouchesEnd = NO;
                [self selectItem: (ADDropDownMenuItemView *)itemView];
                [self exchangeItem:(ADDropDownMenuItemView *)itemView withItem:[self.itemsViews firstObject]];
                
                if([self.delegate respondsToSelector:@selector(ADDropDownMenu:didSelectItem:)]){
                    [self.delegate ADDropDownMenu:self didSelectItem:(ADDropDownMenuItemView *)itemView];
                }
                
                [self contract];
            }
        }
        else{
            self.shouldContractOnTouchesEnd = YES;
            [self selectItem: [self.itemsViews firstObject]];
        }
    }
}

#pragma mark - UI

- (void)addDimView{

    self.dimView = [[UIView alloc] initWithFrame: self.bounds];
    self.dimView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.dimView.backgroundColor = [UIColor blackColor];
    self.dimView.alpha = 0.;
    self.dimView.tag = DIM_VIEW_TAG;
    [self addSubview: self.dimView];
}

- (void)addContainerView{
    
    self.containerView = [[UIView alloc] initWithFrame: ((ADDropDownMenuItemView *)[self.itemsViews firstObject]).bounds];
    self.containerView.backgroundColor = [UIColor clearColor];
    self.containerView.clipsToBounds = YES;
    [self addSubview: self.containerView];
}

- (void)addItemsViewsAndSeparatorsAndBorders{
    
    NSUInteger itemsCount = self.itemsViews.count;
    __block CGFloat itemY = 0;
    
    [self.itemsViews enumerateObjectsUsingBlock:^(ADDropDownMenuItemView *item, NSUInteger idx, BOOL *stop) {
        
		// Setup an item's frame and add it to the container
        item.frame = (CGRect){.origin = CGPointMake(item.frame.origin.x, itemY), .size = item.frame.size};
		item.tag = idx;
        [self.containerView addSubview: item];
		
		// Setup the top border
		if (idx == 0) {
			UIView *topBorder = [self separatorView];
			
			[self.borders addObject:topBorder];
			topBorder.frame = (CGRect){.origin = CGPointMake(0, 0), .size = topBorder.frame.size};
			topBorder.layer.zPosition = MAXFLOAT;
			[self.containerView addSubview:topBorder];
		}
        
		// Setup the vertical borders
		UIView *leftVerticalBorder = [self borderView];
		UIView *rightVerticalBorder = [self borderView];
		leftVerticalBorder.frame = (CGRect){.origin = CGPointMake(0, itemY), .size = leftVerticalBorder.frame.size};
		rightVerticalBorder.frame = (CGRect){.origin = CGPointMake(item.frame.size.width-1, itemY), .size = rightVerticalBorder.frame.size};
		leftVerticalBorder.layer.zPosition = MAXFLOAT;
		rightVerticalBorder.layer.zPosition = MAXFLOAT;
		
		[self.containerView addSubview:leftVerticalBorder];
		[self.containerView addSubview:rightVerticalBorder];
		
		[self.borders addObjectsFromArray:@[leftVerticalBorder, rightVerticalBorder]];
		
		// Setup the separators
		if(idx < itemsCount - 1){
			UIView *separatorView = [self separatorView];

			[self.separators addObject:separatorView];
            separatorView.frame = (CGRect){.origin = CGPointMake(separatorView.frame.origin.x, itemY + item.frame.size.height), .size = separatorView.frame.size};
			[self.containerView addSubview:separatorView];
			itemY = separatorView.frame.size.height + separatorView.frame.origin.y;
        }
		
		// Setup the bottom border
		if (idx == [self.itemsViews count]-1) {
			UIView *bottomBorder = [self separatorView];
			
			[self.borders addObject:bottomBorder];
			bottomBorder.frame = (CGRect){.origin = CGPointMake(0, itemY+item.frame.size.height-1), .size = bottomBorder.frame.size};
			bottomBorder.layer.zPosition = MAXFLOAT;
			[self.containerView addSubview:bottomBorder];
		}
		
    }];
}

- (UIView *)separatorView{
    
    UIView *separatorView = [[UIView alloc] initWithFrame: (CGRect){.size = CGSizeMake(self.bounds.size.width, SEPARATOR_VIEW_HEIGHT)}];
    separatorView.backgroundColor = self.separatorColor;
    return separatorView;
}

- (UIView *)borderView{
	
	UIView *borderView = [[UIView alloc] initWithFrame: (CGRect){.size = CGSizeMake(BOARDER_VIEW_WIDTH, self.bounds.size.height+1)}];
	borderView.backgroundColor = self.borderColor;
	return borderView;
}

#pragma mark - Helpers

- (void)exchangeItem:(ADDropDownMenuItemView *)item withItem:(ADDropDownMenuItemView *)item2{
    
	CGRect itemRect = item.frame;
	item.frame = item2.frame;
	item2.frame = itemRect;
    
	[self.itemsViews exchangeObjectAtIndex:[self.itemsViews indexOfObject: item] withObjectAtIndex:[self.itemsViews indexOfObject: item2]];
	
	// End the method if the list should not keep the order of non selected items
	if (!self.orderedMenuList) return;
	NSUInteger idx = [self.itemsViews indexOfObject:item2];
	
	/* topItem: Assigned to the item with a decremented index. If that item is the selected
	 *			item (index 0 in the itemsViews array) then set it topItem nil
	 * 
	 * bottomItem: Assigned to the item with a incremented index. If that index is less than
	 *			   the last index set the bottomItem else set it nil
	 */
	ADDropDownMenuItemView *topItem = (idx>1) ? [self.itemsViews objectAtIndex:idx-1] : nil;
	ADDropDownMenuItemView *bottomItem = (idx<[self.itemsViews count]-1) ?
									[self.itemsViews objectAtIndex:idx+1] : nil;
	
	// Check to see if the swaped out item should be exchanged with its adjacent menu items
	// tag on the view is set to the item's original index in the itemsViews array
	if (bottomItem && bottomItem.tag<item2.tag) [self exchangeItem:bottomItem withItem:item2];
	else if(topItem && topItem.tag>item2.tag) [self exchangeItem:topItem withItem:item2];
}

- (void)highlightItem:(ADDropDownMenuItemView *)item{
    
    [self.itemsViews enumerateObjectsUsingBlock:^(ADDropDownMenuItemView *obj, NSUInteger idx, BOOL *stop) {
        if(obj == item){
            obj.state = ADDropDownMenuItemViewStateHighlighted;
        }
        else{
            obj.state = ADDropDownMenuItemViewStateNormal;
        }
    }];
}

- (void)selectItem:(ADDropDownMenuItemView *)item{
    
    [self.itemsViews enumerateObjectsUsingBlock:^(ADDropDownMenuItemView *obj, NSUInteger idx, BOOL *stop) {
        if(obj == item){
            obj.state = ADDropDownMenuItemViewStateSelected;
        }
        else{
            obj.state = ADDropDownMenuItemViewStateNormal;
        }
    }];
}

+ (CGFloat)contractedHeightForItemsViews:(NSArray *)itemsViews{
    ADDropDownMenuView *item = [itemsViews firstObject];
    return item.frame.size.height;
}

+ (CGFloat)expandedHeightForItemsViews:(NSArray *)itemsViews{
    NSUInteger itemsCount = itemsViews.count;
    ADDropDownMenuView *someItem = [itemsViews firstObject];
    return itemsCount * someItem.frame.size.height + SEPARATOR_VIEW_HEIGHT * MAX(itemsCount - 1, 0);
}

+ (CGFloat)expandedHeightForItemsViews:(NSArray *)itemsViews withRange:(NSRange)range {
	
}

- (void)expand{
	
	// Don't run the method if it's already open.
	if (self.isOpen) return;
    
    self.isAnimating = YES;
    CGRect expandedFrame = (CGRect){.origin = self.containerView.frame.origin,
        .size = CGSizeMake(self.containerView.frame.size.width, [ADDropDownMenuView expandedHeightForItemsViews: self.itemsViews])};
    
    if([self.delegate respondsToSelector:@selector(ADDropDownMenu:willExpandToRect:)]){
        [self.delegate ADDropDownMenu:self willExpandToRect:expandedFrame];
    }
    
    self.frame = (CGRect){.origin = self.frame.origin, .size = CGSizeMake(self.frame.size.width, [UIScreen mainScreen].applicationFrame.size.height)};
    [UIView animateWithDuration:self.menuAnimationDuration animations:^{
        if (!self.disableDimView) self.dimView.alpha = 0.4;
        self.containerView.frame = expandedFrame;
    } completion:^(BOOL finished) {
        self.isAnimating = NO;
    }];
    
    self.isOpen = YES;
}

- (void)contract{
    
	// Don't run the method if it's already closed
	if (!self.isOpen) return;
	
    self.isAnimating = YES;
    CGRect contractedFrame = (CGRect){.origin = self.containerView.frame.origin,
        .size = CGSizeMake(self.containerView.frame.size.width, [ADDropDownMenuView contractedHeightForItemsViews: self.itemsViews])};
    
    if([self.delegate respondsToSelector:@selector(ADDropDownMenu:willContractToRect:)]){
        [self.delegate ADDropDownMenu:self willContractToRect:contractedFrame];
    }
    
    self.frame = (CGRect){.origin = self.frame.origin, .size = CGSizeMake(self.frame.size.width, [ADDropDownMenuView contractedHeightForItemsViews: self.itemsViews])};
    [UIView animateWithDuration:self.menuAnimationDuration animations:^{
        if (!self.disableDimView) self.dimView.alpha = 0.;
        self.containerView.frame = contractedFrame;
    } completion:^(BOOL finished) {
        self.isAnimating = NO;
    }];
    
    self.isOpen = NO;
}

- (void)setSelectedAtIndex:(NSInteger)index {
    ADDropDownMenuItemView *itemView = self.initialItems[index];
	self.shouldContractOnTouchesEnd = NO;
	[self selectItem: itemView];
	[self exchangeItem: itemView withItem:[self.itemsViews firstObject]];
	if([self.delegate respondsToSelector:@selector(ADDropDownMenu:didSelectItem:)]){
		[self.delegate ADDropDownMenu:self didSelectItem:itemView];
	}
	[self contract];
}

- (void)offsetBorderStart:(NSUInteger)offset {
	NSAssert(offset<[self.itemsViews count]-1, @"Border offset cannot be greater than or equal to the number of items");
	
	NSUInteger length = 3 + 2 * (offset-1);
	NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, length)];
	[[self.borders objectsAtIndexes:idxSet] enumerateObjectsUsingBlock:^(UIView *border, NSUInteger idx, BOOL *stop) {
		[border removeFromSuperview];
	}];
	[self.borders removeObjectsAtIndexes:idxSet];
	
	// Setup the new top border
	UIView *topBorder = [self separatorView];
	[self.borders addObject:topBorder];
	
	ADDropDownMenuView *someItem = [self.itemsViews firstObject];
	CGFloat borderTopY = offset * someItem.frame.size.height + SEPARATOR_VIEW_HEIGHT * MAX(offset - 1, 0);
	topBorder.frame = (CGRect){.origin = CGPointMake(0, borderTopY), .size = topBorder.frame.size};
	topBorder.layer.zPosition = MAXFLOAT;

	[self.containerView addSubview:topBorder];
	
}

@end
