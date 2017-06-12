/*
 * cgeAnimationParser.mm
 *
 *  Created on: 2016-5-16
 *      Author: Wang Yang
 *        Mail: admin@wysaid.org
 */

#ifndef _CGE_ONLY_FILTERS_

#include "cgeAnimationParser.h"
#include "cgeSlideshow.h"
#include "cgeUtilFunctions.h"
#include <vector>

namespace CGE
{
    static CGETextureInfo sGetTextureByConfig(id config)
    {
        id _img = [config objectForKey:@"image"];
        NSError* err = nil;
        CGETextureInfo info = {0};
        
        if(_img && [_img isKindOfClass:UIImage.class])
        {
            UIImage* img = (UIImage*)_img;
            info.name = cgeCGImage2Texture(img.CGImage, nullptr);
            info.width = (int)CGImageGetWidth(img.CGImage);
            info.height = (int)CGImageGetHeight(img.CGImage);
        }
        else
        {
            id _imgFile = [config objectForKey:@"imageFile"];
            if(_imgFile && [_imgFile isKindOfClass:NSString.class])
            {
                info = cgeLoadTextureByPath(_imgFile);
            }
        }
        
        if(err)
        {
            CGE_NSLog(@"Create Slideshow Texture Failed: %@", err);
        }
        
        return info;
    }
    
    static Vec2f sGetSpriteDuringByConfig(id config)
    {
        id _during = [config objectForKey:@"during"];
        if(_during && [_during isKindOfClass:NSArray.class])
        {
            NSArray* arr = _during;
            if(arr.count >= 2)
            {
                return Vec2f([[arr objectAtIndex:0] floatValue], [[arr objectAtIndex:1] floatValue]);
            }
        }
        
        CGE_NSLog(@"Invalid During config !");
        return Vec2f(-1.0f, -1.0f);
    }
    
    template<class SpriteType>
    static inline TimeActionInterface<SpriteType>* createUniformAlphaActionByConfig(id config)
    {
        id params = [config objectForKey:@"params"];
        
        if(params && [params isKindOfClass:NSArray.class])
        {
            NSArray* arr = params;
            if(arr.count < 4)
                return nullptr;
            
            float startTime = [arr[0] floatValue];
            float endTime = [arr[1] floatValue];
            float alphaFrom = [arr[2] floatValue];
            float alphaTo = [arr[3] floatValue];
            float repeatTimes = arr.count >= 5 ? [arr[4] floatValue] : 1;
            bool shouldInit = arr.count == 6 ? [arr[5] boolValue] : true;
            
            auto* action = new UniformAlphaAction<SpriteType>(startTime, endTime, alphaFrom, alphaTo, repeatTimes, shouldInit);
            return action;
        }
        return nullptr;
    }
    
    template<class SpriteType>
    static inline TimeActionInterface<SpriteType>* createUniformRotateActionByConfig(id config)
    {
        id params = [config objectForKey:@"params"];
        
        if(params && [params isKindOfClass:NSArray.class])
        {
            NSArray* arr = params;
            if(arr.count < 4)
                return nullptr;
            
            float startTime = [arr[0] floatValue];
            float endTime = [arr[1] floatValue];
            float rotFrom = [arr[2] floatValue];
            float rotTo = [arr[3] floatValue];
            float repeatTimes = arr.count == 5 ? [arr[4] floatValue] : 1;
            
            auto* action = new UniformRotateAction<SpriteType>(startTime, endTime, rotFrom, rotTo, repeatTimes);
            return action;
        }
        return nullptr;
    }
    
    template<class SpriteType>
    static inline TimeActionInterface<SpriteType>* createUniformScaleActionByConfig(id config)
    {
        id params = [config objectForKey:@"params"];
        
        if(params && [params isKindOfClass:NSArray.class])
        {
            NSArray* arr = params;
            if(arr.count < 4)
                return nullptr;
            
            float startTime = [arr[0] floatValue];
            float endTime = [arr[1] floatValue];
            float scaleFrom = [arr[2] floatValue];
            float scaleTo = [arr[3] floatValue];
            float repeatTimes = arr.count == 5 ? [arr[4] floatValue] : 1;
            
            auto* action = new UniformScaleAction<SpriteType>(startTime, endTime, scaleFrom, scaleTo, repeatTimes);
            return action;
        }
        return nullptr;
    }
    
    template<class SpriteType>
    static inline void sSetSpriteAction(SpriteType* sprite, id config)
    {
        id name = [config objectForKey:@"name"];
        
        if(name && [name isKindOfClass:NSString.class])
        {
            name = [name lowercaseString];
            
            if([name isEqualToString:@"uniformalpha"])
            {
                auto* action = createUniformAlphaActionByConfig<SpriteType>(config);
                sprite->pushAction(action);
            }
            else if([name isEqualToString:@"uniformrotation"])
            {
                auto* action = createUniformRotateActionByConfig<SpriteType>(config);
                sprite->pushAction(action);
            }
            else if([name isEqualToString:@"uniformscale"])
            {
                auto* action = createUniformScaleActionByConfig<SpriteType>(config);
                sprite->pushAction(action);
            }
        }
        
    }
    
    template<class SpriteType>
    static inline void sSetSpritePos(SpriteType* sprite, id config)
    {
        id pos = [config objectForKey:@"pos"];
        if(pos && [pos isKindOfClass:NSArray.class])
        {
            sprite->moveTo([[pos objectAtIndex:0] floatValue], [[pos objectAtIndex:1] floatValue]);
        }
        else
        {
            pos = [config objectForKey:@"posRelative"];
            if(pos && [pos isKindOfClass:NSArray.class])
            {
                sprite->moveTo([[pos objectAtIndex:0] floatValue] * SpriteType::sCanvasSize.width, [[pos objectAtIndex:1] floatValue] * SpriteType::sCanvasSize.height);
            }
        }
    }
    
