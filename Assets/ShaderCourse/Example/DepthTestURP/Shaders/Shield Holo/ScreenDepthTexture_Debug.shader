Shader "ShaderCourse/ScreenDepthTexture_Debug"
{
    Properties
    {
        // 说明：
        // 这里的 Inspector Header、Enum 名称仍然使用 ASCII，
        // 是为了规避 Unity 在部分编码环境下解析属性头时再次报错。
        // 面向课堂讲解的中文解释，统一写在下面的代码注释中。
        [Header(Depth Debug)]
        [Enum(SceneDepth,0,ShieldView,1,ObjectDepth,2,DepthDifference,3,IntersectionMask,4)] _DebugMode ("Debug Mode", Float) = 1
        _DepthRange ("Depth Range", Range(0.1, 50.0)) = 8.0
        _Contrast ("Depth Contrast", Range(0.25, 4.0)) = 1.0

        [Header(Scene Blend)]
        _SceneTintStrength ("Scene Tint Strength", Range(0, 1)) = 0.65
        _FillStrength ("Depth Fill Strength", Range(0, 2)) = 0.8
        _BaseAlpha ("Base Alpha", Range(0, 1)) = 0.28

        [Header(Edge Lighting)]
        _RimColor ("Rim Color", Color) = (0.70, 0.98, 1.00, 1.00)
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 3.5
        _RimStrength ("Rim Strength", Range(0, 4.0)) = 1.8
        _IntersectionColor ("Intersection Color", Color) = (0.95, 1.00, 1.00, 1.00)
        _IntersectionWidth ("Intersection Width", Range(0.01, 2.0)) = 0.22
        _IntersectionStrength ("Intersection Strength", Range(0, 4.0)) = 2.5

        [Header(Depth Colors)]
        _NearColor ("Near Color", Color) = (0.12, 0.95, 1.00, 1.00)
        _FarColor ("Far Color", Color) = (0.03, 0.08, 0.20, 1.00)
        _GapColor ("Gap Color", Color) = (0.10, 0.70, 1.00, 1.00)

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
            Name "DepthDebug"
            Tags { "LightMode" = "UniversalForward" }

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

            // --------------------------------------------------
            // 教学说明：深度缓冲 vs 深度纹理
            //
            // 1. 深度缓冲
            // 深度缓冲是 GPU 在渲染过程中维护的一块缓存。
            // 它的核心职责是做深度测试：判断“当前片元是否比已写入的片元更靠近相机”。
            // 如果当前片元更远，通常就会被丢弃，因此深度缓冲更像一套“可见性裁决规则”。
            //
            // 2. 深度纹理
            // 深度纹理可以理解为：把场景中的深度结果，以可采样纹理的形式提供给 Shader。
            // 这样 Shader 就不只是被动参与深度测试，还能主动读取“这个屏幕位置后方有多远的场景表面”。
            //
            // 3. 为什么教学中要单独做这个案例
            // 很多学生在水体、软粒子、护盾等效果里第一次接触深度纹理，
            // 容易把“视觉表现”与“底层原理”混在一起。
            // 护盾案例比水体更纯粹，能先把深度纹理的读取、比较、差值驱动讲清楚，
            // 再迁移到 PoolWater 之类的综合案例，会更自然。
            //
            // 4. 这个案例到底在演示什么
            // - 从屏幕深度纹理中读取后方场景深度
            // - 计算当前护盾表面的自身深度
            // - 用两者差值驱动交界发光、内部染色和边缘能量感
            // --------------------------------------------------

            CBUFFER_START(UnityPerMaterial)
                float4 _PatternTex_ST;
                half _DebugMode;
                half _DepthRange;
                half _Contrast;
                half _SceneTintStrength;
                half _FillStrength;
                half _BaseAlpha;
                half4 _RimColor;
                half _RimPower;
                half _RimStrength;
                half4 _IntersectionColor;
                half _IntersectionWidth;
                half _IntersectionStrength;
                half4 _NearColor;
                half4 _FarColor;
                half4 _GapColor;
                half4 _PatternColor;
                half _PatternTiling;
                half _PatternStrength;
            CBUFFER_END

            TEXTURE2D(_PatternTex);
            SAMPLER(sampler_PatternTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float objectEyeDepth : TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                // 裁剪空间坐标会用于最终栅格化，也会被后面拿来计算屏幕 UV。
                output.positionCS = positionInputs.positionCS;

                // ComputeScreenPos 会把裁剪空间坐标整理成适合后续换算屏幕坐标的数据。
                // 片元阶段通常通过 screenPos.xy / screenPos.w 得到标准化屏幕 UV。
                output.screenPos = ComputeScreenPos(positionInputs.positionCS);

                // 世界空间位置和法线后面会用于计算观察方向、边缘光和贴图采样。
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;

                // 这里计算的是“当前护盾自身的线性眼空间深度”。
                // 它不是从深度纹理里采样出来的，而是由当前顶点在观察空间中的 z 值换算得到。
                // 初学者最容易混淆的地方就在这里：
                // 场景深度纹理记录的是“这个屏幕位置后方场景表面的深度”，
                // 而 objectEyeDepth 记录的是“当前护盾片元自己的深度”。
                output.objectEyeDepth = -TransformWorldToView(positionInputs.positionWS).z;
                return output;
            }

            half3 VisualizeDepth(half depth01)
            {
                // 把 0~1 的深度值映射成伪彩色，方便课堂演示。
                // 越接近 0 表示越靠近相机，越接近 1 表示越远离相机。
                half remapped = saturate(pow(depth01, _Contrast));
                return lerp(_NearColor.rgb, _FarColor.rgb, remapped);
            }

            half BuildEnergyPattern(float3 normalWS)
            {
                // 这里不再用程序纹理，而是直接采样六边形贴图。
                // 这样学生能更清楚地区分两件事：
                // 1. 贴图负责表面装饰和风格化细节
                // 2. 深度纹理负责空间关系判断和交界效果驱动
                float2 sphereUV = float2(
                    atan2(normalWS.z, normalWS.x) / (2.0 * PI) + 0.5,
                    normalWS.y * 0.5 + 0.5
                );
                float2 patternUV = sphereUV * _PatternTiling;
                half patternSample = SAMPLE_TEXTURE2D(_PatternTex, sampler_PatternTex, patternUV).r;
                return patternSample;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 先把插值后的 screenPos 还原成真正的屏幕 UV，供场景颜色和深度纹理采样使用。
                float2 screenUV = input.screenPos.xy / input.screenPos.w;

                // 读取当前屏幕像素的场景颜色。
                // 护盾是透明效果，因此内部通常会保留一部分背景信息，让画面更像真实能量罩。
                half3 sceneColor = SampleSceneColor(screenUV);

                // 从屏幕深度纹理中读取“这个屏幕位置后方场景表面的原始深度”。
                // 这个值仍然是设备深度，不适合直接当作真实距离使用。
                real rawSceneDepth = SampleSceneDepth(screenUV);

                // 把设备深度线性化，得到更适合做距离比较的眼空间深度。
                half sceneEyeDepth = LinearEyeDepth(rawSceneDepth, _ZBufferParams);

                // 当前护盾片元自身的线性眼空间深度，来自顶点阶段传入的数据。
                half objectEyeDepth = input.objectEyeDepth;

                // 深度差值 = 后方场景深度 - 当前护盾深度
                // 差值越小，说明护盾越贴近墙面或地面；
                // 差值越大，说明护盾后方还有更大的空间厚度。
                // 这一步是本案例最核心的教学重点。
                half gapDepth = max(sceneEyeDepth - objectEyeDepth, 0.0h);

                // 为了更容易控制颜色和遮罩，把几种深度统一归一化到 0~1。
                half sceneDepth01 = saturate(sceneEyeDepth / max(_DepthRange, 0.0001h));
                half objectDepth01 = saturate(objectEyeDepth / max(_DepthRange, 0.0001h));
                half gapDepth01 = saturate(gapDepth / max(_DepthRange, 0.0001h));

                // 观察方向和法线是做边缘光时的基础输入。
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
                half3 normalWS = normalize(input.normalWS);

                // 菲涅尔边缘光：
                // 当视线越贴近掠射角时，边缘通常会更亮。
                // 这类高光常用于护盾、力场、能量罩等效果。
                half NdotV = saturate(dot(normalWS, viewDirWS));
                half rimMask = pow(1.0h - NdotV, _RimPower) * _RimStrength;

                // 交界发光：
                // 当护盾贴近后方几何体时，gapDepth 会变小，
                // 这里就会生成更强的交界发光。
                // 这正是深度纹理在游戏里最常见、也最实用的一类用法。
                half intersectionMask =
                    saturate(1.0h - gapDepth / max(_IntersectionWidth, 0.0001h)) * _IntersectionStrength;

                // 以下三组颜色主要用于调试显示：
                // falseSceneDepth：显示场景深度分布
                // falseObjectDepth：显示护盾自身深度分布
                // falseGapDepth：显示深度差值分布
                // falseIntersection：显示交界发光遮罩分布
                half3 falseSceneDepth = VisualizeDepth(sceneDepth01);
                half3 falseObjectDepth = VisualizeDepth(objectDepth01);
                half3 falseGapDepth = lerp(_FarColor.rgb, _GapColor.rgb, saturate(pow(gapDepth01, _Contrast)));
                half3 falseIntersection = _IntersectionColor.rgb * saturate(intersectionMask);

                if (_DebugMode < 0.5h)
                {
                    // 模式 0：直接观察场景深度纹理。
                    // 这一档最适合课堂开头先讲“深度纹理里到底存了什么”。
                    return half4(falseSceneDepth, 1.0h);
                }

                if (_DebugMode < 1.5h)
                {
                    // 模式 1：护盾演示模式。
                    // 把深度原理翻译成接近游戏成品的视觉效果：
                    // 1. 能看到背景
                    // 2. 内部根据深度差值染色
                    // 3. 靠近几何体时出现交界发光
                    // 4. 外轮廓带有菲涅尔边缘高亮
                    half3 depthFill = lerp(_NearColor.rgb, _GapColor.rgb, gapDepth01) * _FillStrength;
                    half3 sceneTinted = lerp(sceneColor, sceneColor * depthFill, _SceneTintStrength);

                    // 六边形能量纹理作为装饰细节，不参与空间判断，只负责提升视觉层次。
                    half patternMask = BuildEnergyPattern(normalWS) * _PatternStrength;
                    half3 patternColor = _PatternColor.rgb * patternMask;

                    half3 finalColor = sceneTinted;
                    finalColor += depthFill * 0.35h;
                    finalColor += _RimColor.rgb * rimMask;
                    finalColor += _IntersectionColor.rgb * intersectionMask;
                    finalColor += patternColor;

                    // 透明度同样由多种视觉因素共同决定：
                    // 基础透明度 + 边缘光 + 交界光 + 纹理细节。
                    half alpha = _BaseAlpha;
                    alpha += saturate(rimMask * 0.35h);
                    alpha += saturate(intersectionMask * 0.4h);
                    alpha += patternMask * 0.15h;
                    alpha = saturate(alpha);

                    return half4(finalColor, alpha);
                }

                if (_DebugMode < 2.5h)
                {
                    // 模式 2：显示当前护盾片元自身的线性眼空间深度。
                    // 这一档专门用来帮助学生区分两件事：
                    // 1. sceneEyeDepth 来自深度纹理，表示后方场景表面的深度
                    // 2. objectEyeDepth 来自当前护盾本身，表示当前片元自己的深度
                    // 只有把这两个量区分清楚，后面的深度差值比较才不容易混淆。
                    return half4(falseObjectDepth, 1.0h);
                }

                if (_DebugMode < 3.5h)
                {
                    // 模式 3：只显示深度差值。
                    // 这一档最适合讲“为什么深度差值可以驱动交界发光和厚度感”。
                    return half4(falseGapDepth, 1.0h);
                }

                if (_DebugMode > 3.5h)
                {
                    // 模式 4：只显示 intersectionMask。
                    // 这一档可以让学生单独观察：
                    // 深度差值在经过阈值压缩后，是如何变成交界发光遮罩的。
                    // 它特别适合讲“为什么只有靠近障碍物的位置才会亮起来”。
                    return half4(falseIntersection, 1.0h);
                }

                return half4(falseIntersection, 1.0h);
            }
            ENDHLSL
        }
    }
}
