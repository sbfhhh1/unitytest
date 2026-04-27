## Audience

- 已学过渲染管线、基础光照、法线贴图、视差映射、PBR、模板测试的 Unity Shader 学生
- 需要从“屏幕区域筛选”继续理解“遮挡与先后关系”

## Objective

- 讲清深度缓冲、深度测试、ZWrite、ZTest、渲染队列之间的关系
- 用 URP 案例把理论落地到一个可演示的 PBR 深度测试 Shader
- 保持与前一章模板测试一致的课程风格与版式

## Narrative Arc

1. 回顾模板测试，过渡到深度测试
2. 建立深度缓冲与遮挡关系概念
3. 解释深度测试在渲染管线中的位置
4. 解释深度值非线性分布与近平面重要性
5. 讲清 ZTest / ZWrite / Queue 在工程中的联动
6. 用 URP PBR 案例 Shader 落地
7. 讲透明物体、排序和常见错误
8. 用练习巩固

## Slide List

1. 封面
2. 与上一章的关系
3. 深度缓冲是什么
4. 深度测试在管线中的位置
5. 深度值为什么不是线性的
6. ZTest、ZWrite 与 Queue
7. Opaque vs Transparent
8. URP 案例 Shader 结构
9. 案例效果与课堂实验
10. 常见错误与排查
11. 小结与练习

## Source Plan

- 桌面本地网页：`UnityShader-深度测试实践 - 知乎.html`
- 桌面本地配图：深度曲线、视锥体、水体效果图
- `Assets/ShaderCourse/Example/Stentil/Shaders/Stentil_Geometry.shader`
- `Assets/ShaderCourse/Example/lightingModle/URP_BlinnPhong_Full_With_SH/URP_BlinnPhong_Full_With_SH.shader`

## Output

- 深度测试章节课件 `.pptx`
- URP 深度测试案例 Shader
- 对应材质文件
