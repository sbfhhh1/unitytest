Shader "ShaderCourse/Holo/HoloVolumeBeams"
{
    Properties
    {
        [Header(Main)]
        _MaskMap ("Mask (R:Metallic G:AO B:Emission A:Roughness)", 2D) = "white" {}
        _BeamColor ("Beam Color", Color) = (0.35, 0.78, 1.0, 1.0)
        _Intensity ("Intensity", Range(0, 32)) = 8
        _Alpha ("Alpha", Range(0, 2)) = 1.05

        [Header(Mesh Beam Shape)]
        _ObjectXZScale ("Object XZ Scale", Float) = 2.1
        _EdgeThreshold ("Edge Threshold", Range(0, 1)) = 0.42
        _EdgeSoftness ("Edge Softness", Range(0.001, 0.5)) = 0.08
        _CornerThreshold ("Corner Threshold", Range(0, 1)) = 0.18
        _CornerSoftness ("Corner Softness", Range(0.001, 0.5)) = 0.12
        _TopNormalThreshold ("Top Normal Threshold", Range(-1, 1)) = 0.15
        _HeightStart ("Height Start", Float) = 2.02
        _HeightSoftness ("Height Softness", Range(0.001, 0.3)) = 0.06
        _StripeDensity ("Stripe Density", Range(1, 32)) = 9
        _StripeWidth ("Stripe Width", Range(0.01, 0.45)) = 0.14
        _StripeEdgeSoftness ("Stripe Edge Softness", Range(0.01, 1)) = 0.28
        _StripeScroll ("Stripe Scroll", Range(0, 8)) = 1.3
        _BeamSoftAdd ("Surface Fill", Range(0, 2)) = 0.28
        _FresnelPower ("Fresnel Power", Range(0.5, 8)) = 2.8
        _FresnelBoost ("Fresnel Boost", Range(0, 4)) = 1.2

        [Header(Grid Overlay)]
        _GridTiling ("Grid Tiling", Range(2, 80)) = 26
        _GridWidth ("Grid Width", Range(0.005, 0.2)) = 0.03
        _GridSpeed ("Grid Speed", Range(0, 8)) = 1.4
        _GridIntensity ("Grid Intensity", Range(0, 4)) = 0.85
        _GridAngle ("Grid Angle", Range(-180, 180)) = 35

        [Header(Top Breakup)]
        _TopFadeStart ("Top Fade Start", Float) = 2.2
        _TopFadeSoftness ("Top Fade Softness", Range(0.01, 0.3)) = 0.12
        _BreakupTiling ("Breakup Tiling", Range(1, 40)) = 9
        _BreakupStrength ("Breakup Strength", Range(0, 1)) = 0.35

        [Header(Mask Influence)]
        _UseTriplanarMask ("Use Triplanar Mask", Range(0, 1)) = 1
        _TriplanarScale ("Triplanar Scale", Float) = 1.6
        _TriplanarSharpness ("Triplanar Sharpness", Range(1, 16)) = 8
        _MaskInfluence ("Mask Influence", Range(0, 1)) = 0.55

        [Header(Animation)]
        _FlickerSpeed ("Flicker Speed", Range(0, 20)) = 5
        _PulseStrength ("Pulse Strength", Range(0, 1)) = 0.14
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent+50"
        }

        Pass
        {
            Name "HoloMeshBeams"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha One
            ZWrite Off
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MaskMap_ST;
                half4 _BeamColor;
                half _Intensity;
                half _Alpha;
                half _ObjectXZScale;
                half _EdgeThreshold;
                half _EdgeSoftness;
                half _CornerThreshold;
                half _CornerSoftness;
                half _TopNormalThreshold;
                half _HeightStart;
                half _HeightSoftness;
                half _StripeDensity;
                half _StripeWidth;
                half _StripeEdgeSoftness;
                half _StripeScroll;
                half _BeamSoftAdd;
                half _FresnelPower;
                half _FresnelBoost;
                half _GridTiling;
                half _GridWidth;
                half _GridSpeed;
                half _GridIntensity;
                half _GridAngle;
                half _TopFadeStart;
                half _TopFadeSoftness;
                half _BreakupTiling;
                half _BreakupStrength;
                half _UseTriplanarMask;
                half _TriplanarScale;
                half _TriplanarSharpness;
                half _MaskInfluence;
                half _FlickerSpeed;
                half _PulseStrength;
            CBUFFER_END

            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MaskMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float3 positionOS : TEXCOORD3;
                float3 normalOS : TEXCOORD4;
                float2 uv : TEXCOORD5;
            };

            float Hash12(float2 p)
            {
                p = frac(p * float2(0.1031, 0.1030));
                p += dot(p, p.yx + 19.19);
                return frac((p.x + p.y) * p.x);
            }

            float Noise21(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = Hash12(i);
                float b = Hash12(i + float2(1.0, 0.0));
                float c = Hash12(i + float2(0.0, 1.0));
                float d = Hash12(i + float2(1.0, 1.0));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float Fbm21(float2 p)
            {
                float v = 0.0;
                float a = 0.5;
                v += Noise21(p) * a; p = p * 2.03 + 7.13; a *= 0.5;
                v += Noise21(p) * a; p = p * 2.01 + 3.17; a *= 0.5;
                v += Noise21(p) * a; p = p * 2.02 + 5.91; a *= 0.5;
                v += Noise21(p) * a;
                return v;
            }

            float SampleProceduralNoiseTex(float2 uv)
            {
                float n0 = Fbm21(uv);
                float n1 = Fbm21(uv * 1.9 + 13.7);
                float n2 = Fbm21(uv * 3.1 - 7.4);
                return (n0 * 0.55 + n1 * 0.3 + n2 * 0.15);
            }

            float SdRoundedRect(float2 p, float2 b, float r)
            {
                float2 q = abs(p) - b + r;
                return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
            }

            float RoundedRectLine(float2 p, float2 size, float radius, float width)
            {
                float d = abs(SdRoundedRect(p, size, radius));
                return 1.0 - smoothstep(width, width * 2.0, d);
            }

            float SampleMaskEmissionUV(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, uv).b;
            }

            float SampleMaskEmissionTriplanar(float3 positionOS, float3 normalOS)
            {
                float3 blend = pow(abs(normalize(normalOS)), _TriplanarSharpness);
                blend /= max(blend.x + blend.y + blend.z, 1e-4);

                float scale = max(_TriplanarScale, 1e-4);
                float2 uvX = positionOS.zy * scale;
                float2 uvY = positionOS.xz * scale;
                float2 uvZ = positionOS.xy * scale;

                float xSample = SampleMaskEmissionUV(uvX);
                float ySample = SampleMaskEmissionUV(uvY);
                float zSample = SampleMaskEmissionUV(uvZ);
                return xSample * blend.x + ySample * blend.y + zSample * blend.z;
            }

            float ComputeAnchorMask(float3 positionOS, float3 normalOS, float2 uv)
            {
                float topMask = smoothstep(_TopNormalThreshold, 1.0, normalOS.y);
                float heightMask = smoothstep(_HeightStart - _HeightSoftness, _HeightStart + _HeightSoftness, positionOS.y);
                float edgeNoise = (Fbm21(uv * 9.0 + _Time.y * 0.08) - 0.5) * 0.06;
                float panelSdf = SdRoundedRect(uv - 0.5, float2(0.33, 0.33), 0.09);
                float panelMask = 1.0 - smoothstep(0.0, 0.06, panelSdf + edgeNoise);
                return panelMask * topMask * heightMask;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                output.normalWS = normalize(normalInputs.normalWS);
                output.viewDirWS = SafeNormalize(GetWorldSpaceViewDir(posInputs.positionWS));
                output.positionOS = input.positionOS.xyz;
                output.normalOS = normalize(input.normalOS);
                output.uv = TRANSFORM_TEX(input.uv, _MaskMap);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float anchorMask = ComputeAnchorMask(input.positionOS, input.normalOS, input.uv);

                float maskEmission = lerp(
                    SampleMaskEmissionUV(input.uv),
                    SampleMaskEmissionTriplanar(input.positionOS, input.normalOS),
                    saturate(_UseTriplanarMask)
                );

                float pulse = lerp(
                    1.0 - _PulseStrength,
                    1.0 + _PulseStrength,
                    sin(_Time.y * _FlickerSpeed + input.positionOS.y * 6.0) * 0.5 + 0.5
                );

                float fresnel = pow(saturate(1.0 - dot(normalize(input.normalWS), normalize(input.viewDirWS))), _FresnelPower);
                float breakup = Hash12(floor(input.positionOS.xz * _BreakupTiling) + floor(_Time.y * 1.5));
                float topFade = 1.0 - smoothstep(
                    _TopFadeStart - _TopFadeSoftness,
                    _TopFadeStart + _TopFadeSoftness,
                    input.positionOS.y + (breakup - 0.5) * _BreakupStrength
                );

                float angleRad = radians(_GridAngle);
                float2x2 rot = float2x2(cos(angleRad), -sin(angleRad), sin(angleRad), cos(angleRad));

                float2 auroraUv = mul(rot, input.uv - 0.5);
                auroraUv = float2(
                    auroraUv.x * 2.15 + SampleProceduralNoiseTex(float2(auroraUv.y * 2.6, _Time.y * 0.14)) * 0.38,
                    auroraUv.y * 1.9 - _Time.y * (_StripeScroll * 0.22)
                );
                float stripeSoft = max(0.02, _StripeEdgeSoftness);
                float edgeWarpA = (SampleProceduralNoiseTex(auroraUv * 1.8 + float2(0.0, _Time.y * 0.08)) - 0.5) * stripeSoft;
                float edgeWarpB = (SampleProceduralNoiseTex(auroraUv * 2.7 + 9.3 - float2(0.0, _Time.y * 0.11)) - 0.5) * stripeSoft;
                float centerA = 0.22 + edgeWarpA;
                float centerB = -0.18 + edgeWarpB;
                float distA = abs(auroraUv.x - centerA);
                float distB = abs(auroraUv.x - centerB);
                float falloffA = 1.0 - smoothstep(0.02, 0.02 + stripeSoft * 1.35, distA);
                float falloffB = 1.0 - smoothstep(0.03, 0.03 + stripeSoft * 1.55, distB);
                float bodyA = SampleProceduralNoiseTex(auroraUv * 2.1 + float2(0.0, _Time.y * 0.06));
                float bodyB = SampleProceduralNoiseTex(auroraUv * 3.0 + 5.4 - float2(0.0, _Time.y * 0.09));
                float auroraBandA = falloffA * smoothstep(0.36, 0.82, bodyA);
                float auroraBandB = falloffB * smoothstep(0.32, 0.8, bodyB);
                float auroraWisp = saturate(SampleProceduralNoiseTex(float2(input.uv.x * 6.4, input.uv.y * 2.2 - _Time.y * 0.18)) * 1.6 - 0.42);
                float aurora = (auroraBandA * 0.95 + auroraBandB * 0.72) * anchorMask;
                aurora *= auroraWisp * lerp(0.45, 1.0, maskEmission) * pulse;

                float2 rectUvA = mul(rot, input.uv - 0.5) * (_GridTiling * 0.22);
                rectUvA.y -= _Time.y * (_GridSpeed * 0.22);
                float2 rectCellA = floor(rectUvA);
                float2 rectLocalA = frac(rectUvA) - 0.5;
                float rectHashA = Hash12(rectCellA + 3.7);
                float2 rectSizeA = float2(lerp(0.08, 0.22, rectHashA), lerp(0.05, 0.18, Hash12(rectCellA + 7.1)));
                float rectRadiusA = min(rectSizeA.x, rectSizeA.y) * 0.45;
                float rectLineA = RoundedRectLine(rectLocalA, rectSizeA, rectRadiusA, _GridWidth * 0.6);

                float2 rectUvB = mul(rot, input.uv - 0.5 + float2(0.13, -0.07)) * (_GridTiling * 0.28);
                rectUvB.y -= _Time.y * (_GridSpeed * 0.31);
                float2 rectCellB = floor(rectUvB);
                float2 rectLocalB = frac(rectUvB) - 0.5;
                float rectHashB = Hash12(rectCellB + 13.4);
                float2 rectSizeB = float2(lerp(0.05, 0.16, rectHashB), lerp(0.06, 0.24, Hash12(rectCellB + 17.2)));
                float rectRadiusB = min(rectSizeB.x, rectSizeB.y) * 0.42;
                float rectLineB = RoundedRectLine(rectLocalB, rectSizeB, rectRadiusB, _GridWidth * 0.45);

                float rectSweep = sin((input.uv.y * 9.0) - _Time.y * (_GridSpeed * 1.3)) * 0.5 + 0.5;
                float rectGlow = (rectLineA + rectLineB) * rectSweep * (_GridIntensity * 1.15) * anchorMask;
                rectGlow *= lerp(0.35, 1.0, maskEmission);

                float2 particleUv = input.uv * float2(12.0, 18.0);
                particleUv.y -= _Time.y * 1.8;
                float2 particleCell = floor(particleUv);
                float2 particleLocal = frac(particleUv) - 0.5;
                float particleKeep = step(0.72, Hash12(particleCell + 21.7));
                float2 particleOffset = float2(Hash12(particleCell + 2.1), Hash12(particleCell + 5.4)) - 0.5;
                particleLocal -= particleOffset * 0.35;
                float particleSize = lerp(0.035, 0.095, Hash12(particleCell + 9.8));
                float squareDist = max(abs(particleLocal.x), abs(particleLocal.y));
                float particle = (1.0 - smoothstep(particleSize, particleSize * 1.8, squareDist)) * particleKeep;
                float particleTwinkle = sin(_Time.y * 6.0 + Hash12(particleCell + 14.2) * 9.0) * 0.5 + 0.5;
                float particleRiseFade = 1.0 - smoothstep(0.35, 0.95, frac(particleUv.y * 0.12));
                float particleGlow = particle * particleTwinkle * particleRiseFade * anchorMask * 1.6;

                float softFill = anchorMask * _BeamSoftAdd * 0.45 * (0.45 + 0.55 * pulse);
                float glow = (aurora + rectGlow + particleGlow + softFill + fresnel * _FresnelBoost * anchorMask * 0.28) * topFade;

                half3 color = _BeamColor.rgb * glow * _Intensity;
                half alpha = saturate((glow * _Alpha) + fresnel * 0.08) * _BeamColor.a;
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}
