# iOS-GPUImage-Plus 
GPU accelerated filters for iOS based on OpenGL. 

__New feature__: Face effects will be created with the ios11's `VNSequenceRequestHandler` & `VNDetectFaceLandmarksRequest`.

>Android version: [https://github.com/wysaid/android-gpuimage-plus](https://github.com/wysaid/android-gpuimage-plus "http://wysaid.org")

## Abstract ##

* This repo is open source now. You can use cge.framework in your project.

    1. You can add the cge.framework to your project, then add the code
    >#import <cge/cge.h>
    >//Everything is done.

    2. If you're using CocoaPods, add this to your Podfile:
    >pod 'cge', :git => 'https://github.com/wysaid/ios-gpuimage-plus.git'

    or with the latest static library:
    >pod 'cge', :git => 'https://github.com/wysaid/ios-gpuimage-plus-pod.git', :tag => '2.5.1'

    __Dependencies__:  libc++, ImageIO.framework, MobileCoreServices.framework

    Note: The filters are written in C++, so you should change your source file extensions to "mm" if you want use all features. But it is not necessary when you're using the interface-headers just like the [demo](https://github.com/wysaid/ios-gpuimage-plus/tree/master/demo/cgeDemo).

* Hundreds of built-in filters are available in the demo. 😋If you'd like to add your own filter, please take a look at the manual page. Or you can follow the demo code. The new custom filters should be written in C++.

* To build the source code, you can use the xcode project in the 'library' folder.

## Manual ##

### 1. Usage ###

___Sample Code for doing a filter with UIImage___
```
//Simply apply a filter to an UIImage.
- (void)viewDidLoad
{
    UIImage* srcImage = [UIImage imageNamed:@"test.jpg"];
    //HSL Adjust (hue: 0.02, saturation: -0.31, luminance: -0.17)
    //Please see the manual for more details.
    const char* ruleString = @"@adjust hsl 0.02 -0.31 -0.17";
    UIImage* resultImage = cgeFilterUIImage_MultipleEffects(srcImage, ruleString, 1.0f, nil);

    //Then the dstImage is applied with the filter.
    //It's so convenient, isn't it?
}
```

### 2. Custom Shader Filter ###

#### 2.1 Write your own filter ####
>Your filter must inherit [CGEImageFilterInterfaceAbstract](https://github.com/wysaid/ios-gpuimage-plus/blob/master/library/cge/include/cgeImageFilter.h#L39) or its child class. Most of the filters are inherited from [CGEImageFilterInterface](https://github.com/wysaid/ios-gpuimage-plus/blob/master/library/cge/include/cgeImageFilter.h#L54) because it has many useful functions.

```
// A simple customized filter to do a color reversal.
class MyCustomFilter : public CGE::CGEImageFilterInterface
{
public:
    
    bool init()
    {
        CGEConstString fragmentShaderString = CGE_SHADER_STRING_PRECISION_H
        (
        varying vec2 textureCoordinate;  //defined in 'g_vshDefaultWithoutTexCoord'
        uniform sampler2D inputImageTexture; // the same to above.

        void main()
        {
            vec4 src = texture2D(inputImageTexture, textureCoordinate);
            src.rgb = 1.0 - src.rgb;  //Simply reverse all channels.
            gl_FragColor = src;
        }
        );

        //m_program is defined in 'CGEImageFilterInterface'
        return m_program.initWithShaderStrings(g_vshDefaultWithoutTexCoord, s_fsh);
    }

    //void render2Texture(CGE::CGEImageHandlerInterface* handler, GLuint srcTexture, GLuint vertexBufferID)
    //{
    //  //Your own render functions here.
    //  //Do not override this function to use the CGEImageFilterInterface's.
    //}
};
```

>Note: To add your own shader filter with c++. [Please see the demo for further details](https://github.com/wysaid/ios-gpuimage-plus/blob/master/library/filterLib/CustomFilter_N.cpp).

#### 2.2 Run your own filter ####

Please see this: [https://github.com/wysaid/ios-gpuimage-plus/blob/master/library/filterLib/cgeCustomFilters.h#L34](https://github.com/wysaid/ios-gpuimage-plus/blob/master/library/filterLib/cgeCustomFilters.h#L34)

### 3. Filter Rule String ###

En: [https://github.com/wysaid/android-gpuimage-plus/wiki/Parsing-String-Rule-En](https://github.com/wysaid/android-gpuimage-plus/wiki/Parsing-String-Rule-En "http://wysaid.org")

Ch: [https://github.com/wysaid/android-gpuimage-plus/wiki/Parsing-String-Rule](https://github.com/wysaid/android-gpuimage-plus/wiki/Parsing-String-Rule "http://wysaid.org")

## Tool ##

Some utils are available for creating filters: [https://github.com/wysaid/cge-tools](https://github.com/wysaid/cge-tools "http://wysaid.org")

[![Tool](https://raw.githubusercontent.com/wysaid/cge-tools/master/screenshots/0.jpg "cge-tool")](https://github.com/wysaid/cge-tools)

## License ##

[MIT License](https://github.com/wysaid/ios-gpuimage-plus/blob/master/LICENSE)

## Donate ##

Alipay:

![Alipay](https://raw.githubusercontent.com/wysaid/ios-gpuimage-plus/master/screenshots/alipay.jpg "alipay")

Paypal: 

[![Paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif "Paypal")](http://blog.wysaid.org/p/donate.html)
