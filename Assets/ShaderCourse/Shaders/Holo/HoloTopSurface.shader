Shader "ShaderCourse/Holo/HoloTopSurface"
{
    Properties
    {
        [MainTexture] _HoloBaseMap ("Base Color", 2D) = "white" {}
        [Normal] _HoloNormalMap ("Normal Map", 2D) = "bump" {}
        _HoloMaskMap ("Mask (R:Metallic G:AO B:Emission A:Roughness)", 2D) = "white" {}

        [MainColor] _BaseColor ("Base Tint", Color) = (0.18, 0.45, 0.72, 1)
        _EmissionColor ("Emission Color", Color) = (0.33, 0.85, 1.0, 1.0)

        _BaseContribution ("Base Contribution", Range(0, 1)) = 0.35
        _BaseFloor ("Base Floor", Range(0, 1)) = 0.08
        _BaseDesaturate ("Base Desaturate", Range(0, 1)) = 0.15
        _EmissionIntensity ("Emission Intensity", Range(0, 12)) = 4.5
        _NormalScale ("Normal Scale", Range(0, 2)) = 1
        _EdgeBoost ("Edge Boost", Range(0, 6)) = 1.8
        _FresnelPower ("Fresnel Power", Range(0.25, 8)) = 3.2
        _SpecBoost ("Spec Boost", Range(0, 4)) = 1.0
        _EmissionMaskContrast ("Emission Mask Contrast", Range(0.25, 4)) = 1.6
        _EmissionThreshold ("Emission Threshold", Range(0, 1)) = 0.18
        _TopOnly ("Top Only", Range(0, 1)) = 0.85
        _TopNormalDotMin ("Top Normal Dot Min", Range(-1, 1)) = 0.35
        _EdgeWidth ("Edge Width", Range(0.001, 0.25)) = 0.045
        _EdgeIntensity ("Edge Intensity", Range(0, 4)) = 1.2
        _PanelDepthFade ("Panel Depth Fade", Range(0, 4)) = 1.4
        _DepthFadeCenter ("Depth Fade Center (Object Y)", Float) = 0.0
        _PanelFill ("Panel Fill", Range(0, 2)) = 0.35

        _ScanAngle ("Scan Angle", Range(-180, 180)) = 45
        _ScanTiling ("Scan Tiling", Range(1, 100)) = 24
        _ScanSpeed ("Scan Speed", Range(0, 10)) = 1.6
        _ScanWidth ("Scan Width", Range(0.01, 0.8)) = 0.2
        _ScanBoost ("Scan Boost", Range(0, 4)) = 1.2
        _LineBoost ("Line Boost", Range(0, 2)) = 0.55

        _FlickerSpeed ("Flicker Speed", Range(0, 24)) = 8
        _NoiseTiling ("Noise Tiling", Range(1, 256)) = 42
        _Alpha ("Alpha", Range(0, 2)) = 0.85
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent+20"
        }

        Pass
        {
            Name "HoloTopSurface"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha One
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _HoloBaseMap_ST;
                float4 _HoloMaskMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _BaseContribution;
                half _BaseFloor;
                half _BaseDesaturate;
                half _EmissionIntensity;
                half _NormalScale;
                half _EdgeBoost;
                half _FresnelPower;
                half _SpecBoost;
                half _EmissionMaskContrast;
                half _EmissionThreshold;
                half _TopOnly;
                half _TopNormalDotMin;
                half _EdgeWidth;
                half _EdgeIntensity;
                half _PanelDepthFade;
                half _DepthFadeCenter;
                half _PanelFill;
                half _ScanAngle;
                half _ScanTiling;
                half _ScanSpeed;
                half _ScanWidth;
                half _ScanBoost;
                half _LineBoost;
                half _FlickerSpeed;
                half _NoiseTiling;
                half _Alpha;
            CBUFFER_END

            TEXTURE2D(_HoloBaseMap);
            SAMPLER(sampler_HoloBaseMap);
            TEXTURE2D(_HoloNormalMap);
            SAMPLER(sampler_HoloNormalMap);
            TEXTURE2D(_HoloMaskMap);
            SAMPLER(sampler_HoloMaskMap);

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
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float2 uvBase : TEXCOORD3;
                float2 uvMask : TEXCOORD4;
                float3 positionOS : TEXCOORD5;
            };

            float Hash12(float2 p)
            {
                p = frac(p * float2(0.1031, 0.1030));
                p += dot(p, p.yx + 33.33);
                return frac((p.x + p.y) * p.x);
            }

            half3 UnpackNormalRG(half4 packed, half scale)
            {
                half2 xy = (packed.xy * 2.0h - 1.0h) * scale;
                half z = sqrt(saturate(1.0h - dot(xy, xy)));
                return normalize(half3(xy, z));
            }

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs nrmInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                output.normalWS = normalize(nrmInputs.normalWS);
                output.tangentWS = float4(normalize(nrmInputs.tangentWS), input.tangentOS.w);
                output.uvBase = TRANSFORM_TEX(input.uv, _HoloBaseMap);
                output.uvMask = TRANSFORM_TEX(input.uv, _HoloMaskMap);
                output.positionOS = input.positionOS.xyz;
                return output;
            }

            half3 GetNormalWS(Varyings input)
            {
                half3 normalTS = UnpackNormalRG(SAMPLE_TEXTURE2D(_HoloNormalMap, sampler_HoloNormalMap, input.uvBase), _NormalScale);

                half3 tangentWS = normalize(input.tangentWS.xyz);
                half tangentSign = input.tangentWS.w * GetOddNegativeScale();
                half3 bitangentWS = normalize(cross(input.normalWS, tangentWS) * tangentSign);
                half3x3 tbn = half3x3(tangentWS, bitangentWS, input.normalWS);
                return normalize(TransformTangentToWorld(normalTS, tbn));
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 baseTex = SAMPLE_TEXTURE2D(_HoloBaseMap, sampler_HoloBaseMap, input.uvBase);
                half4 maskTex = SAMPLE_TEXTURE2D(_HoloMaskMap, sampler_HoloMaskMap, input.uvMask);

                half metallic = saturate(maskTex.r);
                half ao = saturate(maskTex.g);
                half emissionMask = saturate(maskTex.b);
                half roughness = saturate(maskTex.a);
                half smoothness = 1.0h - roughness;

                half3 normalWS = GetNormalWS(input);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
                Light mainLight = GetMainLight();
                half3 lightDirWS = normalize(mainLight.direction);
                half3 halfDirWS = SafeNormalize(viewDirWS + lightDirWS);

                half NdotL = saturate(dot(normalWS, lightDirWS));
                half NdotH = saturate(dot(normalWS, halfDirWS));

                half specPower = lerp(12.0h, 96.0h, smoothness);
                half specular = pow(NdotH, specPower) * lerp(0.08h, 1.0h, metallic) * _SpecBoost;

                half luminance = dot(baseTex.rgb, half3(0.299h, 0.587h, 0.114h));
                half3 baseTinted = baseTex.rgb * _BaseColor.rgb;
                half3 albedo = lerp(baseTinted, luminance.xxx, _BaseDesaturate);

                half topMask = smoothstep(_TopNormalDotMin, 1.0h, normalWS.y);
                half2 panelUv = input.uvMask;
                half2 edgeDist = min(panelUv, 1.0h - panelUv);
                half edgeMask = 1.0h - smoothstep(_EdgeWidth, _EdgeWidth * 2.2h, min(edgeDist.x, edgeDist.y));
                half depthFade = saturate(exp(-abs(input.positionOS.y - _DepthFadeCenter) * _PanelDepthFade));

                emissionMask = smoothstep(_EmissionThreshold, 1.0h, pow(emissionMask, _EmissionMaskContrast));
                half panelMask = lerp(1.0h, topMask * depthFade, _TopOnly);

                half3 litBase = albedo * (_BaseFloor + NdotL * 0.25h) * ao * _BaseContribution * panelMask;
                litBase += specular * mainLight.color * panelMask;

                half fresnel = pow(saturate(1.0h - dot(normalWS, viewDirWS)), _FresnelPower);

                half angleRad = radians(_ScanAngle);
                half2 scanDir = normalize(half2(cos(angleRad), sin(angleRad)));
                half2 centeredUv = input.uvMask - 0.5h;
                half scanCoord = dot(centeredUv, scanDir);
                half sweep = frac(scanCoord * _ScanTiling - _Time.y * _ScanSpeed);
                half scanBand = smoothstep(0.0h, _ScanWidth, sweep) * (1.0h - smoothstep(_ScanWidth, _ScanWidth + 0.22h, sweep));
                half scanLines = 0.5h + 0.5h * sin(scanCoord * _ScanTiling * TWO_PI - _Time.y * _ScanSpeed * TWO_PI);

                float2 noiseCell = floor(input.positionWS.xz * _NoiseTiling) + floor(_Time.y * _FlickerSpeed);
                half flicker = lerp(0.82h, 1.18h, Hash12(noiseCell));

                half emissiveMod = (1.0h + scanBand * _ScanBoost + scanLines * _LineBoost) * (1.0h + fresnel * _EdgeBoost) * flicker;
                half panelFill = _PanelFill * panelMask * depthFade * (0.65h + scanBand * 0.9h + scanLines * 0.25h);
                half edgeGlow = edgeMask * _EdgeIntensity;
                half3 emissive = _EmissionColor.rgb * _EmissionIntensity * (panelMask * emissionMask * emissiveMod + edgeGlow + panelFill);

                half3 finalColor = litBase + emissive;
                half alpha = saturate((panelMask * (emissionMask + panelFill + edgeGlow) + fresnel * 0.12h) * _Alpha) * _EmissionColor.a;

                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}