    template<class SpriteType>
    static inline void sSetSpriteScaling(SpriteType* sprite, id config)
    {
        id scaling = [config objectForKey:@"scaling"];
        if(scaling && [scaling isKindOfClass:NSArray.class])
        {
            sprite->scaleTo([[scaling objectAtIndex:0] floatValue], [[scaling objectAtIndex:1] floatValue]);
        }
    }
    
    template<class SpriteType>
    static inline void sSetSpriteHotspot(SpriteType* sprite, id config)
    {
        id hotspot = [config objectForKey:@"hotspot"];
        if(hotspot && [hotspot isKindOfClass:NSArray.class])
        {
            sprite->setHotspot([[hotspot objectAtIndex:0] floatValue], [[hotspot objectAtIndex:1] floatValue]);
        }
    }
    
    template<class SpriteType>
    static inline void sSetSpriteRotation(SpriteType* sprite, id config)
    {
        id rotation = [config objectForKey:@"rotation"];
        if(rotation)
        {
            sprite->rotateTo([rotation floatValue]);
        }
    }
    
    template<class SpriteType>
    static inline void sSetSpriteCommonAttribute(SpriteType* sprite, id config)
    {
        id rect = [config objectForKey:@"rect"];
        if(rect && [rect isKindOfClass:NSArray.class])
        {
            if([rect count] < 3)
            {
                return ;
            }
            
            float x = [rect[0] floatValue];
            float y = [rect[1] floatValue];
            float w = [rect[2] floatValue];
            
            float spriteWidth = sprite->getTexture().width;
            float spriteHeight = sprite->getTexture().height;
            
            float moveX, moveY;
            float scaleX, scaleY;
            
            float configWidth = Sprite2d::sCanvasSize.width * w;
            
            if([rect count] == 3)
            {
                scaleX = scaleY = configWidth / spriteWidth;
                moveX = x * Sprite2d::sCanvasSize.width;
                moveY = y * Sprite2d::sCanvasSize.height;
            }
            else
            {
                float h = [rect[3] floatValue];
                float configHeight = Sprite2d::sCanvasSize.height * h;
                scaleX = configWidth / spriteWidth;
                scaleY = configHeight / spriteHeight;
                moveX = x * Sprite2d::sCanvasSize.width + scaleX * spriteWidth / 2.0f;
                moveY = y * Sprite2d::sCanvasSize.height + scaleY * spriteHeight / 2.0f;
            }
            
            sprite->scaleTo(scaleX, scaleY);
            sprite->moveTo(moveX, moveY);
            
        }
        else
        {
            sSetSpritePos(sprite, config);
            sSetSpriteScaling(sprite, config);
            sSetSpriteHotspot(sprite, config);
            sSetSpriteRotation(sprite, config);
        }
    }
    
    static AnimLogicSprite2d* sCreateAnimSprite2dByConfig(id config, SharedTexture& sharedTexture)
    {
        auto&& during = sGetSpriteDuringByConfig(config);
        
        if(during[0] < 0.0f)
            return nullptr;
        
        AnimSprite2d* sprite = new AnimSprite2d(during[0], during[1], sharedTexture);
        
        sSetSpriteCommonAttribute(sprite, config);
        
        id actions = [config objectForKey:@"action"];
        
        if(actions && [actions isKindOfClass:NSArray.class])
        {
            for(id actionElem : actions)
            {
                sSetSpriteAction(sprite, actionElem);
            }
        }
        
        return sprite;
    }
    
    static std::vector<AnimLogicSprite2d*> sCreateSpriteByConfig(id config, SharedTexture& sharedTexture)
    {
        std::vector<AnimLogicSprite2d*> vec;
        
        for(id spriteConfig : config)
        {
            AnimLogicSprite2d* sp = nullptr;
            id name = [spriteConfig objectForKey:@"name"];
            if(name == nil)
            {
                continue;
            }
            
            name = [name lowercaseString];
            
            if([name isEqualToString:@"animsprite2d"])
            {
                sp = sCreateAnimSprite2dByConfig(spriteConfig, sharedTexture);
            }
            
            vec.push_back(sp);
        }
        
        return vec;
    }
    
    void* createSlideshowByConfig(id config, float totalTime)
    {
        if(!(config && [config isKindOfClass:NSArray.class]))
        {
            return nullptr;
        }
        
        CGE_NSLog(@"Creating slideshow by config: %@", config);
        
        TimeLine* timeline = new TimeLine();
        
        for(id elem : config)
        {
            CGETextureInfo info = sGetTextureByConfig(elem);
            if(info.name == 0)
            {
                continue;
            }
            
            SharedTexture sharedTexture(info.name, info.width, info.height);
            
            id sprites = [elem objectForKey:@"sprite"];
            
            if(sprites && [sprites isKindOfClass:NSArray.class])
            {
                auto&& vec = sCreateSpriteByConfig(sprites, sharedTexture);
                
                for(auto* s : vec)
                {
                    timeline->push(s);
                }
            }
        }
        
        timeline->setTotalTime(totalTime);
        
        if(timeline->timeObjects().empty())
        {
            CGE_NSLog(@"The timeline is empty!!!");
            delete timeline;
            timeline = nullptr;
        }
        
        return timeline;
    }
}

#endif














