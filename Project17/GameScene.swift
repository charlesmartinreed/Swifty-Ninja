//
//  GameScene.swift
//  Project17
//
//  Created by Charles Martin Reed on 8/23/18.
//  Copyright © 2018 Charles Martin Reed. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    //MARK:- PROPERTIES
    var gameScore: SKLabelNode!
    var score = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    var activeSlicePoints = [CGPoint]()
    
    var isSwooshSoundActive = false
    
    override func didMove(to view: SKView) {
        
        //creating and placing our background
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        //adding our physics. CGVector is used to set the intensity of the gravitational acceleration. Measured in meters per second.
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        //speed of less than 1 means that the movement happens at a slightly slower pace than default
        physicsWorld.speed = 0.85
        
        createScore()
        createLives()
        createSlices()
    }
    
    //MARK:- Game Initalization Methods
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.text = "Score: 0"
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
    }
    
    func createLives() {
        //we're using this up so that we can cross off lives when the player loses
        for i in 0..<3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        //swiping around the screen creates a glowing trail of slice marks that fade when you let go or keep moving - we'll use SKShapeNode
        //we need to track all player moves on the screen, recording an array of their swipe points
        //draw two slices shapes, white and yellow, to emulate a hot glow
        //use zPosition to place them higher than anything else
        
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 2
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    //MARK:- Touch functions
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //remove all points in activeSlicePoints array
        //get the touch location and add it to the activeSlicePoints array
        //call redrawActiveSlice, which will clear the slice shapes
        //remove any actions attached to the slice shapes
        //set both slice shapes to have an alpha of 1 so they are fully visible again
        
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        //if there's a touch event
        if let touch = touches.first {
            let location = touch.location(in: self)
            activeSlicePoints.append(location)
        
            redrawActiveSlice()
            
            activeSliceBG.removeAllActions()
            activeSliceFG.removeAllActions()
            activeSliceBG.alpha = 1
            activeSliceFG.alpha = 1
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //figure out where the user touched, add that location to the slice points array and redraw the slice shape
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        //playing our sound effect for the player's touch
        if isSwooshSoundActive == false {
            playSwooshSound()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //fades out the slice shapes over 0.25 seconds
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //happens when a system call (low battery, etc) interrupts a touch event. Just forwarding the event over to touchesEnded
        touchesEnded(touches, with: event)
    }
    
    //MARK:- Drawing our slices on screen using UIBezierPath
    
    func redrawActiveSlice() {
        
         //if we have fewer than two points in our array, we can't draw a line - clear the shapes and return
        if activeSlicePoints.count < 2 {
            
            //SKShapeNodes have a path property that describes the shape to draw. These accept CGPath values.
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        while activeSlicePoints.count > 12 {
            //if we have more than 12 slice points in our array, remove oldes ones until we have no more than 12 to keep the slice shapes manageable
            activeSlicePoints.remove(at: 0)
        }
        
        //start line at position of first swipe, draw lines to each additional point
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        
        for i in 1..<activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        
        //update the slice shape paths so they get drawn using the proper line width and color
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
    }
    
    func playSwooshSound() {
        isSwooshSoundActive = true
        
        let randomNumber = RandomInt(min: 1, max: 3)
        let soundName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        run(swooshSound) { [unowned self] in
            self.isSwooshSoundActive = false
        }
    }
    
    
   
    
    
  
}
