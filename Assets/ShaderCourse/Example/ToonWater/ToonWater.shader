Shader "ShaderCourse/ToonWater_URP"
{
    Properties
    {
        // ==================== 水体基础颜色 ====================
        // 浅水区域颜色：越接近岸边或水底越浅时越接近这个颜色。
        _DepthGradientShallow ("浅水颜色", Color) = (0.325, 0.807, 0.971, 0.725)

        // 深水区域颜色：水越深越接近这个颜色。
        _DepthGradientDeep ("深水颜色", Color) = (0.086, 0.407, 1, 0.749)

        // 深度渐变作用的最大距离，值越大，浅水到深水过渡越缓。
        _DepthMaxDistance ("深度渐变最大距离", Float) = 1

        // ==================== 泡沫与扰动 ====================
        // 交界泡沫颜色，用于水面与岸边/模型交界处。
        _FoamColor ("泡沫颜色", Color) = (1, 1, 1, 1)

        // 表面噪声贴图，用于控制泡沫的破碎边缘形状。
        _SurfaceNoise ("表面噪声", 2D) = "white" {}

        // 噪声滚动速度，xy 分量分别控制 U/V 方向流动。
        _SurfaceNoiseScroll ("噪声滚动速度", Vector) = (0.03, 0.03, 0, 0)

        // 泡沫阈值，越高泡沫面积越少。
        _SurfaceNoiseCutoff ("泡沫阈值", Range(0, 1)) = 0.777

        // 扰动贴图：RG 通道用来偏移噪声 UV，让水面更灵动。
        _SurfaceDistortion ("扰动贴图", 2D) = "gray" {}

        // 扰动强度。
        _SurfaceDistortionAmount ("扰动强度", Range(0, 1)) = 0.27

        // 交界泡沫的最大/最小检测距离。
        _FoamMaxDistance ("泡沫最大距离", Float) = 0.4
        _FoamMinDistance ("泡沫最小距离", Float) = 0.04

        // 下面这组参数专门控制“物体穿进水面时”的白边泡沫。
        // 和前面的噪声泡沫不同，这组会更稳定、更适合教学演示。
        _IntersectionFoamWidth ("交界泡沫宽度", Range(0.01, 2.0)) = 0.6
        _IntersectionFoamSoftness ("交界泡沫软化", Range(0.001, 1.0)) = 0.18
        _IntersectionFoamBrightness ("交界泡沫亮度", Range(0, 2)) = 1.2

        // ==================== 卡通 PBR 光照 ====================
        // 基础色乘子，方便整体调色。
        _BaseColor ("基础颜色乘子", Color) = (1, 1, 1, 1)

        // 金属度与光滑度仍然保留为 PBR 参数，但最终高光表现是卡通化分层。
        _Metallic ("金属度", Range(0, 1)) = 0
        _Smoothness ("光滑度", Range(0, 1)) = 0.88

        // 阴影层与高光层的分段阈值。
        _ShadowStep ("阴影分界", Range(0, 1)) = 0.45
        _HighlightStep ("高光分界", Range(0, 1)) = 0.8
        _BandSoftness ("分层软化", Range(0.001, 0.2)) = 0.04
        _ShadowStrength ("阴影强度", Range(0, 1)) = 0.55

        // 高光颜色和边缘光颜色。
        _SpecularColor ("高光颜色", Color) = (1, 1, 1, 1)
        _RimColor ("边缘光颜色", Color) = (0.75, 0.92, 1.0, 1.0)
        _RimPower ("边缘光指数", Range(0.5, 8)) = 3.0
        _RimStrength ("边缘光强度", Range(0, 2)) = 0.6

        // 环境反射染色与强度。
        _ReflectionTint ("反射颜色", Color) = (0.7, 0.9, 1.0, 1.0)
        _IBLStrength ("环境反射强度", Range(0, 2)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Assets/ShaderCourse/Example/ToonWater/ToonPBRLightingCommon.hlsl"

            #define SMOOTHSTEP_AA 0.01

            CBUFFER_START(UnityPerMaterial)
                float4 _DepthGradientShallow;
                float4 _DepthGradientDeep;
                float4 _FoamColor;
                float4 _BaseColor;
                float4 _SpecularColor;
                float4 _RimColor;
                float4 _ReflectionTint;
                float4 _SurfaceNoise_ST;
                float4 _SurfaceDistortion_ST;
                float4 _SurfaceNoiseScroll;
                half _DepthMaxDistance;
                half _FoamMaxDistance;
                half _FoamMinDistance;
                half _IntersectionFoamWidth;
                half _IntersectionFoamSoftness;
                half _IntersectionFoamBrightness;
                half _SurfaceNoiseCutoff;
                half _SurfaceDistortionAmount;
                half _Metallic;
                half _Smoothness;
                half _ShadowStep;
                half _HighlightStep;
                half _BandSoftness;
                half _ShadowStrength;
                half _RimPower;
                half _RimStrength;
                half _IBLStrength;
            CBUFFER_END

            TEXTURE2D(_SurfaceNoise);
            SAMPLER(sampler_SurfaceNoise);
            TEXTURE2D(_SurfaceDistortion);
            SAMPLER(sampler_SurfaceDistortion);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 noiseUV : TEXCOORD0;
                float2 distortUV : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                float waterEyeDepth : TEXCOORD5;
                float4 shadowCoord : TEXCOORD6;
            };

            // 普通透明混合：把泡沫层叠加到水体底色上。
            float4 AlphaBlend(float4 top, float4 bottom)
            {
                float3 color = (top.rgb * top.a) + (bottom.rgb * (1.0 - top.a));
                float alpha = top.a + bottom.a * (1.0 - top.a);
                return float4(color, alpha);
            }

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalize(normalInputs.normalWS);
                output.shadowCoord = GetShadowCoord(positionInputs);

                output.screenPos = ComputeScreenPos(positionInputs.positionCS);
                output.waterEyeDepth = -TransformWorldToView(positionInputs.positionWS).z;

                output.noiseUV = TRANSFORM_TEX(input.uv, _SurfaceNoise);
                output.distortUV = TRANSFORM_TEX(input.uv, _SurfaceDistortion);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 screenUV = input.screenPos.xy / input.screenPos.w;

                // 读取屏幕深度，并转换到线性眼空间深度。
                real rawSceneDepth = SampleSceneDepth(screenUV);
                float sceneEyeDepth = LinearEyeDepth(rawSceneDepth, _ZBufferParams);

                // 当前像素后方物体与水面的距离差，用来控制深浅水与交界泡沫。
                float depthDifference = max(sceneEyeDepth - input.waterEyeDepth, 0.0);

                // ==================== 深浅水颜色 ====================
                float waterDepthDifference01 = saturate(depthDifference / max(_DepthMaxDistance, 0.0001));
                float4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, waterDepthDifference01);
                waterColor.rgb *= _BaseColor.rgb;
                waterColor.a *= _BaseColor.a;

                // ==================== 交界泡沫 ====================
                // 不再依赖 Built-in 的相机法线纹理，而是用视角与水面法线的关系估算泡沫范围。
                half3 normalWS = normalize(input.normalWS);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
                half viewDot = saturate(dot(normalWS, viewDirWS));

                // 越接近掠射角，泡沫检测范围稍微放大，视觉上更自然。
                float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, viewDot);

                // 这里专门做“交界环形泡沫”：
                // depthDifference 越小，说明越接近水面与物体的交界处，泡沫越强。
                // depthDifference 越大，说明离交界越远，泡沫越弱直到消失。
                float edgeFoamMask = saturate(1.0 - depthDifference / max(foamDistance, 0.0001));

                // 用阈值控制泡沫图案：
                // 越靠近交界，阈值越低，越容易出现泡沫；
                // 越远离交界，阈值越高，泡沫逐渐被“侵蚀”掉。
                float surfaceNoiseCutoff = lerp(1.0, _SurfaceNoiseCutoff, edgeFoamMask);

                // 扰动贴图用于打散泡沫边缘。
                float2 distortSample = (
                    SAMPLE_TEXTURE2D(_SurfaceDistortion, sampler_SurfaceDistortion, input.distortUV).xy * 2.0 - 1.0
                ) * _SurfaceDistortionAmount;

                float2 noiseUV = float2(
                    input.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x + distortSample.x,
                    input.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y + distortSample.y
                );

                float surfaceNoiseSample = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, noiseUV).r;
                float surfaceNoise = smoothstep(
                    surfaceNoiseCutoff - SMOOTHSTEP_AA,
                    surfaceNoiseCutoff + SMOOTHSTEP_AA,
                    surfaceNoiseSample
                );
                surfaceNoise *= edgeFoamMask;

                // 第二套泡沫：显式的交界白边泡沫。
                // depthDifference 越接近 0，说明物体越贴近水面交线。
                // 这层不依赖噪声是否明显，主要负责“稳定看见边缘”。
                float contactFoam = 1.0 - smoothstep(
                    max(_IntersectionFoamWidth - _IntersectionFoamSoftness, 0.0),
                    _IntersectionFoamWidth,
                    depthDifference
                );

                // 再保留一层较柔和的保底环，用来辅助连接噪声泡沫和白边泡沫。
                float edgeRing = smoothstep(0.05, 0.8, edgeFoamMask) * edgeFoamMask;

                // 双通道合并：
                // 1. surfaceNoise：原来的噪声破碎泡沫
                // 2. contactFoam：稳定的交界白边泡沫
                // 3. edgeRing：中间过渡层
                float foamMask = saturate(max(surfaceNoise, max(contactFoam, edgeRing * 0.85)));

                float4 foamColor = _FoamColor;
                foamColor.a *= foamMask;

                // ==================== 卡通 PBR 光照 ====================
                // 这里开始调用“公共光照逻辑”。
                // 这样水面和场景其他物体会吃同一套卡通光照规则。
                ToonPBRLightingInput lightingInput;
                lightingInput.albedo = waterColor.rgb;
                lightingInput.normalWS = normalWS;
                lightingInput.viewDirWS = viewDirWS;
                lightingInput.positionWS = input.positionWS;
                lightingInput.shadowCoord = input.shadowCoord;

                ToonPBRLightingParams lightingParams;
                lightingParams.metallic = _Metallic;
                lightingParams.smoothness = _Smoothness;
                lightingParams.shadowStep = _ShadowStep;
                lightingParams.highlightStep = _HighlightStep;
                lightingParams.bandSoftness = _BandSoftness;
                lightingParams.shadowStrength = _ShadowStrength;
                lightingParams.specularColor = _SpecularColor.rgb;
                lightingParams.rimColor = _RimColor.rgb;
                lightingParams.rimPower = _RimPower;
                lightingParams.rimStrength = _RimStrength;
                lightingParams.reflectionTint = _ReflectionTint.rgb;
                lightingParams.iblStrength = _IBLStrength;

                half3 litColor = EvaluateToonPBRLighting(lightingInput, lightingParams);

                // 先得到受光后的水体颜色，再把泡沫透明叠加上去。
                float4 litWaterColor = float4(litColor, waterColor.a);

                // 再给泡沫补一层直接提亮：
                // 其中 contactFoam 的权重更高，因为它专门负责“物体穿水白边”。
                // 这样就算物体本身颜色较亮，交界线也不会完全被吃掉。
                float foamHighlight = surfaceNoise * 0.35 + edgeRing * 0.45 + contactFoam * _IntersectionFoamBrightness;
                litWaterColor.rgb += _FoamColor.rgb * foamHighlight;
                return AlphaBlend(foamColor, litWaterColor);
            }
            ENDHLSL
        }
    }
}
