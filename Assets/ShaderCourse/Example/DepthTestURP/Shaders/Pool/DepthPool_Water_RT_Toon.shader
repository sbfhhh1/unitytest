Shader "ShaderCourse/DepthPool_Water_RT_Toon"
{
    Properties
    {
        [MainColor] _BaseColor ("Base Tint", Color) = (0.90, 0.96, 1.00, 1.00)
        [MainTexture] _BaseMap ("Base Noise", 2D) = "white" {}

        _ShallowColor ("Shallow Color", Color) = (0.38, 0.84, 0.95, 1.00)
        _DeepColor ("Deep Color", Color) = (0.08, 0.28, 0.48, 1.00)
        _FoamColor ("Foam Color", Color) = (0.95, 0.99, 1.00, 1.00)
        _TrailColor ("Trail Color", Color) = (0.70, 0.97, 1.00, 1.00)
        _HighlightColor ("Highlight Color", Color) = (1.00, 1.00, 1.00, 1.00)
        _RimColor ("Rim Color", Color) = (0.76, 0.94, 1.00, 1.00)

        _DepthDistance ("Depth Blend Distance", Range(0.05, 8.0)) = 2.2
        _FoamDistance ("Edge Foam Distance", Range(0.01, 2.0)) = 0.35
        _FoamStrength ("Edge Foam Strength", Range(0, 3)) = 1.2
        _FoamNoiseScale ("Foam Noise Scale", Range(0, 1.5)) = 0.55
        _FoamNoiseTiling ("Foam Noise Tiling", Range(0.5, 30)) = 6.0
        _FoamNoiseSpeed ("Foam Noise Speed", Range(0, 3)) = 0.4
        _Transparency ("Base Transparency", Range(0, 1)) = 0.68

        _WaveAmplitude ("Wave Amplitude", Range(0, 0.5)) = 0.08
        _WaveFrequency ("Wave Frequency", Range(0.1, 8.0)) = 2.5
        _WaveSecondaryFrequency ("Wave Secondary Frequency", Range(0.1, 12.0)) = 4.0
        _WaveSpeed ("Wave Speed", Range(0, 5.0)) = 1.1

        [Toggle(_NORMALMAP)] _EnableNormalMap ("Enable Normal Map", Float) = 0
        [Normal] _NormalMap ("Water Normal", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Range(0, 2)) = 0.85
        _NormalTiling ("Normal Tiling", Range(0.1, 20)) = 5.0
        _NormalSpeed ("Normal Speed", Range(0, 2)) = 0.22

        _TrailRT ("Trail Render Texture", 2D) = "black" {}
        _TrailArea ("Trail Area MinX MinZ SizeX SizeZ", Vector) = (-5, -5, 10, 10)
        _TrailThreshold ("Trail Threshold", Range(0, 1)) = 0.12
        _TrailSoftness ("Trail Softness", Range(0.001, 0.5)) = 0.08
        _TrailStrength ("Trail Strength", Range(0, 3)) = 1.4
        _TrailFoamBoost ("Trail Foam Boost", Range(0, 3)) = 1.2
        _TrailDistortion ("Trail Distortion", Range(0, 1)) = 0.18

        _ShadowStep ("Shadow Step", Range(0, 1)) = 0.45
        _LightStep ("Light Step", Range(0, 1)) = 0.78
        _BandSoftness ("Band Softness", Range(0.001, 0.2)) = 0.04
        _ShadowStrength ("Shadow Strength", Range(0, 1)) = 0.55
        _SpecularSize ("Specular Size", Range(8, 128)) = 42
        _SpecularSoftness ("Specular Softness", Range(0.001, 0.2)) = 0.05
        _RimPower ("Rim Power", Range(0.5, 8)) = 3.6
        _RimThreshold ("Rim Threshold", Range(0, 1)) = 0.42
        _RimSoftness ("Rim Softness", Range(0.001, 0.4)) = 0.08
        _RimStrength ("Rim Strength", Range(0, 2)) = 0.7
        _AmbientStrength ("Ambient Strength", Range(0, 2)) = 0.8
        _AdditionalLightIntensity ("Additional Light Intensity", Range(0, 2)) = 0.65
        _AdditionalSpecularStrength ("Additional Specular Strength", Range(0, 2)) = 0.5
        _AdditionalRimStrength ("Additional Rim Strength", Range(0, 2)) = 0.6
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
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma shader_feature_local_fragment _NORMALMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShallowColor;
                half4 _DeepColor;
                half4 _FoamColor;
                half4 _TrailColor;
                half4 _HighlightColor;
                half4 _RimColor;
                float4 _TrailArea;
                half _DepthDistance;
                half _FoamDistance;
                half _FoamStrength;
                half _FoamNoiseScale;
                half _FoamNoiseTiling;
                half _FoamNoiseSpeed;
                half _Transparency;
                half _WaveAmplitude;
                half _WaveFrequency;
                half _WaveSecondaryFrequency;
                half _WaveSpeed;
                half _NormalScale;
                half _NormalTiling;
                half _NormalSpeed;
                half _TrailThreshold;
                half _TrailSoftness;
                half _TrailStrength;
                half _TrailFoamBoost;
                half _TrailDistortion;
                half _ShadowStep;
                half _LightStep;
                half _BandSoftness;
                half _ShadowStrength;
                half _SpecularSize;
                half _SpecularSoftness;
                half _RimPower;
                half _RimThreshold;
                half _RimSoftness;
                half _RimStrength;
                half _AmbientStrength;
                half _AdditionalLightIntensity;
                half _AdditionalSpecularStrength;
                half _AdditionalRimStrength;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_TrailRT);
            SAMPLER(sampler_TrailRT);
            float4 _TrailRT_TexelSize;

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
                float2 trailUV : TEXCOORD7;
                half3 vertexLight : TEXCOORD8;
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

            float2 GetTrailUV(float3 positionWS)
            {
                float2 areaSize = max(_TrailArea.zw, float2(0.0001, 0.0001));
                return (positionWS.xz - _TrailArea.xy) / areaSize;
            }

            half SampleTrailRaw(float2 trailUV)
            {
                if (any(trailUV < 0.0) || any(trailUV > 1.0))
                {
                    return 0.0h;
                }

                half4 trailTex = SAMPLE_TEXTURE2D(_TrailRT, sampler_TrailRT, trailUV);
                half luminance = dot(trailTex.rgb, half3(0.2126h, 0.7152h, 0.0722h));
                return max(trailTex.a, luminance);
            }

            half SampleTrailMask(float2 trailUV)
            {
                half rawTrail = SampleTrailRaw(trailUV);
                half trailMask = smoothstep(
                    _TrailThreshold - _TrailSoftness,
                    _TrailThreshold + _TrailSoftness,
                    rawTrail
                );
                return saturate(trailMask * _TrailStrength);
            }

            float2 SampleTrailGradient(float2 trailUV)
            {
                float2 texel = _TrailRT_TexelSize.xy;
                half left = SampleTrailRaw(trailUV - float2(texel.x, 0.0));
                half right = SampleTrailRaw(trailUV + float2(texel.x, 0.0));
                half down = SampleTrailRaw(trailUV - float2(0.0, texel.y));
                half up = SampleTrailRaw(trailUV + float2(0.0, texel.y));
                return float2(right - left, up - down);
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
                output.trailUV = GetTrailUV(positionInputs.positionWS);

                // 顶点光照（当像素光数量超过上限时，剩余光源降级为顶点光）
                output.vertexLight = 0;
                #if defined(_ADDITIONAL_LIGHTS_VERTEX)
                    half3 vertexLightColor = VertexLighting(
                        positionInputs.positionWS,
                        normalInputs.normalWS
                    );
                    output.vertexLight = vertexLightColor;
                #endif

                return output;
            }

            half3 GetSurfaceNormal(Varyings input, float2 trailGradient, half trailMask)
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

                half3 trailNormal = normalize(half3(-trailGradient.x * _TrailDistortion, 1.0h, -trailGradient.y * _TrailDistortion));
                normalWS = normalize(lerp(normalWS, trailNormal, saturate(trailMask * _TrailDistortion)));
                return normalWS;
            }

            void EvaluateDepthWater(
                Varyings input,
                out half depthLerp,
                out half foamMask,
                float2 foamNoiseUV)
            {
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                real sampledSceneDepth = SampleSceneDepth(screenUV);
                half sceneEyeDepth = LinearEyeDepth(sampledSceneDepth, _ZBufferParams);

                half depthDifference = max(sceneEyeDepth - input.waterEyeDepth, 0.0h);
                depthLerp = saturate(depthDifference / max(_DepthDistance, 0.0001h));

                // 用噪声扰动泡沫深度，让边缘不规则
                half foamNoise = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, foamNoiseUV).r;
                half noiseOffset = (foamNoise - 0.5h) * _FoamNoiseScale * _FoamDistance;
                half noisyDepth = depthDifference + noiseOffset;
                noisyDepth = max(noisyDepth, 0.0h);

                half foamRange = saturate(noisyDepth / max(_FoamDistance, 0.0001h));
                foamMask = saturate((1.0h - foamRange) * _FoamStrength);
            }

            half EvaluateToonBand(half ndotl)
            {
                half shadowBand = smoothstep(_ShadowStep - _BandSoftness, _ShadowStep + _BandSoftness, ndotl);
                half lightBand = smoothstep(_LightStep - _BandSoftness, _LightStep + _BandSoftness, ndotl);
                half toon = lerp(_ShadowStrength, 0.82h, shadowBand);
                toon = lerp(toon, 1.12h, lightBand);
                return toon;
            }

            half EvaluateSpecular(half3 normalWS, half3 lightDirWS, half3 viewDirWS)
            {
                half3 halfDirWS = SafeNormalize(lightDirWS + viewDirWS);
                half spec = pow(saturate(dot(normalWS, halfDirWS)), _SpecularSize);
                return smoothstep(1.0h - _SpecularSoftness, 1.0h, spec);
            }

            half EvaluateRim(half3 normalWS, half3 viewDirWS)
            {
                half rim = pow(1.0h - saturate(dot(normalWS, viewDirWS)), _RimPower);
                return smoothstep(_RimThreshold - _RimSoftness, _RimThreshold + _RimSoftness, rim) * _RimStrength;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half trailMask = SampleTrailMask(input.trailUV);
                float2 trailGradient = SampleTrailGradient(input.trailUV);
                half3 normalWS = GetSurfaceNormal(input, trailGradient, trailMask);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));

                half depthLerp;
                half edgeFoamMask;
                float2 foamNoiseUV = input.uv * _FoamNoiseTiling + float2(_Time.y * _FoamNoiseSpeed, _Time.y * _FoamNoiseSpeed * 0.61);
                EvaluateDepthWater(input, depthLerp, edgeFoamMask, foamNoiseUV);

                half trailFoamMask = saturate(trailMask * _TrailFoamBoost);
                half foamMask = saturate(max(edgeFoamMask, trailFoamMask));

                half3 depthColor = lerp(_ShallowColor.rgb, _DeepColor.rgb, depthLerp);
                half3 waterBodyColor = depthColor * _BaseColor.rgb * baseTex.rgb;
                waterBodyColor = lerp(waterBodyColor, _TrailColor.rgb, saturate(trailMask * 0.5h));

                Light mainLight = GetMainLight(input.shadowCoord);
                half3 lightDirWS = normalize(mainLight.direction);
                half mainNdotL = dot(normalWS, lightDirWS);
                half ndotl = saturate(mainNdotL);
                half toonBand = EvaluateToonBand(ndotl);
                half attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;

                half3 ambient = SampleSH(normalWS) * waterBodyColor * _AmbientStrength;
                half3 diffuse = waterBodyColor * toonBand * attenuation * mainLight.color;

                half additionalSpecularSum = 0.0h;
                half3 additionalRimSum = 0.0h;
                #if defined(_ADDITIONAL_LIGHTS)
                    uint additionalLightsCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < additionalLightsCount; ++lightIndex)
                    {
                        Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);
                        half addNdotL = dot(normalWS, additionalLight.direction);
                        half addNdotLSat = saturate(addNdotL);
                        half addAtten = additionalLight.distanceAttenuation * additionalLight.shadowAttenuation;
                        half3 lightColor = additionalLight.color * _AdditionalLightIntensity;

                        // 额外光源漫反射（卡通阶梯着色）
                        half addBand = EvaluateToonBand(addNdotLSat);
                        diffuse += waterBodyColor * addBand * addAtten * lightColor;

                        // 额外光源高光
                        half addSpec = EvaluateSpecular(normalWS, additionalLight.direction, viewDirWS);
                        additionalSpecularSum += addSpec * addAtten * _AdditionalSpecularStrength;

                        // 额外光源边缘光（背光越强，Rim越亮）
                        half addBacklit = saturate(-addNdotL);
                        additionalRimSum += lightColor * addBacklit * addAtten * _AdditionalRimStrength;
                    }
                #endif

                half specular = EvaluateSpecular(normalWS, lightDirWS, viewDirWS) * attenuation;
                half rim = EvaluateRim(normalWS, viewDirWS);

                // 基础边缘光（始终可见，仅依赖视角和法线）
                half3 baseRim = _RimColor.rgb * rim;

                // 光源驱动的额外边缘光（背光越强越亮）
                half mainBacklit = saturate(-mainNdotL) * attenuation;
                half3 lightRim = rim * (mainBacklit * mainLight.color + additionalRimSum);

                half3 rimColor = baseRim + lightRim;
                half3 vertexLightColor = input.vertexLight * waterBodyColor;
                half3 foamColor = _FoamColor.rgb * foamMask;
                half3 trailHighlight = _TrailColor.rgb * trailMask * 0.55h;
                half3 specColor = _HighlightColor.rgb * (specular + additionalSpecularSum);

                half3 finalColor = ambient + diffuse + vertexLightColor + foamColor + trailHighlight + specColor + rimColor;
                half alpha = saturate(_Transparency + foamMask * 0.22h + trailMask * 0.12h + rim * 0.08h);

                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}
