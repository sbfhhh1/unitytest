// ============================================================
//  HoloLootBox.shader
//  Unity 6.3  |  URP 17
//  Single Mesh (top Quad), Single Shader, all effects in one pass.
//
//  Effects (all visible simultaneously):
//    1. Rectangular blue border glow    -> UV edge falloff
//    2. Corner beam effect              -> corner highlight + vertical streak
//    3. Horizontal scan lines           -> UV.y scroll
//    4. Holographic grid               -> UV modulo
//    5. Random pixel scatter            -> Hash random on/off blocks
//    6. Large floating pixel blocks     -> second layer, independent frequency
//    7. Center emblem texture           -> optional, black bg white art
//    8. Center ripple wave              -> circular sin wave outward
//    9. Global breath & flicker         -> global sin modulation
//
//  Mesh setup:
//    . Top-face thin Quad, UV 0~1 covers entire top face
//    . Material -> Blend One One (additive), ZWrite Off
//    . No other Mesh needed, all effects rendered on this Quad
// ============================================================
Shader "Holo/LootBox"
{
    Properties
    {
        [Header(Color)]
        [HDR] _Color              ("Holo Main Color",    Color)          = (0.2, 0.7, 1.0, 1.0)
        _EmissionIntensity        ("Emission Intensity", Float)          = 2.5

        [Header(Border Rim)]
        _RimWidth                 ("Rim Width",          Float)          = 0.04
        _RimPow                   ("Rim Falloff Power",  Float)          = 1.5
        _RimIntensity             ("Rim Brightness",     Float)          = 5.0

        [Header(Corner Beams Simulated on Surface)]
        _BeamRadius               ("Beam Spot Radius",   Float)          = 0.18
        _BeamIntensity            ("Beam Brightness",    Float)          = 3.0
        _BeamStreakLength         ("Streak Length",       Float)          = 0.35
        _BeamStreakSharpness      ("Streak Sharpness",   Float)          = 6.0

        [Header(Vertical Rising Strips)]
        _ScanSpeed                ("Rise Speed",          Float)          = 0.6
        _ScanDensity              ("Column Count",        Float)          = 14.0
        _ScanBrightness           ("Strip Brightness",    Float)          = 0.55
        _ScanBandWidth            ("Band Height",         Float)          = 0.25

        [Header(Grid)]
        _GridSize                 ("Grid Density",       Float)          = 10.0
        _GridLineWidth            ("Grid Line Width",    Range(0.01,0.5))= 0.06
        _GridBrightness           ("Grid Brightness",   Float)          = 0.10

        [Header(Small Pixel Scatter)]
        _PixelDensity             ("Pixel Density",      Float)          = 22.0
        _PixelBrightness          ("Pixel Brightness",  Float)          = 0.45
        _PixelFlipFreq            ("Pixel Flicker Freq", Float)          = 3.5

        [Header(Large Floating Pixels)]
        _LargePixDensity          ("Large Pix Density",  Float)          = 7.0
        _LargePixBrightness       ("Large Pix Bright",   Float)          = 0.65
        _LargePixSpeed            ("Large Pix Speed",    Float)          = 0.15
        _LargePixFlipFreq         ("Large Pix Flicker",  Float)          = 2.0

        [Header(Emblem)]
        _EmblemTex                ("Emblem Tex (B on W)", 2D)            = "black" {}
        _EmblemIntensity          ("Emblem Brightness",  Float)          = 2.2

        [Header(Ripple)]
        _RippleSpeed              ("Ripple Speed",        Float)          = 2.5
        _RippleFreq               ("Ripple Frequency",   Float)          = 7.0
        _RippleBrightness         ("Ripple Brightness",  Float)          = 0.08

        [Header(Flicker)]
        _FlickerSpeed             ("Flicker Speed",      Float)          = 7.0
        _FlickerAmount            ("Flicker Amount",     Range(0,0.3))   = 0.12
        _BreathSpeed              ("Breath Speed",       Float)          = 1.2
        _BreathAmount             ("Breath Amount",      Range(0,0.4))   = 0.20

        [Header(Edge Dissolve)]
        _EdgeNoiseScale           ("Edge Noise Scale",   Float)          = 20.0
        _EdgeFadeWidth            ("Edge Fade Width",    Float)          = 0.18

        [Header(Alpha Vertical Fade)]
        _AlphaFadeStart           ("Fade Start (0=bottom)",Range(0,1))   = 0.25
        _AlphaFadeNoiseScale      ("Fade Noise Columns",  Float)         = 8.0
        _AlphaFadeNoiseAmt        ("Fade Noise Amount",   Range(0,0.5))  = 0.30
    }

    SubShader
    {
        Tags
        {
            "RenderType"      = "Transparent"
            "RenderPipeline"  = "UniversalPipeline"
            "Queue"           = "Transparent"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "HoloLootBox"
            Tags { "LightMode" = "UniversalForward" }

            // 
            Blend SrcAlpha One
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 
            // Structs
            // 
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float  NdotV       : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // 
            // CBufferSRP Batcher
            // 
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float  _EmissionIntensity;

                float  _RimWidth, _RimPow, _RimIntensity;

                float  _BeamRadius, _BeamIntensity;
                float  _BeamStreakLength, _BeamStreakSharpness;

                float  _ScanSpeed, _ScanDensity, _ScanBrightness, _ScanBandWidth;

                float  _GridSize, _GridLineWidth, _GridBrightness;

                float  _PixelDensity, _PixelBrightness, _PixelFlipFreq;

                float  _LargePixDensity, _LargePixBrightness;
                float  _LargePixSpeed, _LargePixFlipFreq;

                float4 _EmblemTex_ST;
                float  _EmblemIntensity;

                float  _RippleSpeed, _RippleFreq, _RippleBrightness;

                float  _FlickerSpeed, _FlickerAmount;
                float  _BreathSpeed,  _BreathAmount;

                float  _EdgeNoiseScale, _EdgeFadeWidth;
                float  _AlphaFadeStart, _AlphaFadeNoiseScale, _AlphaFadeNoiseAmt;
            CBUFFER_END

            TEXTURE2D(_EmblemTex); SAMPLER(sampler_EmblemTex);

            // 
            // 
            // 

            // 2D  [0,1]
            float Hash21(float2 p)
            {
                p  = frac(p * float2(127.1, 311.7));
                p += dot(p, p + 74.27);
                return frac(p.x * p.y);
            }

            // Chebyshev SDF
            //  0~1 UV 1= 0= 
            float SoftSquare(float2 uv, float halfSize, float softness)
            {
                float2 q = abs(uv - 0.5);
                float  d = max(q.x, q.y);
                return smoothstep(halfSize, halfSize - softness, d);
            }

            // 
            // Vertex
            // 
            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;

                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
                float3 posWS    = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.NdotV       = saturate(dot(normalWS,
                                  normalize(GetWorldSpaceViewDir(posWS))));
                return OUT;
            }

            // 
            // Fragment  
            // 
            float4 Frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv;
                float  t  = _Time.y;

                // 
                //  
                // 

                //  sin
                float breath  = 1.0 - _BreathAmount
                              * (0.5 - 0.5 * sin(t * _BreathSpeed));

                // 
                float flicker = 1.0 - _FlickerAmount
                              * abs(sin(t * _FlickerSpeed))
                              * abs(sin(t * _FlickerSpeed * 2.31 + 1.7));

                float anim = breath * flicker;

                // 
                //  1. 
                // 
                // min(uv, 1-uv) = 
                float2 border  = min(uv, 1.0 - uv);
                float  rimDist = min(border.x, border.y);
                float  rim     = pow(1.0 - smoothstep(0.0, _RimWidth, rimDist), _RimPow);

                // 
                float cornerBias = (1.0 - smoothstep(0.0, _RimWidth * 3.0, border.x))
                                 * (1.0 - smoothstep(0.0, _RimWidth * 3.0, border.y));
                rim = saturate(rim + cornerBias * 0.8);

                float rimOut = rim * _RimIntensity;

                // 
                //  2. 
                //     (0,0) (1,0) (0,1) (1,1)
                //      + 
                // 
                //  UV.y  Mesh 
                // 
                float beamOut = 0.0;

                // 
                float2 corners[4];
                corners[0] = float2(0.0, 0.0);
                corners[1] = float2(1.0, 0.0);
                corners[2] = float2(0.0, 1.0);
                corners[3] = float2(1.0, 1.0);

                for (int i = 0; i < 4; i++)
                {
                    float2 d = uv - corners[i];

                    // 
                    float radial = length(d);
                    float spot   = smoothstep(_BeamRadius, 0.0, radial);

                    //  UV.y 
                    //  sign 
                    float2 inward = sign(float2(0.5, 0.5) - corners[i]);
                    float  streak = saturate(dot(d * inward, float2(0,1)));
                    streak = pow(streak, _BeamStreakSharpness) * _BeamStreakLength;
                    float  streakMask = smoothstep(_BeamRadius * 0.5, 0.0, abs(d.x));
                    float  streakOut  = streak * streakMask;

                    // 
                    float beamFlicker = 0.85 + 0.15 * sin(t * 8.0 + i * 1.57);

                    beamOut += (spot + streakOut) * _BeamIntensity * beamFlicker;
                }

                // ─────────────────────────────────────────────
                //  3. Vertical Rising Strips
                //     Divide UV.x into discrete columns.
                //     Each column gets a random phase (Hash21) so
                //     the bright band rises at different times →
                //     irregular horizontal distribution.
                // ─────────────────────────────────────────────
                float  colID    = floor(uv.x * _ScanDensity);       // column index
                float  colRandA = Hash21(float2(colID, 0.0));       // 0~1 per column
                float  colRandB = Hash21(float2(colID, 7.3));       // independent rand
                // Each column has a slightly different rise speed
                float  colSpeed = _ScanSpeed * (0.6 + colRandA * 0.8);
                // Phase: 0~1 = position of bright band within the column (looping)
                float  phase    = frac(t * colSpeed + colRandB);    // random start offset
                // Band: a smooth peak that rises from bottom (0) to top (1) each cycle
                float  bandDist = abs(uv.y - phase);
                float  band     = smoothstep(_ScanBandWidth, 0.0, bandDist);
                // Some columns are dimmer/brighter (irregular intensity)
                float  colMask  = step(0.25, colRandA);             // ~75 % columns visible
                float  scanOut  = band * colMask * _ScanBrightness;

                // 
                //  4. 
                // 
                float2 gUV    = frac(uv * _GridSize);
                float  gX     = smoothstep(1.0 - _GridLineWidth, 1.0, gUV.x)
                              + smoothstep(_GridLineWidth, 0.0, gUV.x);
                float  gY     = smoothstep(1.0 - _GridLineWidth, 1.0, gUV.y)
                              + smoothstep(_GridLineWidth, 0.0, gUV.y);
                float  gridOut = saturate(gX + gY) * _GridBrightness;

                // 
                //  5. 
                // 
                float2 cellID   = floor(uv * _PixelDensity);
                float  r1       = Hash21(cellID);
                float  r2       = Hash21(cellID + 99.7);
                float  pixStep  = floor(t * _PixelFlipFreq * (0.5 + r2 * 0.5));
                float  rOnOff   = Hash21(float2(r1, pixStep));
                float  pixelOut = step(0.80, r1) * step(0.65, rOnOff) * _PixelBrightness;

                // 
                //  6. 
                // 
                // UV 
                float2 driftUV  = uv + float2(0.0, t * _LargePixSpeed);
                float2 lgCellID = floor(driftUV * _LargePixDensity);
                float  lr1      = Hash21(lgCellID);
                float  lr2      = Hash21(lgCellID + 13.3);
                float  lgStep   = floor(t * _LargePixFlipFreq * (0.4 + lr2 * 0.6));
                float  lgOnOff  = Hash21(float2(lr1, lgStep));

                //  UV
                float2 lgLocalUV = frac(driftUV * _LargePixDensity);
                //  SDF 40% 
                float  lgShape  = SoftSquare(lgLocalUV, 0.35, 0.06);
                float  largeOut = step(0.75, lr1) * step(0.55, lgOnOff) * lgShape * _LargePixBrightness;

                // 
                float  lgGlow   = SoftSquare(lgLocalUV, 0.45, 0.08)
                                * (1.0 - SoftSquare(lgLocalUV, 0.38, 0.04))
                                * step(0.75, lr1) * step(0.55, lgOnOff) * 0.3;
                largeOut += lgGlow;

                // 
                //  7. 
                // 
                float2 emblemUV = TRANSFORM_TEX(uv, _EmblemTex);
                float  emblemR  = SAMPLE_TEXTURE2D(_EmblemTex, sampler_EmblemTex, emblemUV).r;
                // 
                float  emblemPulse = 0.8 + 0.2 * sin(t * _BreathSpeed * 1.5);
                float  emblemOut   = emblemR * _EmblemIntensity * emblemPulse;

                // 
                //  8. 
                // 
                float2 fromCenter = (uv - 0.5) * 2.0;   // -1 ~ +1
                float  dist       = length(fromCenter);
                float  ripple     = sin(t * _RippleSpeed - dist * _RippleFreq)
                                  * (1.0 - smoothstep(0.6, 1.0, dist));
                float  rippleOut  = max(0.0, ripple) * _RippleBrightness;

                // 
                //  9. Fresnel
                // 
                float fresnelOut = pow(1.0 - IN.NdotV, 3.0) * rim * 0.3;

                // 
                //  
                // 
                float totalGlow = rimOut
                                + beamOut
                                + scanOut
                                + gridOut
                                + pixelOut
                                + largeOut
                                + emblemOut
                                + rippleOut
                                + fresnelOut;

                float3 col = _Color.rgb * totalGlow * _EmissionIntensity * anim;

                //
                //  Edge Dissolve — jagged top boundary
                //  Pixelise UV, sample noise, clip near UV.y == 1
                //
                float2 edgeCell  = floor(uv * _EdgeNoiseScale) / _EdgeNoiseScale;
                float  edgeNoise = Hash21(edgeCell + float2(13.7, 91.3));  // 0~1 per block
                // Map uv.y into dissolve zone: 0 = fully dissolved (top), 1 = fully solid (bottom)
                // edgeNoise shifts per-block cutoff so blocks dissolve at different heights
                float  topMask   = saturate((1.0 - uv.y - edgeNoise * _EdgeFadeWidth)
                                            / max(_EdgeFadeWidth * 0.5, 0.001));
                topMask = smoothstep(0.0, 1.0, topMask);
                clip(topMask - 0.005);   // discard fully dissolved pixels
                col *= topMask;

                // ─────────────────────────────────────────────
                //  Alpha: luminance × irregular vertical gradient
                //  Each "column" (coarse X cell) has its own fade
                //  start offset → top edge looks ragged, not uniform
                // ─────────────────────────────────────────────
                float  fadeColID   = floor(uv.x * _AlphaFadeNoiseScale);
                float  fadeNoise   = Hash21(float2(fadeColID, 3.91));   // per-column rand
                // Shift the fade start randomly per column (some columns fade earlier)
                float  fadeStart   = _AlphaFadeStart + (fadeNoise - 0.5) * _AlphaFadeNoiseAmt * 2.0;
                fadeStart          = saturate(fadeStart);
                // Linear ramp: 0 at fadeStart, 1 at top (uv.y=1)  → invert for bottom-bright
                float  vertGrad    = saturate((uv.y - fadeStart) / max(1.0 - fadeStart, 0.001));
                // Smooth and flip: bottom = 1 (opaque), top = 0 (transparent)
                float  alphaGrad   = 1.0 - smoothstep(0.0, 1.0, vertGrad);
                // Final alpha = per-pixel luminance × irregular gradient × edge dissolve
                float  lum         = saturate(max(col.r, max(col.g, col.b)));
                float  alpha       = lum * alphaGrad * topMask;
                return float4(col, alpha);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
