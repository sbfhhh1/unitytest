Shader "ShaderCourse/Stentil_Geometry"
{
    Properties
    {
        // 当前物体要读取哪个模板 ID。
        // 只有当屏幕当前像素中的模板值 == 这里的 ID 时，物体才会显示。
        _StencilID ("模板 ID", Range(0, 255)) = 1

        // 基础颜色和贴图。
        [MainColor] _BaseColor ("基础颜色", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap ("基础贴图", 2D) = "white" {}

        // PBR 基础参数。
        _Metallic ("金属度", Range(0, 1)) = 0
        _Smoothness ("光滑度", Range(0, 1)) = 0.5

        // 法线贴图开关与强度。
        [Toggle(_NORMALMAP)] _EnableNormalMap ("启用法线贴图", Float) = 0
        [Normal] _NormalMap ("法线贴图", 2D) = "bump" {}
        _NormalScale ("法线强度", Range(0, 2)) = 1

        // 用于课堂上调强环境反射，方便观察 IBL 效果。
        _IBLStrength ("IBL 强度", Range(0, 2)) = 1
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
            Name "StencilGeometry"
            Tags { "LightMode" = "UniversalForward" }

            // 模板测试：
            // 只有模板值与当前材质的 _StencilID 相等时，当前像素才继续走后面的光照计算。
            // 所以 stencil 决定“哪里能显示”，PBR 决定“显示出来以后长什么样”。
            Stencil
            {
                Ref [_StencilID]
                Comp Equal
                Pass Keep
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            // 主光源阴影关键字。
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

          

            // 法线贴图开关。
            #pragma shader_feature_local_fragment _NORMALMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _Metallic;
                half _Smoothness;
                half _NormalScale;
                half _IBLStrength;
                half _StencilID;
            CBUFFER_END

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

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
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
            };

            // 顶点阶段：
            // 1. 计算裁剪空间位置，决定物体画到屏幕哪里
            // 2. 计算世界空间位置，后面求视线方向和附加光源会用到
            // 3. 计算世界空间法线和切线，为法线贴图准备 TBN 基础
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
                output.shadowCoord = GetShadowCoord(positionInputs);

                return output;
            }

            // 由顶点法线或法线贴图，得到最终参与光照的世界空间法线。
            half3 GetSurfaceNormal(Varyings input)
            {
                half3 normalWS = normalize(input.normalWS);

                #if defined(_NORMALMAP)
                    // 先从纹理采样切线空间法线。
                    half3 normalTS = UnpackNormalScale(
                        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv),
                        _NormalScale
                    );

                    // 构建 TBN：Tangent / Bitangent / Normal
                    // 用来把切线空间法线转换到世界空间。
                    half3 tangentWS = normalize(input.tangentWS.xyz);
                    half tangentSign = input.tangentWS.w * GetOddNegativeScale();
                    half3 bitangentWS = normalize(cross(normalWS, tangentWS) * tangentSign);
                    half3x3 tbn = half3x3(tangentWS, bitangentWS, normalWS);

                    normalWS = normalize(TransformTangentToWorld(normalTS, tbn));
                #endif

                return normalWS;
            }

            // Schlick 菲涅耳近似：
            // 用于估计观察角度变化时，镜面反射会如何增强。
            half3 FresnelSchlick(half cosTheta, half3 F0)
            {
                return F0 + (1.0h - F0) * Pow4(1.0h - cosTheta) * (1.0h - cosTheta);
            }

            // GGX 法线分布函数 D。
            half DistributionGGX(half NdotH, half roughness)
            {
                half a = roughness * roughness;
                half a2 = a * a;
                half denom = NdotH * NdotH * (a2 - 1.0h) + 1.0h;
                return a2 / max(PI * denom * denom, 0.0001h);
            }

            // Schlick-GGX 几何项的一半。
            half GeometrySchlickGGX(half NdotX, half roughness)
            {
                half r = roughness + 1.0h;
                half k = (r * r) * 0.125h;
                return NdotX / lerp(k, 1.0h, NdotX);
            }

            // Smith 几何项 G。
            half GeometrySmith(half NdotV, half NdotL, half roughness)
            {
                half gV = GeometrySchlickGGX(NdotV, roughness);
                half gL = GeometrySchlickGGX(NdotL, roughness);
                return gV * gL;
            }

            // 计算单个光源的直接光照。
            // 这里就是课堂里可讲的 BRDF 核心：
            // diffuse + specular，其中 specular 来自 Cook-Torrance 微表面模型。
            half3 EvaluateDirectPBR(
                Light lightData,
                half3 albedo,
                half3 normalWS,
                half3 viewDirWS,
                half metallic,
                half smoothness)
            {
                half3 lightDirWS = normalize(lightData.direction);
                half3 halfDirWS = SafeNormalize(lightDirWS + viewDirWS);

                half NdotL = saturate(dot(normalWS, lightDirWS));
                half NdotV = saturate(dot(normalWS, viewDirWS));
                half NdotH = saturate(dot(normalWS, halfDirWS));
                half VdotH = saturate(dot(viewDirWS, halfDirWS));

                // 光滑度越高，粗糙度越低。
                half roughness = max(1.0h - smoothness, 0.04h);

                // F0：
                // 非金属通常从 0.04 起步，金属则使用 albedo 作为镜面反射基色。
                half3 F0 = lerp(half3(0.04h, 0.04h, 0.04h), albedo, metallic);

                half3 F = FresnelSchlick(VdotH, F0);
                half D = DistributionGGX(NdotH, roughness);
                half G = GeometrySmith(NdotV, NdotL, roughness);

                half3 numerator = D * G * F;
                half denominator = max(4.0h * NdotV * NdotL, 0.0001h);
                half3 specular = numerator / denominator;

                // 能量守恒：
                // 镜面反射越强，漫反射应越弱。
                half3 kS = F;
                half3 kD = (1.0h - kS) * (1.0h - metallic);
                half3 diffuse = kD * albedo / PI;

                half attenuation = lightData.distanceAttenuation * lightData.shadowAttenuation;
                half3 radiance = lightData.color * attenuation;

                return (diffuse + specular) * radiance * NdotL;
            }

            // IBL：
            // 使用球谐环境光作为漫反射环境项，
            // 使用反射探针 / 天空盒的 GlossyEnvironmentReflection 作为镜面环境项。
            half3 EvaluateIBL(
                half3 albedo,
                half3 normalWS,
                half3 viewDirWS,
                half metallic,
                half smoothness)
            {
                half roughness = max(1.0h - smoothness, 0.04h);
                half NdotV = saturate(dot(normalWS, viewDirWS));
                half3 F0 = lerp(half3(0.04h, 0.04h, 0.04h), albedo, metallic);

                // IBL 一般也会使用 Fresnel 来平衡漫反射和镜面反射占比。
                half3 fresnel = FresnelSchlick(NdotV, F0);
                half3 kS = fresnel;
                half3 kD = (1.0h - kS) * (1.0h - metallic);

                // 漫反射环境光：来自 SH。
                half3 diffuseIBL = SampleSH(normalWS) * albedo * kD;

                // 镜面环境光：来自反射向量采样环境。
                half3 reflectDirWS = reflect(-viewDirWS, normalWS);
                half3 specularIBL =
                    GlossyEnvironmentReflection(reflectDirWS, roughness, 1.0h).rgb * fresnel;

                return (diffuseIBL + specularIBL) * _IBLStrength;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 注意：
                // 能运行到这里，说明 stencil 已经通过。
                // 也就是“这个像素属于当前模板窗口”。

                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = baseTex.rgb * _BaseColor.rgb;

                half3 normalWS = GetSurfaceNormal(input);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));

                // 主光源直接光照。
                Light mainLight = GetMainLight(input.shadowCoord);
                half3 directLighting = EvaluateDirectPBR(
                    mainLight,
                    albedo,
                    normalWS,
                    viewDirWS,
                    _Metallic,
                    _Smoothness
                );

              

                // IBL 环境光照。
                half3 indirectLighting = EvaluateIBL(
                    albedo,
                    normalWS,
                    viewDirWS,
                    _Metallic,
                    _Smoothness
                );

                half3 finalColor = directLighting + indirectLighting;
                return half4(finalColor, 1.0h);
            }
            ENDHLSL
        }
    }
}
