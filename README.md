# iOS-GPUImage-plus 
GPU accelerated filters for iOS based on OpenGL. 

## 简介 ##

1. 目前只是放了个demo以及framework(cge.framework, 支持armv7 armv7s arm64 i386 x86_64)，不包含核心代码

2. 不定期更新静态库文件以及demo

3. For study only, and no free tech support by now.

## 展示 ##

![iOS-GPUImage-plus](https://raw.githubusercontent.com/wysaid/ios-gpuimage-plus/master/screenshots/0.jpg "iOS-GPUImage-plus")
<br>demo主界面

![iOS-GPUImage-plus](https://raw.githubusercontent.com/wysaid/ios-gpuimage-plus/master/screenshots/1.jpg "iOS-GPUImage-plus")
<br>图片滤镜

![iOS-GPUImage-plus](https://raw.githubusercontent.com/wysaid/ios-gpuimage-plus/master/screenshots/2.jpg "iOS-GPUImage-plus")
<br>相机实时滤镜 (支持带声音录像)

![iOS-GPUImage-plus](https://raw.githubusercontent.com/wysaid/ios-gpuimage-plus/master/screenshots/3.jpg "iOS-GPUImage-plus")
<br>视频播放实时滤镜

## 文档 ##

本lib使用简单， 滤镜自定义可以全部通过纯文本配置来完成。 (目前不提供编辑器)

文本解析器的目的是让完全不懂GLSL甚至编程的人也知道如何快速添加新的特效。

EffectString解析规则和常用方法说明:

1. 每一步不同的处理均以'@'开头，后面跟处理方式。中间可以有空格或者没有
例: "@ method" 或者 "@method" 均为正确格式。method后面可以跟任意个字符，以空格隔开。
method后面的所有字符(直到下一个"@"符号或者字符串结束)将作为参数传递给该method对应的Parser.

2. curve方法参数解释： @curve方法格式为 "@curve &lt;arg1&gt; &lt;arg2&gt; ... &lt;argN&gt;"
&lt;argN&gt; 的格式有两种： "RGB (x1,y1) (xn, yn)", xn和yn分别表示0~255之间的数字
或者 "R (rx1,ry1) ... (rxn, ryn) G (gx1,gy1) ... (gxn,gyn) B (bx1,by1)...(bxn,byn)"
其中R，G，B分别表示对应通道，后面跟的点即为该通道下的点。
括号与参数之间可以有空格也可以没有。括号中的x与y之间可以使用任意间隔符如空格，逗号等.

例： 
曲线A: RGB 通道调整点为 (0, 0) (100, 200) (255, 255)
格式： "@curve RGB(0,0) (100, 200) (255, 255)"

曲线B: R通道(0, 0) (50, 25) (255, 255),
G通道(0, 0) (100, 150) (255, 255),
RGB通道(0, 0) (200, 150) (255, 255)
格式： "@curve R(0,0) (50, 25) (255, 255) G(0, 0) (100,150) (255, 255) RGB(0, 0) (200, 150) (255, 255)". PS(WangYang):为了简化我们的工作，我编写了曲线格式生成工具。请到tool目录下获取。

注： 当有连续多次curve调整时，可只写一次"@curve"，以上面的例子为例，如果曲线A，B中间没有其他操作，那么可以将A，B连接为一条curve指令，这将节省开销加快程序执行速度。
例: "@curve RGB(0,0) (100, 200) (255, 255) R(0,0) (50, 25) (255, 255) G(0, 0) (100,150) (255, 255) RGB(0, 0) (200, 150) (255, 255)" (与上例先后执行曲线A，曲线B结果相同)

3. blend方法参数解释： @blend方法格式为 "@blend &lt;function&gt; &lt;texture&gt; &lt;intensity&gt;"
&lt;function&gt;值目前有

正常: mix
溶解: dissolve[dsv]

变暗:     darken[dk]
正片叠底: multiply[mp]
颜色加深: colorburn[cb]
线性加深: linearburn[lb]
深色:     darkercolor[dc]

变亮:     lighten[lt]
滤色:     screen[sr]
颜色减淡: colordodge[cd]
线性减淡: lineardodge[ld]
浅色:     lightercolor[lc]

叠加:     overlay[ol]
柔光:     softlight[sl]
强光:     hardlight[hl]
亮光:     vividlight[vvl]
线性光:   linearlight[ll]
点光:     pinlight[pl]
实色混合: hardmix[hm]

差值:     difference[dif]
排除:     exclude[ec]
减去:     subtract[sub]
划分:     divide[div]

色相:     hue
饱和度:   saturation[sat]
颜色:     color[cl]
明度:     luminosity[lum]

相加:     add
反向加:   addrev
黑白:     colorbw  //此方法仅依据texture的alpha通道将src color置换为黑白.

注: [] 中的表示该值的缩写，可以使用缩写代替原本过长的参数值。

&lt;texture&gt; 参数表示所用到的资源文件名，包含后缀! 

&lt;intensity&gt;表示叠加强度(不透明度)，为(0, 100] 之间的整数。

例：使用资源图 src.jpg 进行叠加，强度为80%
格式： "@blend overlay src.jpg 80" 或者 "@blend ol src.jpg 80"

4. krblend方法参数解释： @krblend方法格式与blend方法一样。参见@blend方法。
 另, krblend所有参数以及用法均与blend方法一致。区别在于krblend方法进行纹理处理时，
 将固定纹理的比例以及对纹理进行等比例缩放以使最终覆盖全图。

5. pixblend方法参数解释： @pixblend方法格式为 "@pixblend &lt;function&gt; &lt;color&gt; &lt;intensity&gt;"
&lt;function&gt;参数与blend方法相同，请直接参考blend方法。
&lt;intensity&gt;参数含义与blend方法相同，请直接参考blend方法。
&lt;color&gt;参数包含四个浮点数，分别表示这个颜色的r,g,b,a，取值范围为 [0, 1] 或者 [0, 255]
例: 使用纯红色进行叠加，强度为90%
格式： "@pixblend overlay 1 0 0 0 90"  -->注意，中间的颜色值可以写为小数。当alpha值大于1时，所有颜色参数值域范围将被认为是[0, 255] 否则被认为是[0, 1]

6. selfblend方法参数解释： @selfblend方法格式为 "@selfblend &lt;function&gt; &lt;intensity&gt;"
注： 此方法中对应的参数与blend方法相同，区别在于没有&lt;texture&gt;参数。本方法将使用待处理图片自身颜色进行混合。

7. adjust方法参数解释： @adjust方法格式为 "@adjust &lt;function&gt; &lt;arg1&gt;...&lt;argN&gt;"
&lt;function&gt;值目前有
brightness (亮度): 后接一个参数 intensity, 范围 [-1, 1]

contrast (对比度): 后接一个参数 intensity, 范围 intensity > 0, 当 intensity = 0 时为灰色图像, intensity = 1 时为无效果, intensity > 1 时加强对比度.

saturation (饱和度): 后接一个参数 intensity, 范围 intensity > 0, 当 intensity = 0 时为黑白图像, intensity = 1 时为无效果， intensity > 1 时加强饱和度

monochrome (黑白): 后接六个参数, 范围 [-2, 3], 与photoshop一致。参数顺序分别为: red, green, blue, cyan, magenta, yellow

sharpen (锐化): 后接一个参数 intensity, 范围 [0, 10], 当intensity为0时无效果
blur (模糊): 后接一个参数 intensity, 范围 [0, 1], 当 intensity 为0时无效果

whitebalance (白平衡): 后接两个参数 temperature (范围：[-1, 1], 0为无效果) 和 tint (范围: [0, 5], 1 为无效果)

shadowhighlight[shl] (阴影&高光): 后接两个参数 shadow(范围: [-200, 100], 0为无效果) 和 highlight(范围: [-100, 200], 0为无效果)

hsv : 后接六个参数red, green, blue, magenta, yellow, cyan. 六个参数范围均为 [-1, 1]
hsl : 后接三个参数hue, saturation, luminance， 三个参数范围均为 [-1, 1]

level (色阶): 后接三个参数 dark, light, gamma, 范围均为[0, 1], 其中 dark < light

exposure (曝光) : 后接一个参数 intensity, 范围 [-10, 10]

colorbalance (色彩平衡): 后接三个参数 redShift [-1, 1], greenShift [-1, 1], blueShift [-1, 1]. (添加日期: 2015-3-30)

注: [] 中的表示该值的缩写，可以使用缩写代替原本过长的参数值。
&lt;arg*&gt; 表示该方法所需的参数，具体范围请参考相关class。 &lt;arg*&gt;的个数与具体&lt;function&gt;有关，

8. cvlomo方法参数解释： @cvlomo方法包含了子方法curve。格式 "@cvlomo &lt;vignetteStart&gt; &lt;vignetteEnd&gt; &lt;colorScaleLow&gt; &lt;colorScaleRange&gt; &lt;saturation&gt; &lt;curve&gt;"
&lt;vignetteStart&gt;和&lt;vignetteEnd&gt;均为大于0的小数，一般小于1。
&lt;colorScaleLow&gt; &lt;colorScaleRange&gt; 均为大于0的小数，一般小于1。 用于调整图像
&lt;saturation&gt; 0~1之间的小数， 设置图像饱和度。
参数&lt;curve&gt; 为一个完整的curve方法，但是不添加@curve 标记。
例： "@cvlomo 0.2 0.8 0.1 0.2 1 RGB(0, 0) (255, 255)"

9. colorscale方法参数解释: @colorscale方法格式为 "@colorscale &lt;low&gt; &lt;range&gt; &lt;saturation&gt;"
注: colorscale方法需要进行CPU计算，较影响速度。

10. vignette 方法参数解释： @vignette方法格式为 "@vignette &lt;low&gt; &lt;range&gt; &lt;centerX&gt; &lt;centerY&gt;
注: 其中low和range是必须选项，centerX和centerY是可选项，若不填，则默认为0.5。 centerX和centerY必须同时存在才生效。
例： "@vignette 0.1 0.9" , "@vignette 0.1 0.9 0.5 0.5" 

11. colormul 方法参数解释： @colormul方法格式为 "@colormul &lt;function&gt; &lt;arg1&gt; ...&lt;argN&gt;"
参数&lt;function&gt;值目前有 "flt", "vec" 和 "mat"。
当&lt;function&gt;为flt时， 后面跟一个参数 &lt;arg&gt;，将对所有像素执行乘法.
当&lt;function&gt;为vec时，后面跟三个参数&lt;arg1&gt; &lt;arg2&gt; &lt;arg3&gt;，将对所有像素分别执行rgb分量各自相乘。
当&lt;function&gt;为mat时，后面跟九个参数&lt;arg1&gt;...&lt;argN&gt;，将对所有像素分别执行矩阵的rgb分量进行矩阵乘法。

12. special方法参数解释: @special方法格式为 "@special &lt;N&gt;"
其中参数&lt;N&gt; 为该特效的编号。
此类用于处理所有不具备通用性的特效。直接重新编写一个processor以解决。

13. lomo方法参数解释：格式 "@lomo &lt;vignetteStart&gt; &lt;vignetteEnd&gt; &lt;colorScaleLow&gt; &lt;colorScaleRange&gt; &lt;saturation&gt; &lt;isLinear&gt;"
&lt;vignetteStart&gt;和&lt;vignetteEnd&gt;均为大于0的小数，一般小于1。
&lt;colorScaleLow&gt; &lt;colorScaleRange&gt; 均为大于0的小数，一般小于1。 用于调整图像
&lt;saturation&gt; 0~1之间的小数， 设置图像饱和度。
&lt;isLinear&gt; 0或1， 设置所使用的vignette方法是否为线性增长，不写此参数则默认为0
例： "@lomo 0.2 0.8 0.1 0.2 1 0"

======编号13 以前使用到的特效依赖库版本： 0.2.1.x =========

14. vigblend 方法参数解释: @vigblend方法格式为 "@vigblend &lt;function&gt; &lt;color&gt; &lt;intensity&gt; &lt;low&gt; &lt;range&gt; &lt;centerX&gt; &lt;centerY&gt; [kind]"
[isLinear] 参数为可选参数, 默认为0
0: 线性增强，vignette本身不包含alpha通道（alpha通道为1）
1: 线性增强，vignette本身以alpha通道形成渐变
2: 二次增强，vignette本身不包含alpha通道（alpha通道为1）
3: 二次增强，vignette本身以alpha通道形成渐变
例："@vigblend ol 0 0 0 1 50 0.02 0.45 0.5 0.5 0"
	"@vigblend mix 10 10 30 255 100 0 1.5 0.5 0.5 0",
	"@vigblend mix 10 10 30 255 100 0 1.5 0.5 0.5 1",
	"@vigblend mix 10 10 30 255 100 0 1.5 0.5 0.5 2",
	"@vigblend mix 10 10 30 255 100 0 1.5 0.5 0.5 3",
注：其他参数含义以及用法参考 pixblend 方法以及 vignette 方法。


======↑此注释以上编号使用的特效库依赖版本 0.3.2.1

15. selcolor (selective color) 方法参数解释: @selcolor方法格式："@selcolor &lt;color1&gt; &lt;colorargs1&gt; ...&lt;colorN&gt; &lt;colorargsN&gt;"
其中&lt;colorN&gt;为选择的颜色， 有效参数包括：
red, green, blue, cyan, magenta, yellow, white, gray, black.

&lt;colorargsN&gt; 为对选择颜色所做出的调整， 格式为
(cyan, magenta, yellow, key)   范围： [-1, 1]
每一个&lt;colorargsN&gt; 为使用括号括起来的四个参数， 如果该参数未作调整， 则写0

======↑新增加 2014-11-12

16. style 方法参数解释: @style 方法格式为 "@style &lt;function&gt; &lt;arg1&gt; ... &lt;argN&gt;"
&lt;function&gt;值目前有

crosshatch (交叉阴影): 后接两个参数 spacing 范围[0, 0.1] 和 lineWidth 范围(0, 0.01]

edge (sobel查找边缘): 后接两个参数 mix 范围[0, 1] 和 stride 范围(0, 5]

emboss (浮雕): 后接三个参数 mix 范围[0, 1], stride 范围[1, 5] 和 angle 范围[0, 2π]

halftone (半调): 后接一个参数 dotSize 范围 >= 1

haze (雾): 后接三个参数 distance 范围[-0.5, 0.5], slope 范围 [-0.5, 0.5] 和 color (参数 color包含三个分量， 分别表示r, g, b， 范围均为[0, 1] )

polkadot (圆点花样): 后接一个参数 dotScaling 范围 (0, 1]

sketch (素描): 后接一个参数 intensity [0, 1]

max (最大值) 暂无参数

min (最小值) 暂无参数

mid (中值) 暂无参数

======↑新增加 2015-2-5

17. beautify 方法参数解释: @beautify 方法格式为 "@beautify &lt;function&gt; &lt;arg1&gt;...&lt;argN&gt;"

&lt;function&gt;值 目前有

bilateral (双边滤波): 后接 三个参数 模糊半径(blurScale) 范围[-100, 100], 色彩容差(distanceFactor) 范围[1, 20] 和 重复次数(repeat times) 范围 >= 1
                      其中 重复次数为可选参数， 如果不填， 则默认为 1

======↑新增加 2015-3-19

18. 新增功能性方法 unpack, 使用方式为 在整个配置的开头加入 #unpack
   作用： 将去除MultipleEffects包装， 直接把解析出来的所有特效直接加入整个handler.

======↑新增加 2015-8-7

19. blur 方法参数解释
   新增以 @blur 方法， 专门提供各类模糊算法, 格式: "@blur &lt;function&gt; &lt;arg1&gt; ... &lt;argN&gt;"

&lt;function&gt;值目前有

lerp (lerp blur): 后接两个个参数 模糊级别[0, 1], 模糊基数 [0.6, 2.0]



