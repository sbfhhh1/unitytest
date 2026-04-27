# 屏幕深度纹理课件规划

## 课程定位

- 章节名称：屏幕深度纹理
- 所属位置：深度测试案例之后，PoolWater 水面案例之前
- 对应案例脚本：`Assets/ShaderCourse/Example/DepthTestURP/Shaders/ScreenDepthTexture_Debug.shader`
- 作用：先用护盾深度纹理案例讲透原理，再为后续 PoolWater 水面案例做铺垫

## 教学目标

- 让学生区分“深度缓冲”和“深度纹理”
- 解释为什么深度纹理不是线性距离，为什么要做线性化
- 解释屏幕坐标与 `SampleSceneDepth` 的关系
- 解释“场景深度 - 当前表面深度”为什么能驱动护盾交界发光、深度染色与空间厚度感
- 为后续 `DepthPool_Water_Demo.shader` 水面案例铺垫，不让知识跳跃过大

## 叙事结构

1. 从深度测试过渡到深度纹理
2. 什么是深度缓冲
3. 什么是深度纹理
4. 为什么深度值不是线性的
5. 为什么要做线性化
6. 屏幕坐标如何采样深度纹理
7. 深度差值如何变成视觉参数
8. 本节主案例：护盾深度纹理
9. 与 PoolWater 案例的衔接
10. 小结与练习

## 图例规划

- 使用现有本地参考图：
  - `Assets/ShaderCourse/Example/DepthTestURP/References/depth_curve.jpg`
  - `Assets/ShaderCourse/Example/DepthTestURP/References/frustum_transform.jpg`
  - `Assets/ShaderCourse/Example/DepthTestURP/References/water_depth_effect.jpg`
- 使用网络知识来源作为内容依据：
  - Unity Manual: Camera's Depth Texture
  - LearnOpenGL: Depth testing
- 关键流程图和算法图在 PPT 内重绘，保证风格统一、中文清晰

## 输出文件

- `Assets/ShaderCourse/Example/DepthTestURP/Unity Shader编程_屏幕深度纹理课件.pptx`
