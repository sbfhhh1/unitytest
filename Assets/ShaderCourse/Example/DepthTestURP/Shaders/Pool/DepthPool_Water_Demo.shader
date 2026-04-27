Shader "ShaderCourse/DepthPool_Water_Demo"
{
    Properties
    {
        // Overall tint multiplier for quick lookdev adjustment.
        [MainColor] _BaseColor ("Base Tint", Color) = (0.85, 0.98, 1.00, 1.00)
        [MainTexture] _BaseMap ("Base Disturbance", 2D) = "white" {}

        // Depth-driven water colors.
        _ShallowColor ("Shallow Color", Color) = (0.34, 0.76, 0.92, 1.00)
        _DeepColor ("Deep Color", Color) = (0.05, 0.22, 0.37, 1.00)
        _FoamColor ("Foam Color", Color) = (0.92, 0.98, 1.00, 0.95)
        _ReflectionTint ("Reflection Tint", Color) = (0.72, 0.90, 1.00, 1.00)

        // Depth texture controls.
        _DepthDistance ("Depth Blend Distance", Range(0.05, 8.0)) = 2.2
        _FoamDistance ("Foam Distance", Range(0.01, 2.0)) = 0.35
        _FoamStrength ("Foam Strength", Range(0, 3)) = 1.2
        _Transparency ("Base Transparency", Range(0, 1)) = 0.62

        // Vertex wave controls.
        _WaveAmplitude ("Wave Amplitude", Range(0, 0.5)) = 0.08
        _WaveFrequency ("Wave Frequency", Range(0.1, 8.0)) = 2.6
        _WaveSecondaryFrequency ("Wave Secondary Frequency", Range(0.1, 12.0)) = 4.3
        _WaveSpeed ("Wave Speed", Range(0, 5.0)) = 1.1

        // Normal flow and fresnel controls.
        [Toggle(_NORMALMAP)] _EnableNormalMap ("Enable Normal Map", Float) = 0
        [Normal] _NormalMap ("Water Normal", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Range(0, 2)) = 0.8
        _NormalTiling ("Normal Tiling", Range(0.1, 20)) = 5.0
        _NormalSpeed ("Normal Speed", Range(0, 2)) = 0.2
        _FresnelPower ("Fresnel Power", Range(0.5, 8)) = 4.0
        _FresnelStrength ("Fresnel Strength", Range(0, 2)) = 1.0

        // Basic PBR parameters kept for course continuity.
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.92
        _IBLStrength ("IBL Strength", Range(0, 2)) = 1.15
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
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            Cull Back
            ZWrite Off
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma shader_feature_local_fragment _NORMALMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShallowColor;
                half4 _DeepColor;
                half4 _FoamColor;
                half4 _ReflectionTint;
                half _DepthDistance;
                half _FoamDistance;
                half _FoamStrength;
                half _Transparency;
                half _WaveAmplitude;
                half _WaveFrequency;
                half _WaveSecondaryFrequency;
                half _WaveSpeed;
                half _NormalScale;
                half _NormalTiling;
                half _NormalSpeed;
                half _FresnelPower;
                half _FresnelStrength;
                half _Metallic;
                half _Smoothness;
                half _IBLStrength;
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
                float4 screenPos : TEXCOORD5;
                float waterEyeDepth : TEXCOORD6;
            };

            void ApplyWave(inout float3 positionOS, out float3 waveNormalOS)
            {
                float timeValue = _Time.y * _WaveSpeed;

                float wavePrimary = sin(positionOS.x * _WaveFrequency + timeValue);
                float waveSecondary = cos(positionOS.z * _WaveSecondaryFrequency + timeValue * 1.27);
                float waveMix = (wavePrimary + waveSecondary) * 0.5;
                positionOS.y += waveMix * _WaveAmplitude;

                float dhdx = cos(positionOS.x * _WaveFrequency + timeValue) * _WaveFrequency * _WaveAmplitude * 0.5;
                float dhdz = -sin(positionOS.z * _WaveSecondaryFrequency + timeValue * 1.27) * _WaveSecondaryFrequency * _WaveAmplitude * 0.5;
                waveNormalOS = normalize(float3(-dhdx, 1.0, -dhdz));
            }

            Varyings vert(Attributes input)
            {
                Varyings output;

                float3 positionOS = input.positionOS.xyz;
                float3 waveNormalOS;
                ApplyWave(positionOS, waveNormalOS);

                VertexPositionInputs positionInputs = GetVertexPositionInputs(positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(waveNormalOS, input.tangentOS);

                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = float4(normalInputs.tangentWS.xyz, input.tangentOS.w);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.shadowCoord = GetShadowCoord(positionInputs);
                output.screenPos = ComputeScreenPos(positionInputs.positionCS);
                output.waterEyeDepth = -TransformWorldToView(positionInputs.positionWS).z;
                return output;
            }

            half3 GetSurfaceNormal(Varyings input)
            {
                half3 normalWS = normalize(input.normalWS);

                #if defined(_NORMALMAP)
                    float2 flowA = input.uv * _NormalTiling + float2(_Time.y * _NormalSpeed, _Time.y * _NormalSpeed * 0.73);
                    float2 flowB = input.uv * (_NormalTiling * 1.37) + float2(-_Time.y * _NormalSpeed * 0.84, _Time.y * _NormalSpeed);

                    half3 normalA = UnpackNormalScale(
                        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, flowA),
                        _NormalScale
                    );
                    half3 normalB = UnpackNormalScale(
                        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, flowB),
                        _NormalScale * 0.65h
                    );

                    half3 normalTS = normalize(half3(normalA.xy + normalB.xy, normalA.z * normalB.z));

                    half3 tangentWS = normalize(input.tangentWS.xyz);
                    half tangentSign = input.tangentWS.w * GetOddNegativeScale();
                    half3 bitangentWS = normalize(cross(normalWS, tangentWS) * tangentSign);
                    half3x3 tbn = half3x3(tangentWS, bitangentWS, normalWS);
                    normalWS = normalize(TransformTangentToWorld(normalTS, tbn));
                #endif

                return normalWS;
            }

            half3 FresnelSchlick(half cosTheta, half3 F0)
            {
                return F0 + (1.0h - F0) * Pow4(1.0h - cosTheta) * (1.0h - cosTheta);
            }

            half DistributionGGX(half NdotH, half roughness)
            {
                half a = roughness * roughness;
                half a2 = a * a;
                half denom = NdotH * NdotH * (a2 - 1.0h) + 1.0h;
                return a2 / max(PI * denom * denom, 0.0001h);
            }

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

                half roughness = max(1.0h - smoothness, 0.04h);
                half3 F0 = lerp(half3(0.04h, 0.04h, 0.04h), albedo, metallic);

                half3 F = FresnelSchlick(VdotH, F0);
                half D = DistributionGGX(NdotH, roughness);
                half G = GeometrySmith(NdotV, NdotL, roughness);

                half3 numerator = D * G * F;
                half denominator = max(4.0h * NdotV * NdotL, 0.0001h);
                half3 specular = numerator / denominator;

                half3 kS = F;
                half3 kD = (1.0h - kS) * (1.0h - metallic);
                half3 diffuse = kD * albedo / PI;

                half attenuation = lightData.distanceAttenuation * lightData.shadowAttenuation;
                half3 radiance = lightData.color * attenuation;
                return (diffuse + specular) * radiance * NdotL;
            }

            half3 EvaluateIBL(
                half3 normalWS,
                half3 viewDirWS,
                half3 reflectionTint,
                half smoothness)
            {
                half roughness = max(1.0h - smoothness, 0.04h);
                half3 reflectDirWS = reflect(-viewDirWS, normalWS);
                return GlossyEnvironmentReflection(reflectDirWS, roughness, 1.0h).rgb * reflectionTint * _IBLStrength;
            }

            void EvaluateDepthWater(
                Varyings input,
                out half depthLerp,
                out half foamMask,
                out half sceneEyeDepth)
            {
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                // 使用更明确的局部变量名，避免与 URP 头文件中的宏展开或内部命名产生冲突。
                real sampledSceneDepth = SampleSceneDepth(screenUV);
                sceneEyeDepth = LinearEyeDepth(sampledSceneDepth, _ZBufferParams);

                half depthDifference = max(sceneEyeDepth - input.waterEyeDepth, 0.0h);
                depthLerp = saturate(depthDifference / max(_DepthDistance, 0.0001h));

                half foamRange = saturate(depthDifference / max(_FoamDistance, 0.0001h));
                foamMask = saturate((1.0h - foamRange) * _FoamStrength);
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 normalWS = GetSurfaceNormal(input);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));

                half depthLerp;
                half foamMask;
                half sceneEyeDepth;
                EvaluateDepthWater(input, depthLerp, foamMask, sceneEyeDepth);

                half3 waterBodyColor = lerp(_ShallowColor.rgb, _DeepColor.rgb, depthLerp);
                waterBodyColor *= _BaseColor.rgb * baseTex.rgb;

                half NdotV = saturate(dot(normalWS, viewDirWS));
                half fresnelMask = pow(1.0h - NdotV, _FresnelPower) * _FresnelStrength;

                Light mainLight = GetMainLight(input.shadowCoord);
                half3 directLighting = EvaluateDirectPBR(
                    mainLight,
                    waterBodyColor,
                    normalWS,
                    viewDirWS,
                    _Metallic,
                    _Smoothness
                );

                #if defined(_ADDITIONAL_LIGHTS)
                    uint additionalLightsCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < additionalLightsCount; ++lightIndex)
                    {
                        Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);
                        directLighting += EvaluateDirectPBR(
                            additionalLight,
                            waterBodyColor,
                            normalWS,
                            viewDirWS,
                            _Metallic,
                            _Smoothness
                        );
                    }
                #endif

                half3 reflectionColor = EvaluateIBL(
                    normalWS,
                    viewDirWS,
                    _ReflectionTint.rgb,
                    _Smoothness
                );

                half3 bodyContribution = waterBodyColor * (0.45h + 0.35h * mainLight.shadowAttenuation);
                half3 fresnelReflection = reflectionColor * saturate(0.25h + fresnelMask);
                half3 foamColor = _FoamColor.rgb * foamMask;

                half3 finalColor = bodyContribution + directLighting * 0.28h + fresnelReflection + foamColor;
                half alpha = saturate(_Transparency + fresnelMask * 0.2h + foamMask * _FoamColor.a);

                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}
