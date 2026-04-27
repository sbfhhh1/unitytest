Shader "ShaderCourse/ScreenDepthTexture_Shield"
{
    Properties
    {
        // ============================================================
        // 场景混合（Scene Blend）
        // ============================================================
        [Header(Scene Blend)]
        _SceneTintStrength ("Scene Tint Strength", Range(0, 1)) = 0.65
        _FillStrength ("Depth Fill Strength", Range(0, 2)) = 0.8
        _BaseAlpha ("Base Alpha", Range(0, 1)) = 0.28

        // ============================================================
        // 边缘光 & 交界发光（Edge Lighting / Intersection）
        // ============================================================
        [Header(Edge Lighting)]
        _RimColor ("Rim Color", Color) = (0.70, 0.98, 1.00, 1.00)
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 3.5
        _RimStrength ("Rim Strength", Range(0, 4.0)) = 1.8
        _IntersectionColor ("Intersection Color", Color) = (0.95, 1.00, 1.00, 1.00)
        _IntersectionWidth ("Intersection Width", Range(0.01, 2.0)) = 0.22
        _IntersectionStrength ("Intersection Strength", Range(0, 4.0)) = 2.5

        // ============================================================
        // 深度颜色映射（Depth Colors）
        // ============================================================
        [Header(Depth Colors)]
        _DepthRange ("Depth Range", Range(0.1, 50.0)) = 8.0
        _NearColor ("Near Color", Color) = (0.12, 0.95, 1.00, 1.00)
        _FarColor ("Far Color", Color) = (0.03, 0.08, 0.20, 1.00)
        _GapColor ("Gap Color", Color) = (0.10, 0.70, 1.00, 1.00)

        // ============================================================
        // 能量纹理装饰（Energy Pattern）
        // ============================================================
        [Header(Energy Pattern)]
        _PatternTex ("Pattern Texture", 2D) = "white" {}
        _PatternColor ("Pattern Color", Color) = (0.72, 0.96, 1.00, 1.00)
        _PatternTiling ("Pattern Tiling", Range(1, 20)) = 6
        _PatternStrength ("Pattern Strength", Range(0, 2)) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "Shield"
            Tags { "LightMode" = "UniversalForward" }

            // ----------------------------------------------------------
            // 混合与深度写入设置
            // ----------------------------------------------------------
            // Blend SrcAlpha OneMinusSrcAlpha : 标准透明混合。
            // 片元的 alpha 值决定透明度，背景按 (1-alpha) 保留。
            //
            // ZWrite Off : 护盾是半透明物体，不写入深度缓冲。
            // 如果写入深度，半透明物体之间或与自身会产生错误遮挡。
            //
            // ZTest LEqual : 正常深度测试，护盾被不透明物体挡住的地方不显示。
            // ----------------------------------------------------------
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Back
            ZWrite Off
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            // ============================================================
            // 材质参数（UnityPerMaterial）
            // ============================================================
            CBUFFER_START(UnityPerMaterial)
                float4 _PatternTex_ST;
                half _DepthRange;           // 深度归一化范围（米），决定深度映射的远近边界
                half _SceneTintStrength;    // 背景场景颜色的渗透强度
                half _FillStrength;         // 深度填充颜色强度
                half _BaseAlpha;            // 基础透明度
                half4 _RimColor;            // 边缘光颜色
                half _RimPower;             // 菲涅尔指数，值越大边缘越窄
                half _RimStrength;          // 边缘光亮度
                half4 _IntersectionColor;   // 交界发光颜色
                half _IntersectionWidth;    // 交界检测的深度阈值（米）
                half _IntersectionStrength; // 交界发光亮度
                half4 _NearColor;           // 深度差值小（靠近遮挡物）时的颜色
                half4 _FarColor;            // 深度差值大（远离遮挡物）时的颜色
                half4 _GapColor;            // 中间过渡颜色
                half4 _PatternColor;        // 六边形纹理着色
                half _PatternTiling;         // 纹理在球面上的重复次数
                half _PatternStrength;      // 纹理可见度
            CBUFFER_END

            TEXTURE2D(_PatternTex);
            SAMPLER(sampler_PatternTex);

            // ============================================================
            // 顶点输入结构
            // ============================================================
            struct Attributes
            {
                float4 positionOS : POSITION;   // 对象空间位置
                float3 normalOS : NORMAL;       // 对象空间法线
            };

            // ============================================================
            // 片元输入结构（顶点到片元的插值数据）
            // ============================================================
            struct Varyings
            {
                float4 positionCS : SV_POSITION;    // 裁剪空间位置（栅格化用）
                float4 screenPos : TEXCOORD0;       // 屏幕坐标（用于计算 UV）
                float3 positionWS : TEXCOORD1;      // 世界空间位置
                float3 normalWS : TEXCOORD2;        // 世界空间法线
                float objectEyeDepth : TEXCOORD3;   // 当前片元的眼空间深度
            };

            // ============================================================
            // 顶点着色器
            // ============================================================
            Varyings vert(Attributes input)
            {
                Varyings output;

                // -------------------------------------------------------
                // 坐标变换
                // -------------------------------------------------------
                // VertexPositionInputs 内部做了以下变换链：
                //   positionOS → 世界空间 → 观察空间 → 裁剪空间
                // GetVertexPositionInputs 一次调用完成全部变换。
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                output.positionCS = positionInputs.positionCS;

                // -------------------------------------------------------
                // ComputeScreenPos — 为屏幕 UV 做准备
                // -------------------------------------------------------
                // 这里存的是 (x, y, z, w)，不是最终的 UV。
                // 在片元阶段通过 screenPos.xy / screenPos.w 得到 [0,1] 的屏幕 UV。
                // 之所以不在顶点阶段直接除 w，是因为裁剪空间插值是线性的，
                // 但透视投影下的 UV 需要透视校正插值，手动除 w 会破坏这个校正。
                // 正确的做法是传递 (x/w)*w = x，让 GPU 在片元阶段完成除法。
                output.screenPos = ComputeScreenPos(positionInputs.positionCS);

                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;

                // -------------------------------------------------------
                // 计算当前片元的眼空间深度
                // -------------------------------------------------------
                // TransformWorldToView 将世界坐标转换到观察空间（相机空间）。
                // 在观察空间中，相机的观察方向是 -Z 轴，
                // 因此 z 值越负表示离相机越远。
                // 取负号得到正值，值越大离相机越远。
                output.objectEyeDepth = -TransformWorldToView(positionInputs.positionWS).z;

                return output;
            }

            // ============================================================
            // 能量纹理采样
            // ============================================================
            // 将法线映射到球面 UV 坐标，再采样六边形纹理。
            //
            // atan2(normalWS.z, normalWS.x) 得到水平角度，
            // 范围 [-PI, PI] 映射到 [0, 1]。
            // normalWS.y 是垂直方向，范围 [-1, 1] 映射到 [0, 1]。
            //
            // 这是一种简单的「球体纹理映射」(sphere mapping)，
            // 不需要网格自带 UV，适合球形护盾或任意形状表面。
            half BuildEnergyPattern(float3 normalWS)
            {
                float2 sphereUV = float2(
                    atan2(normalWS.z, normalWS.x) / (2.0 * PI) + 0.5,
                    normalWS.y * 0.5 + 0.5
                );
                float2 patternUV = sphereUV * _PatternTiling;
                half patternSample = SAMPLE_TEXTURE2D(_PatternTex, sampler_PatternTex, patternUV).r;
                return patternSample;
            }

            // ============================================================
            // 片元着色器 —— 核心渲染逻辑
            // ============================================================
            // 以下是本 Shader 的核心教学区，我们一步步拆解：
            //
            // 【第一步】获取屏幕 UV
            //   通过 screenPos.xy / screenPos.w 将裁剪坐标转换成 [0,1] 屏幕 UV。
            //   这个 UV 可以用来采样屏幕深度纹理和场景颜色纹理。
            //
            // 【第二步】采样场景颜色
            //   从 _CameraOpaqueTexture 中读取当前像素后面的场景颜色。
            //   护盾是半透明的，需要混合背景。
            //
            // 【第三步】获取两种深度
            //   (a) 场景深度（sceneEyeDepth）：
            //       从屏幕深度纹理中读取当前像素位置"后方场景表面"的深度。
            //       这是理解本 Shader 最关键的一步。
            //   (b) 片元自身深度（objectEyeDepth）：
            //       来自顶点阶段计算的眼空间深度，表示当前护盾片元离相机多远。
            //
            // 【第四步】计算深度差值
            //   gapDepth = sceneEyeDepth - objectEyeDepth
            //   这个差值代表"护盾表面到后方场景表面之间的空间厚度"。
            //   差值越小 → 护盾越靠近障碍物 → 交界处。
            //   差值越大 → 护盾后方空的区域越大 → 内部区域。
            //
            // 【第五步】边缘光（菲涅尔效应）
            //   视角方向与法线的夹角越接近 90°（掠射角），边缘越亮。
            //   这是护盾/能量罩类效果最常用的视觉技巧。
            //
            // 【第六步】交界发光
            //   利用深度差值 gapDepth，当护盾贴近障碍物时产生高亮。
            //   这正是"深度纹理驱动视觉效果"的典型应用。
            //
            // 【第七步】合成最终颜色与透明度
            //   所有元素叠加，输出半透明片元。
            // ============================================================

            half4 frag(Varyings input) : SV_Target
            {
                // ============================================================
                // 第一步：计算屏幕 UV
                // ============================================================
                // screenPos 是 ComputeScreenPos 的输出，
                // 它保存了 (x, y, z, w) 四个分量。
                //
                // 为什么需要除以 w？
                // 因为裁剪空间的坐标经过了透视投影矩阵变换，
                // x 和 y 分量包含了透视缩放因子 w。
                // 除以 w 才能得到正确的屏幕归一化坐标 [0, 1]。
                //
                // 图示理解：
                //   裁剪空间 (x, y, z, w)
                //       ↓ 除以 w（透视除法）
                //   NDC 坐标 (-1 ~ 1)
                //       ↓ 映射到 [0, 1]
                //   屏幕 UV（用于采样纹理）
                float2 screenUV = input.screenPos.xy / input.screenPos.w;

                // ============================================================
                // 第二步：采样场景颜色
                // ============================================================
                // SampleSceneColor 是 URP 提供的封装函数，
                // 内部从 _CameraOpaqueTexture（不透明颜色纹理）中采样。
                //
                // 注意：这个纹理只包含不透明物体的颜色，
                // 透明物体之前的半透明物体不会被记录。
                // 护盾作为透明物体，需要主动混合背景。
                half3 sceneColor = SampleSceneColor(screenUV);

                // ============================================================
                // 第三步：获取场景深度纹理中的深度
                // ============================================================
                // -------------------------------------------------------
                // 3a. 读取原始设备深度（raw depth）
                // -------------------------------------------------------
                // SampleSceneDepth 从 _CameraDepthTexture 采样，
                // 返回的是非线性的设备深度（device depth），范围 [0, 1]。
                //
                // 深度纹理是怎么来的？
                //   在 URP 中，不透明物体渲染完成后，
                //   GPU 会将深度缓冲拷贝到 _CameraDepthTexture 中。
                //   这样 Shader 就可以像采样普通纹理一样读取场景深度。
                //
                // 深度缓冲 vs 深度纹理：
                //   深度缓冲是"被动裁决规则"——GPU 内部用它做深度测试，
                //   判断"哪个片元更近"。Shader 无法直接读取它。
                //   深度纹理是"主动采样数据"——把深度缓冲拷贝到可采样纹理中，
                //   Shader 可以主动查询"这个屏幕位置后方有什么"。
                //
                // 为什么不用深度缓冲做这件事？
                //   深度缓冲是 GPU 流水线内部的暂存区，不是可采样资源。
                //   在延迟渲染中深度缓冲本身是 G-buffer 的一部分，
                //   但在前向渲染中必须显式拷贝才能采样。
                // -------------------------------------------------------
                real rawSceneDepth = SampleSceneDepth(screenUV);

                // -------------------------------------------------------
                // 3b. 线性化 — 将设备深度转换为眼空间深度
                // -------------------------------------------------------
                // 设备深度是非线性的，它遵循投影矩阵的倒数关系：
                //   更多的精度分配给了靠近相机的物体。
                //
                // 非线性深度的特点：
                //   近处的物体深度值变化剧烈，远处的变化缓慢。
                //   直接做减法得到的是"非线性差值"，不能代表真实距离差。
                //
                // LinearEyeDepth 的作用：
                //   将 [0, 1] 的设备深度逆变换回眼空间的 Z 值（单位：米）。
                //   这样 sceneEyeDepth 就代表了"这个像素后方场景表面的实际距离"。
                //
                // _ZBufferParams 包含投影矩阵的逆变换参数：
                //   x = (1 - far/near) / 2
                //   y = (1 + far/near) / 2
                //   线性化公式：LinearEyeDepth = 1 / (z * x + y)
                //   其中 z 是设备深度值。
                half sceneEyeDepth = LinearEyeDepth(rawSceneDepth, _ZBufferParams);

                // -------------------------------------------------------
                // 3c. 当前片元的自身深度（来自顶点阶段）
                // -------------------------------------------------------
                // 这个值不是从深度纹理中采样的，而是从顶点数据插值而来。
                // 每个顶点的观察空间 Z 值经过光栅化插值，得到每个片元的深度。
                //
                // 初学者最容易混淆的地方就在这里：
                //   sceneEyeDepth    = 屏幕纹理采样 → 后方场景的深度
                //   objectEyeDepth   = 顶点插值计算 → 当前片元自己的深度
                //
                // 一个是"从外部读进来的"，一个是"自己算出来的"。
                // 两者相减，才能知道护盾表面和场景表面之间的空间关系。
                half objectEyeDepth = input.objectEyeDepth;

                // ============================================================
                // 第四步：计算深度差值
                // ============================================================
                // gapDepth = sceneEyeDepth - objectEyeDepth
                //
                // 含义：
                //   这个差值表示"护盾表面到它后面最近的不透明表面之间的空间厚度"。
                //
                // 边缘情况解读：
                //   gapDepth ≈ 0      → 护盾紧贴墙壁/地面 → 交界区域
                //   gapDepth 很大     → 护盾后方是开阔空间 → 内部区域
                //   gapDepth 为负     → 护盾在场景表面之前 → 不产生交界光
                //                       （用 max(..., 0) 截断）
                //
                // 为什么 gapDepth 可以驱动视觉效果？
                //   人的视觉系统对"物体靠近表面时产生的光晕"非常敏感，
                //   这是自然界中流体表面张力、静电吸附等物理现象的视觉特征。
                //   游戏中利用深度差值模拟这种"贴近感"，
                //   让护盾看起来像是真的贴在了场景表面。
                //
                // 实际应用场景：
                //   1. 护盾/能量罩：靠近墙壁时发出交界光
                //   2. 水体渲染：浅水区 vs 深水区的颜色过渡
                //   3. 软粒子：粒子靠近场景表面时淡出
                //   4. 描边/选中高亮：物体边缘发光
                // -------------------------------------------------------
                half gapDepth = max(sceneEyeDepth - objectEyeDepth, 0.0h);

                // -------------------------------------------------------
                // 将深度差值归一化到 [0, 1]
                // -------------------------------------------------------
                // gapDepth01 = gapDepth / _DepthRange
                // _DepthRange 控制"多少米以内算近、多少算远"。
                // 这是一个人为设定的范围，用于将物理距离映射到颜色空间。
                //
                // gapDepth01 趋近 0 → 护盾贴近障碍物
                // gapDepth01 趋近 1 → 护盾后方空间空旷
                half gapDepth01 = saturate(gapDepth / max(_DepthRange, 0.0001h));

                // ============================================================
                // 第五步：边缘光（菲涅尔效应 Fresnel Effect）
                // ============================================================
                // 菲涅尔效应的物理原理：
                //   当光线从一种介质进入另一种介质时，
                //   反射率随入射角增大而增大。
                //   简单说："视线越平，反射越强"。
                //
                // 在护盾效果中的应用：
                //   护盾是一个三维曲面，从中心到边缘，
                //   视线与表面的夹角逐渐从 90° 变为 0°（掠射角）。
                //   边缘处的法线与视线接近垂直 → NdotV ≈ 0 → rimMask 最大。
                //   中心处的法线正对视线 → NdotV ≈ 1 → rimMask 接近 0。
                //
                // 公式分解：
                //   NdotV = dot(normalWS, viewDirWS)
                //     法线与视线的点积，范围 [0, 1]。
                //     1 = 法线正对视线（中心），0 = 法线垂直于视线（边缘）。
                //
                //   rimMask = (1 - NdotV)^_RimPower * _RimStrength
                //     (1 - NdotV) 将 NdotV 翻转：中心 = 0，边缘 = 1。
                //     乘方 _RimPower 控制边缘光的"集中程度"，
                //       值越大，边缘光越窄、越锐利。
                //       值越小，边缘光越宽、越柔和。
                //     乘以 _RimStrength 控制整体亮度。
                //
                // 为什么护盾需要菲涅尔边缘光？
                //   在游戏视觉设计中，护盾/能量罩通常被表现为"能量场"。
                //   边缘高亮模拟了能量在表面边界聚集的视觉效果，
                //   同时也在视觉上清晰地勾勒出护盾的轮廓。
                // -------------------------------------------------------
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
                half3 normalWS = normalize(input.normalWS);

                half NdotV = saturate(dot(normalWS, viewDirWS));
                half rimMask = pow(1.0h - NdotV, _RimPower) * _RimStrength;

                // ============================================================
                // 第六步：交界发光（Intersection Glow）
                // ============================================================
                // 交界发光的核心思路是利用深度差值 gapDepth 检测"贴近"状态。
                //
                // intersectionMask 的计算：
                //   gapDepth / _IntersectionWidth 将深度值归一化到 [0, 1] 范围，
                //   其中 _IntersectionWidth 是"交界检测的阈值范围"（单位：米）。
                //
                //   举例子：
                //     _IntersectionWidth = 0.2 米
                //     gapDepth = 0.05 米 → gapDepth / 0.2 = 0.25
                //                       → 1 - 0.25 = 0.75 → 强烈发光
                //     gapDepth = 0.3 米  → gapDepth / 0.2 = 1.5
                //                       → saturate → 1.0 → 1 - 1.0 = 0 → 不发光
                //
                //   这意味着：护盾与障碍物距离在 _IntersectionWidth 以内时，
                //   距离越近发光越强；超出阈值则完全不发光。
                //
                //   再乘以 _IntersectionStrength 控制整体交界光的亮度。
                //
                // 为什么交界发光看起来像"能量在表面流动"？
                //   因为当护盾穿过墙壁或贴近地面时，
                //   gapDepth 在交界处发生剧烈变化（从很大变为很小），
                //   这个突变在视觉上形成了一条发光的轮廓线。
                //   如果物体在护盾内部移动，这条线会跟随物体运动，
                //   产生"能量在表面追踪物体"的动态效果。
                //
                // 这种技术在以下游戏中非常常见：
                //   - 科幻游戏的护盾/屏障效果
                //   - 角色被击中时的能量反馈
                //   - 武器充能/蓄力时的光效
                // -------------------------------------------------------
                half intersectionMask =
                    saturate(1.0h - gapDepth / max(_IntersectionWidth, 0.0001h)) * _IntersectionStrength;

                // ============================================================
                // 第七步：合成最终颜色
                // ============================================================
                // -------------------------------------------------------
                // 7a. 深度填充（内部颜色）
                // -------------------------------------------------------
                // 根据深度差值 gapDepth01 在 _NearColor 和 _GapColor 之间插值。
                // gapDepth01 = 0（贴近障碍物）→ _NearColor（亮蓝/青色）
                // gapDepth01 = 1（空间开阔）→ _GapColor（明亮的蓝色）
                //
                // 这种颜色映射模拟了"能量密度随空间厚度变化"的视觉效果：
                //   贴近表面处能量密集 → 颜色亮
                //   开阔区域能量扩散 → 颜色变淡或变为另一种色调
                half3 depthFill = lerp(_NearColor.rgb, _GapColor.rgb, gapDepth01) * _FillStrength;

                // -------------------------------------------------------
                // 7b. 混合背景场景
                // -------------------------------------------------------
                // 护盾不是完全不透明的，它需要透出背后的场景。
                // _SceneTintStrength 控制背景透过程度：
                //   0 = 完全不透（纯护盾颜色）
                //   1 = 完全透出（护盾只提供颜色叠加）
                //
                // sceneColor * depthFill = 用深度填充颜色对背景染色
                half3 sceneTinted = lerp(sceneColor, sceneColor * depthFill, _SceneTintStrength);

                // -------------------------------------------------------
                // 7c. 能量纹理装饰
                // -------------------------------------------------------
                // 六边形纹理作为表面装饰，不参与空间判断。
                // 它通过球面 UV 映射包裹在护盾表面，
                // 增加视觉层次感，让护盾看起来有"内部结构"。
                half patternMask = BuildEnergyPattern(normalWS) * _PatternStrength;
                half3 patternColor = _PatternColor.rgb * patternMask;

                // -------------------------------------------------------
                // 7d. 叠加所有颜色层
                // -------------------------------------------------------
                // 最终颜色 = 背景染色 + 深度填充 + 边缘光 + 交界光 + 纹理
                //
                // 每一层都有独立的物理含义：
                //   sceneTinted    → 做出"半透明能量场"的质感，透过它能看到世界
                //   depthFill      → 内部能量分布，模拟厚度感
                //   rimMask        → 外轮廓高亮，定义护盾的形状边界
                //   intersection   → 交界发光，表达护盾与场景的交互
                //   patternColor   → 表面细节，增加视觉复杂度
                half3 finalColor = sceneTinted;
                finalColor += depthFill * 0.35h;
                finalColor += _RimColor.rgb * rimMask;
                finalColor += _IntersectionColor.rgb * intersectionMask;
                finalColor += patternColor;

                // -------------------------------------------------------
                // 7e. 透明度合成
                // -------------------------------------------------------
                // alpha 同样由多层贡献：
                //   _BaseAlpha      → 基本透明度（护盾的基础可见度）
                //   rimMask         → 边缘更亮更不透明（突出轮廓）
                //   intersectionMask → 交界处更亮更不透明（强调接触区域）
                //   patternMask     → 纹理区域的可见度变化
                //
                // 这种多层 alpha 叠加让护盾看起来"活"的：
                //   不同区域有不同的透明度，模拟能量密度分布。
                half alpha =_BaseAlpha;
                alpha += saturate(rimMask * 0.35h);
                alpha += saturate(intersectionMask * 0.4h);
                alpha += patternMask * 0.15h;
                alpha = saturate(alpha);

                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}
