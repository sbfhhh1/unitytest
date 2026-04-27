Shader "ShaderCourse/URP_PBR_Lesson"
{
    Properties
    {
        [Header(Base)]
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}

        [Header(Scalar Controls)]
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.55

        [Header(Normal)]
        [Toggle(_NORMALMAP)] _EnableNormalMap ("Enable Normal Map", Float) = 0
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Range(0, 2)) = 1

        [Header(Mask Map)]
        // 为了让一个案例承载更多材质细节，这里额外引入 Mask Map。
        // 通道约定：
        // R = Metallic   金属度
        // G = AO         环境遮蔽
        // B = Emission   自发光遮罩
        // A = Roughness  粗糙度
        _MaskMap ("Mask Map (R=Metal G=AO B=Emission A=Rough)", 2D) = "white" {}
        [Toggle(_USEMASKMAP)] _UseMaskMap ("Use Mask Map", Float) = 0
        _AOStrength ("AO Strength", Range(0, 1)) = 1

        [Header(Emission)]
        [HDR] _EmissionColor ("Emission Color", Color) = (0, 0, 0, 1)
        _EmissionStrength ("Emission Strength", Range(0, 5)) = 1

        [Header(Indirect Lighting)]
        _IBLStrength ("IBL Strength", Range(0, 2)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma shader_feature_local_fragment _NORMALMAP
            #pragma shader_feature_local_fragment _USEMASKMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _MaskMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _Metallic;
                half _Smoothness;
                half _NormalScale;
                half _AOStrength;
                half _EmissionStrength;
                half _IBLStrength;
            CBUFFER_END

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MaskMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uvMask : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                float4 tangentWS : TEXCOORD4;
                float4 shadowCoord : TEXCOORD5;
            };

            struct SurfaceDataEx
            {
                half3 albedo;
                half3 normalWS;
                half3 emission;
                half metallic;
                half smoothness;
                half roughness;
                half ao;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = float4(normalInputs.tangentWS.xyz, input.tangentOS.w);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.uvMask = TRANSFORM_TEX(input.uv, _MaskMap);
                output.shadowCoord = GetShadowCoord(positionInputs);
                return output;
            }

            // 将法线贴图中的切线空间法线转换到世界空间。
            // 这一段与前面法线贴图课程内容呼应：法线贴图并不直接替换几何法线，
            // 而是通过 TBN 矩阵把“切线空间扰动”还原到世界空间中参与光照。
            half3 GetSurfaceNormal(Varyings input)
            {
                half3 normalWS = normalize(input.normalWS);

                #if defined(_NORMALMAP)
                    half3 normalTS = UnpackNormalScale(
                        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv),
                        _NormalScale
                    );

                    half3 tangentWS = normalize(input.tangentWS.xyz);
                    half tangentSign = input.tangentWS.w * GetOddNegativeScale();
                    half3 bitangentWS = normalize(cross(normalWS, tangentWS) * tangentSign);
                    half3x3 tbn = half3x3(tangentWS, bitangentWS, normalWS);
                    normalWS = normalize(TransformTangentToWorld(normalTS, tbn));
                #endif

                return normalWS;
            }

            // Schlick 近似版菲涅尔项。
            // 视线越贴近掠射方向，反射越强，这是 PBR 高光“边缘更亮”的关键来源之一。
            half3 FresnelSchlick(half cosTheta, half3 F0)
            {
                return F0 + (1.0h - F0) * Pow4(1.0h - cosTheta) * (1.0h - cosTheta);
            }

            // GGX 法线分布函数 D：
            // 用来描述微表面法线与半角向量对齐的概率分布。
            // 粗糙度越高，高光越宽；粗糙度越低，高光越集中。
            half DistributionGGX(half NdotH, half roughness)
            {
                half a = roughness * roughness;
                half a2 = a * a;
                half denom = NdotH * NdotH * (a2 - 1.0h) + 1.0h;
                return a2 / max(PI * denom * denom, 0.0001h);
            }

            // Schlick-GGX 几何项 G 的单边版本。
            // 它用来模拟微表面的自遮挡与自阴影。
            half GeometrySchlickGGX(half NdotX, half roughness)
            {
                half r = roughness + 1.0h;
                half k = (r * r) * 0.125h;
                return NdotX / lerp(k, 1.0h, NdotX);
            }

            half GeometrySmith(half NdotV, half NdotL, half roughness)
            {
                half gV = GeometrySchlickGGX(NdotV, roughness);
                half gL = GeometrySchlickGGX(NdotL, roughness);
                return gV * gL;
            }

            // 采样并整理材质参数。
            // 这一步把“贴图采样”和“光照计算”分离开，课堂讲解时更清晰：
            // 前半部分负责准备材质输入，后半部分负责 BRDF 计算。
            SurfaceDataEx InitializeSurfaceData(Varyings input)
            {
                SurfaceDataEx surface;

                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                surface.albedo = baseTex.rgb * _BaseColor.rgb;
                surface.normalWS = GetSurfaceNormal(input);

                surface.metallic = _Metallic;
                surface.smoothness = _Smoothness;
                surface.roughness = max(1.0h - surface.smoothness, 0.04h);
                surface.ao = 1.0h;
                surface.emission = 0.0h;

                #if defined(_USEMASKMAP)
                    half4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uvMask);

                    // R 通道覆盖金属度，让同一张材质在局部拥有不同金属表现。
                    surface.metallic = mask.r;

                    // G 通道作为 AO，控制缝隙、凹陷等区域的间接光衰减。
                    surface.ao = lerp(1.0h, mask.g, _AOStrength);

                    // A 通道写粗糙度，因此这里要转换为 smoothness 以适配当前课程逻辑。
                    surface.roughness = max(mask.a, 0.04h);
                    surface.smoothness = 1.0h - surface.roughness;

                    // B 通道只作为“哪里发光”的遮罩，实际颜色和强度仍由材质参数控制。
                    surface.emission = mask.b * _EmissionColor.rgb * _EmissionStrength;
                #endif

                return surface;
            }

            // 直接光照部分：主光与附加光都会调用同一套 BRDF 逻辑。
            // 这样结构上更接近课堂中讲的“材质函数 + 光源遍历”。
            // EvaluateDirectPBR：
            // 计算“单个光源”对当前像素产生的直接光照结果。
            // 参数说明：
            // lightData  = 当前参与计算的光源数据
            // surface    = 当前像素整理好的材质参数
            // viewDirWS  = 当前像素指向相机的世界空间视线方向
            half3 EvaluateDirectPBR(
                Light lightData,
                SurfaceDataEx surface,
                half3 viewDirWS)
            {
                // 光线方向，来自当前参与计算的光源。
                half3 lightDirWS = normalize(lightData.direction);
                // 半角向量 H，表示“视线方向 V”和“光线方向 L”的中间方向。
                // 在微表面模型里，很多高光计算都要用到它。
                half3 halfDirWS = SafeNormalize(lightDirWS + viewDirWS);

                // NdotL：法线与光线夹角的余弦值。
                // 越接近 1，说明表面越正对光源，受到的直接光越强。
                half NdotL = saturate(dot(surface.normalWS, lightDirWS));
                // NdotV：法线与视线夹角的余弦值。
                // 它会影响几何项和菲涅尔项。
                half NdotV = saturate(dot(surface.normalWS, viewDirWS));
                // NdotH：法线与半角向量夹角的余弦值。
                // 它主要参与法线分布函数 D 的计算。
                half NdotH = saturate(dot(surface.normalWS, halfDirWS));
                // VdotH：视线与半角向量夹角的余弦值。
                // 它主要参与菲涅尔项 F 的计算。
                half VdotH = saturate(dot(viewDirWS, halfDirWS));

                // F0 表示“正视角下的基础反射率”，也就是视线垂直看向表面时，
                // 材质在镜面反射方向上会反射多少能量。
                // 对大多数非金属来说，F0 通常接近 0.04；
                // 对金属来说，F0 不再是固定值，而是更接近它本身的表面颜色。
                // 所以这里用 metallic 在“非金属默认反射率 0.04”和“材质本身颜色”之间做插值。
                half3 F0 = lerp(half3(0.04h, 0.04h, 0.04h), surface.albedo, surface.metallic);

                // F：菲涅尔项。
                // 用来描述“观察角度变化时，反射会如何变化”。
                half3 F = FresnelSchlick(VdotH, F0);
                // D：法线分布项。
                // 用来描述微表面朝向与半角向量对齐的概率分布。
                half D = DistributionGGX(NdotH, surface.roughness);
                // G：几何遮挡项。
                // 用来描述微表面的自遮挡和自阴影。
                half G = GeometrySmith(NdotV, NdotL, surface.roughness);

                // Cook-Torrance 镜面反射项的分子部分：D * G * F。
                half3 numerator = D * G * F;
                // 分母部分：4 * (NdotV) * (NdotL)。
                // 加一个很小的值是为了防止分母过小导致数值问题。
                half denominator = max(4.0h * NdotV * NdotL, 0.0001h);
                // 得到最终的镜面反射项 specular。
                half3 specular = numerator / denominator;

                // kS 表示镜面反射所占的能量比例。
                // 在这里直接使用菲涅尔结果作为镜面能量权重。
                half3 kS = F;
                // kD 表示漫反射所占的能量比例。
                // 1 - kS 体现能量守恒：镜面反射强了，漫反射就要相应减弱。
                // 再乘以 (1 - metallic) 是因为金属几乎没有传统意义上的漫反射。
                half3 kD = (1.0h - kS) * (1.0h - surface.metallic);
                // 漫反射部分采用 Lambert 模型，并除以 PI 做能量归一化。
                half3 diffuse = kD * surface.albedo / PI;

                // 光源衰减 = 距离衰减 * 阴影衰减。
                half attenuation = lightData.distanceAttenuation * lightData.shadowAttenuation;
                // radiance 表示当前光源最终真正照到表面的光能颜色。
                half3 radiance = lightData.color * attenuation;
                // 最终直接光 = （漫反射 + 镜面反射）* 光源能量 * NdotL。
                // NdotL 保证掠射角时直接光自然减弱。
              //  return (diffuse + specular) * radiance * NdotL;
                return F0;
            }

            // 间接光部分：SH 负责低频漫反射环境光，反射探针负责镜面环境反射。
            // 这和 PPT 中“URP 里的 IBL 拆分”那一页是对应的。
            // EvaluateIBL：
            // 计算环境光照，也就是没有明确“单个光源方向”时，
            // 来自天空盒、反射探针、环境漫反射等部分的贡献。
            // 参数说明：
            // surface    = 当前像素整理好的材质参数
            // viewDirWS  = 当前像素指向相机的世界空间视线方向
            // positionWS = 当前像素的世界空间位置，环境反射采样时会用到
            half3 EvaluateIBL(
                SurfaceDataEx surface,
                half3 viewDirWS,
                float3 positionWS)
            {
                // NdotV：法线与视线夹角的余弦值。
                // 间接光中的菲涅尔和环境高光也要用到它。
                half NdotV = saturate(dot(surface.normalWS, viewDirWS));
                // 这里的 F0 含义与直接光部分一致：
                // 它是材质在“迎着视线观察时”的基础镜面反射率，
                // 后续会作为菲涅尔项的起点，决定环境高光反射的底色和强度基准。
                half3 F0 = lerp(half3(0.04h, 0.04h, 0.04h), surface.albedo, surface.metallic);

                // fresnel：环境光部分同样要考虑菲涅尔效应。
                // 观察角越刁钻，镜面反射越明显。
                half3 fresnel = FresnelSchlick(NdotV, F0);
                // kS：间接镜面反射权重。
                half3 kS = fresnel;
                // kD：间接漫反射权重。
                // 同样遵守能量守恒，并在金属区域压低漫反射。
                half3 kD = (1.0h - kS) * (1.0h - surface.metallic);

                // 间接漫反射：
                // 用球谐函数 SampleSH 近似环境中的低频漫反射光。
                // 再乘以 albedo、漫反射权重 kD 和 AO。
                half3 diffuseIBL = SampleSH(surface.normalWS) * surface.albedo * kD * surface.ao;
                // 反射向量，用来查询环境反射。
                half3 reflectDirWS = reflect(-viewDirWS, surface.normalWS);

                // Unity 6 / URP 中的环境反射采样接口需要传入 positionWS。
                // specularIBL：间接镜面反射，也就是我们常说的“环境高光”。
                half3 specularIBL =
                    // GlossyEnvironmentReflection 会根据反射方向、世界坐标和粗糙度，
                    // 从环境反射数据中取出合适的镜面反射结果。
                    GlossyEnvironmentReflection(reflectDirWS, positionWS, surface.roughness, 1.0h).rgb
                    // 再乘以菲涅尔结果，让环境高光也符合“掠射更强”的规律。
                    * fresnel;

                // 非金属材质更容易被 AO 压暗，金属高光通常保留得更多。
                specularIBL *= lerp(surface.ao, 1.0h, surface.metallic);

                // 最终间接光 = 间接漫反射 + 间接镜面反射，
                // 再乘一个总控参数，方便课堂演示时整体调节环境光贡献。
                // 返回这个像素最终的环境光照结果。
                return (diffuseIBL + specularIBL) * _IBLStrength;
            }

            half4 frag(Varyings input) : SV_Target
            {
                SurfaceDataEx surface = InitializeSurfaceData(input);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));

                Light mainLight = GetMainLight(input.shadowCoord);
                half3 directLighting = EvaluateDirectPBR(mainLight, surface, viewDirWS);

                #if defined(_ADDITIONAL_LIGHTS)
                    uint additionalLightsCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < additionalLightsCount; ++lightIndex)
                    {
                        Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);
                        directLighting += EvaluateDirectPBR(additionalLight, surface, viewDirWS);
                    }
                #endif

                half3 indirectLighting = EvaluateIBL(surface, viewDirWS, input.positionWS);

                // 最终颜色 = 直接光 + 间接光 + 自发光。
                // 这样学生可以清楚看到 PBR 在工程里并不是“一个公式”，
                // 而是一套由多部分叠加构成的材质求值流程。
                half3 finalColor = directLighting + indirectLighting + surface.emission;
                return half4(directLighting, 1.0h);
            }
            ENDHLSL
        }
    }
}
