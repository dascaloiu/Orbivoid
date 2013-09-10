//
//  ORBMyScene.m
//  Orbivoid
//
//  Created by Joachim Bengtsson on 2013-08-27.
//  Copyright (c) 2013 Neto. All rights reserved.
//

#import "ORBGameScene.h"
#import "ORBMenuScene.h"
#import "CGVector+TC.h"
#import "SKEmitterNode+fromFile.h"
#import "ORBCharacterNode.h"

enum {
    CollisionPlayer = 1<<1,
    CollisionEnemy = 1<<2,
};


@interface ORBGameScene () <SKPhysicsContactDelegate>
@end

@implementation ORBGameScene
{
    ORBCharacterNode *_player;
    NSMutableArray *_enemies;
    BOOL _dead;
    SKLabelNode *_scoreLabel;
}

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
        
        self.backgroundColor = [SKColor blackColor];
        
        self.physicsWorld.gravity = CGPointMake(0, 0);
        self.physicsWorld.contactDelegate = self;
        self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
        
        _enemies = [NSMutableArray new];
        
        _player = [[ORBCharacterNode alloc] initWithSize:CGSizeMake(10, 10)];
            _player.physicsBody.mass = 100000;
            _player.physicsBody.categoryBitMask = CollisionPlayer;
            _player.physicsBody.contactTestBitMask = CollisionEnemy;
            _player.position = CGPointMake(size.width/2, size.height/2);
        
        SKEmitterNode *background = [SKEmitterNode orb_emitterNamed:@"Background"];
            background.particlePositionRange = CGVectorMake(self.size.width*2, self.size.height*2);
            [background advanceSimulationTime:10];
        
        [self addChild:background];
        [self addChild:_player];
        [_player didMoveToParent];
        
        [self updateScoreLabel];
    }
    return self;
}

- (void)didMoveToView:(SKView *)view
{
        [self runAction:[SKAction group:@[
/*            [SKAction spawnPlayer] => spawn animation, then add player to world,*/
        ]]];
    [self performSelector:@selector(spawnEnemy) withObject:nil afterDelay:1.0];
}

- (void)spawnEnemy
{
    if(_dead)
        return;
    
    ORBCharacterNode *enemy = [[ORBCharacterNode alloc] initWithSize:CGSizeMake(6, 6)];
        enemy.trail.particleColorSequence = [[SKKeyframeSequence alloc] initWithKeyframeValues:@[
            [SKColor redColor],
            [SKColor colorWithHue:0.1 saturation:.5 brightness:1 alpha:1],
            [SKColor redColor],
        ] times:@[@0, @0.02, @0.2]];
        enemy.trail.particleScale /= 2;
    
        enemy.position = [self randomEnemyPosition];
        enemy.physicsBody.categoryBitMask = CollisionEnemy;
    
    [_enemies addObject:enemy];
    [self addChild:enemy];
    [enemy didMoveToParent];
    
    [self updateScoreLabel];
    
    [self runAction:[SKAction playSoundFileNamed:@"Spawn.wav" waitForCompletion:NO]];
    
    // Next spawn
    [self runAction:[SKAction sequence:@[
        [SKAction waitForDuration:2],
        [SKAction performSelector:@selector(spawnEnemy) onTarget:self],
    ]]];
}

- (CGPoint)randomEnemyPosition
{
    // Spawn next to the player
    CGPoint position = _player.position;
    
    // Offset
    float maxOffset = 100;
//    float minOffset = 20;
    position.x += arc4random_uniform(maxOffset*2)-maxOffset;
    position.y += arc4random_uniform(maxOffset*2)-maxOffset;
    
    NSLog(@"Position x: %f   y: %f", position.x, position.y);

    // Spawn within the frame
    position.x = MAX(0, position.x);
    position.x = MIN(self.frame.size.width, position.x);
    
    position.y = MAX(0, position.x);
    position.y = MIN(self.frame.size.width, position.x);
    
    return position;
}

- (void)updateScoreLabel
{
    if(!_scoreLabel) {
        _scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"Courier-Bold"];
        
        _scoreLabel.fontSize = 200;
        _scoreLabel.position = CGPointMake(CGRectGetMidX(self.frame),
                                       CGRectGetMidY(self.frame));
        _scoreLabel.fontColor = [SKColor colorWithHue:0 saturation:0 brightness:1 alpha:0.3];
        [self addChild:_scoreLabel];
    }
    _scoreLabel.text = [NSString stringWithFormat:@"%02d", _enemies.count];
}

- (void)dieFrom:(SKNode*)killingEnemy
{
    _dead = YES;
    
    SKEmitterNode *explosion = [SKEmitterNode orb_emitterNamed:@"Explosion"];
    explosion.position = _player.position;
    [self addChild:explosion];
    [explosion runAction:[SKAction sequence:@[
        [SKAction playSoundFileNamed:@"Explosion.wav" waitForCompletion:NO],
		[SKAction waitForDuration:0.4],
        [SKAction runBlock:^{
            // TODO: Remove these more nicely
            [killingEnemy removeFromParent];
            [_player removeFromParent];
        }],
		[SKAction waitForDuration:0.4],
		[SKAction runBlock:^{
			explosion.particleBirthRate = 0;
		}],
		[SKAction waitForDuration:1.2],
        
        [SKAction runBlock:^{
            ORBMenuScene *menu = [[ORBMenuScene alloc] initWithSize:self.size];
            [self.view presentScene:menu transition:[SKTransition doorsCloseHorizontalWithDuration:0.5]];
        }],
	]]];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_dead)
        return;
    
    [_player runAction:[SKAction moveTo:[[touches anyObject] locationInNode:self] duration:0.01]];
}

-(void)update:(CFTimeInterval)currentTime
{
    
    CGPoint playerPos = _player.position;
    
    for(ORBCharacterNode *enemyNode in _enemies) {
        CGPoint enemyPos = enemyNode.position;
        
        /* Uniform speed: */
        CGVector diff = TCVectorMinus(playerPos, enemyPos);
        CGVector normalized = TCVectorUnit(diff);
        CGVector force = TCVectorMultiply(normalized, 1.9);
        
        /* Inversely proportional:
        CGVector diff = TCVectorMinus(playerPos, enemyPos);
        CGVector normalized = TCVectorUnit(diff);
        CGVector force = TCVectorMultiply(normalized, 1/sqrt(TCVectorLength(diff))*40);
        */
        
        /* Inverse square root
        CGVector diff = TCVectorMinus(playerPos, enemyPos);
        CGVector normalized = TCVectorUnit(diff);
        CGVector force = TCVectorMultiply(normalized, 1/sqrt(TCVectorLength(diff))*40);
        */
        
        [enemyNode.physicsBody applyForce:force];
//        [enemyNode pointToPlayer:_player];
    }
    
    _player.physicsBody.velocity = CGVectorMake(0, 0);
}

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    if(_dead)
        return;
    
    [self dieFrom:contact.bodyB.node];
    contact.bodyB.node.physicsBody = nil;
}

@end
