Shader "ShaderCourse/Holo/HoloBoxFull"
{
    Properties
    {
        [Header(Textures)]
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        _MaskMap ("Mask (R:Metallic G:AO B:Emission A:Smoothness)", 2D) = "white" {}

        [Header(Core Color)]
        [MainColor] _BaseColor ("Base Color", Color) = (0.08, 0.18, 0.32, 1)
        [HDR] _EdgeColor ("Edge Strip Color", Color) = (0.2, 0.72, 1.0, 1)
        [HDR] _BeamColor ("Beam Color", Color) = (0.25, 0.65, 1.0, 1)
        [HDR] _ParticleColor ("Particle Color", Color) = (0.8, 0.92, 1.0, 1)

        [Header(Edge Light Strips)]
        _EdgeWidth ("Edge Width", Range(0.005, 0.3)) = 0.06
        _EdgeSoftness ("Edge Softness", Range(0.01, 0.5)) = 0.12
        _EdgeIntensity ("Edge Intensity", Range(0, 8)) = 2.5
        _EdgeGlowRadius ("Edge Glow Radius", Range(0, 0.5)) = 0.15

        [Header(Vertical Beams)]
        _BeamCount ("Beam Count (per edge)", Range(1, 12)) = 6
        _BeamWidth ("Beam Width", Range(0.01, 0.3)) = 0.07
        _BeamHeight ("Beam Height", Range(0, 3)) = 1.4
        _BeamIntensity ("Beam Intensity", Range(0, 6)) = 1.8
        _BeamGradientPower ("Beam Vertical Fade", Range(0.5, 6)) = 2.2

        [Header(Beam Animation)]
        _BreathingSpeed ("Breathing Speed", Range(0, 8)) = 2.5
        _BreathingAmplitude ("Breathing Amplitude", Range(0, 0.6)) = 0.25
        _HeightVariation ("Height Variation", Range(0, 0.8)) = 0.35
        _BeamPhaseSpread ("Beam Phase Spread", Range(0, 6.28)) = 1.8

        [Header(Particles)]
        _ParticleDensity ("Particle Density", Range(4, 64)) = 24
        _ParticleSize ("Particle Size", Range(0.01, 0.15)) = 0.05
        _ParticleRiseSpeed ("Particle Rise Speed", Range(0, 4)) = 0.8
        _ParticleTwinkle ("Particle Twinkle", Range(0, 1)) = 0.6
        _ParticleClusterChance ("Particle Cluster Chance", Range(0, 1)) = 0.3

        [Header(Holographic)]
        _FresnelPower ("Fresnel Power", Range(0.5, 10)) = 3.5
        _FresnelIntensity ("Fresnel Intensity", Range(0, 4)) = 1.2
        _ChromaticDispersion ("Chromatic Dispersion", Range(0, 0.02)) = 0.006
        _HoloOpacity ("Hologram Base Alpha", Range(0, 1)) = 0.25

        [Header(Scan Lines)]
        _ScanAngle ("Scan Angle", Range(-180, 180)) = 45
        _ScanTiling ("Scan Tiling", Range(1, 100)) = 18
        _ScanSpeed ("Scan Speed", Range(0, 8)) = 1.2
        _ScanWidth ("Scan Width", Range(0.01, 0.6)) = 0.18
        _ScanIntensity ("Scan Intensity", Range(0, 4)) = 0.9

        [Header(Global)]
        _GlobalIntensity ("Global Intensity", Range(0, 4)) = 1.0
        _TopOnly ("Top Only", Range(0, 1)) = 0.8
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent+30"
        }

        Pass
        {
            Name "HoloBoxFull"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha One
            ZWrite Off
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _MaskMap_ST;
                half4 _BaseColor;
                half4 _EdgeColor;
                half4 _BeamColor;
                half4 _ParticleColor;
                half _EdgeWidth;
                half _EdgeSoftness;
                half _EdgeIntensity;
                half _EdgeGlowRadius;
                half _BeamCount;
                half _BeamWidth;
                half _BeamHeight;
                half _BeamIntensity;
                half _BeamGradientPower;
                half _BreathingSpeed;
                half _BreathingAmplitude;
                half _HeightVariation;
                half _BeamPhaseSpread;
                half _ParticleDensity;
                half _ParticleSize;
                half _ParticleRiseSpeed;
                half _ParticleTwinkle;
                half _ParticleClusterChance;
                half _FresnelPower;
                half _FresnelIntensity;
                half _ChromaticDispersion;
                half _HoloOpacity;
                half _ScanAngle;
                half _ScanTiling;
                half _ScanSpeed;
                half _ScanWidth;
                half _ScanIntensity;
                half _GlobalIntensity;
                half _TopOnly;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
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

            // ── Hash & Noise ──────────────────────────────────

            float Hash12(float2 p)
            {
                p = frac(p * float2(0.1031, 0.1030));
                p += dot(p, p.yx + 33.33);
                return frac((p.x + p.y) * p.x);
            }

            float Hash1(float p)
            {
                return frac(sin(p) * 43758.5453);
            }

            float Noise21(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = Hash12(i);
                float b = Hash12(i + float2(1, 0));
                float c = Hash12(i + float2(0, 1));
                float d = Hash12(i + float2(1, 1));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float Fbm(float2 p)
            {
                float v = 0;
                float a = 0.5;
                float2 shift = float2(0, 0);
                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    v += a * Noise21(p + shift);
                    p = p * 2.03 + 7.13;
                    a *= 0.5;
                    shift += 3.17;
                }
                return v;
            }

            // ── Edge / SDF ────────────────────────────────────

            // Signed distance from a point to the nearest edge of a unit square [0,1]^2
            float RectEdgeDist(float2 uv)
            {
                float2 d = min(uv, 1.0 - uv);
                return min(d.x, d.y);
            }

            // Top-face edge strip mask
            float EdgeStripMask(float2 uv, float width, float softness)
            {
                float dist = RectEdgeDist(uv);
                float core = 1.0 - smoothstep(width, width + softness, dist);
                float glow = exp(-dist / max(_EdgeGlowRadius, 0.001));
                return core * 0.85 + glow * 0.3;
            }

            // ── Beam from top edges ────────────────────────────

            // Given a UV position on the top face, place beams along edges
            float BeamFromTopEdge(float2 uv, float3 positionOS, float3 normalWS, float time)
            {
                float topFace = smoothstep(0.3, 0.7, normalWS.y);

                // Map UV to 4 edges
                float2 edgeDist = float2(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
                float minDist = min(edgeDist.x, edgeDist.y);

                // Only near top edges
                float edgeProximity = 1.0 - smoothstep(0.0, _EdgeWidth + _BeamWidth * 2.5, minDist);

                // Parameterize position along the 4 edges
                // Which edge are we closest to? Use the perimeter coordinate
                float uAlong = 0;
                // Remap: walk around the perimeter
                if (uv.y < 0.5) uAlong = uv.x;                       // bottom edge, left->right
                else if (uv.x > 0.5) uAlong = 1.0 + (1.0 - uv.y);   // right edge, bottom->top
                else if (uv.y > 0.5) uAlong = 2.0 + (1.0 - uv.x);   // top edge, right->left
                else uAlong = 3.0 + uv.y;                            // left edge, top->bottom
                uAlong /= 4.0;

                // Place beam anchors along the perimeter
                float beamSpacing = 1.0 / max(_BeamCount, 1);
                float bestBeam = 0;
                float bestDist = 100;

                for (int b = 0; b < 12; b++)
                {
                    if (b >= (int)_BeamCount) break;
                    float anchor = (b + 0.5) * beamSpacing;
                    // Jitter anchors per-beam using hash
                    float jitter = (Hash12(float2(b * 73.1, 17.3)) - 0.5) * beamSpacing * 0.6;
                    anchor += jitter;
                    float distAlong = abs(uAlong - anchor);
                    // Wrap around perimeter
                    distAlong = min(distAlong, 1.0 - distAlong);
                    // Convert to approximate UV distance
                    float beamDist = distAlong * 4.0 * _BeamWidth * 0.7;
                    if (beamDist < bestDist)
                    {
                        bestDist = beamDist;
                        bestBeam = beamDist;
                    }
                }

                // Beam shape: soft falloff
                float beamShape = 1.0 - smoothstep(_BeamWidth * 0.3, _BeamWidth * 1.6, bestBeam);

                // Vertical extension: beams extend upward from the top face
                // Use world-space Y to create gradient
                float heightAbove = positionOS.y - 0.48; // top face ~0.5 for unit cube
                float heightFrac = saturate(heightAbove / max(_BeamHeight, 0.01));
                float verticalFade = 1.0 - pow(heightFrac, _BeamGradientPower);

                // Height cutoff
                float heightCutoff = 1.0 - smoothstep(_BeamHeight * 0.9, _BeamHeight, heightAbove);

                // Each beam has its own breathing phase
                float beamIndex = floor(uAlong * _BeamCount);
                float individualPhase = Hash1(beamIndex * 31.7) * _BeamPhaseSpread;
                float breathe = 1.0 - _BreathingAmplitude +
                    _BreathingAmplitude * (sin(time * _BreathingSpeed + individualPhase) * 0.5 + 0.5);

                // Height variation: some beams are taller
                float heightVar = 1.0 - _HeightVariation * Hash1(beamIndex * 53.9);

                return beamShape * edgeProximity * topFace * verticalFade * heightCutoff *
                       breathe * heightVar * _BeamIntensity;
            }

            // ── Procedural Particles ───────────────────────────

            float Particles(float3 positionWS, float time)
            {
                float particle = 0;

                // 3D grid for particles
                float spacing = 1.0 / max(_ParticleDensity * 0.3, 0.1);

                for (int px = -1; px <= 1; px++)
                for (int py = 0; py <= 2; py++)
                for (int pz = -1; pz <= 1; pz++)
                {
                    float3 cellOffset = float3(px, py, pz);
                    float3 cell = floor(positionWS * spacing + cellOffset);
                    float3 cellCenter = (cell + 0.5) / spacing;

                    // Only spawn particles above a certain height and with probability
                    float spawnHash = Hash12(cell.xz + cell.y * 47.3);
                    if (spawnHash < 0.58) continue; // density control

                    // Particle position within cell (with slow upward drift)
                    float3 localPos;
                    localPos.x = Hash12(cell.xy + 13.7) - 0.5;
                    localPos.z = Hash12(cell.zy + 27.1) - 0.5;
                    localPos.y = frac(Hash12(cell.xz + 41.9) + time * _ParticleRiseSpeed * 0.15);
                    localPos -= 0.5;

                    float3 particlePos = cellCenter + localPos / spacing * 0.85;
                    float3 delta = positionWS - particlePos;
                    float dist = length(delta);

                    // Square particle shape (use max of abs components)
                    float squareDist = max(max(abs(delta.x), abs(delta.y)), abs(delta.z));
                    float size = _ParticleSize * lerp(0.4, 1.4, Hash12(cell.xy + 81.2));
                    float sqParticle = 1.0 - smoothstep(size * 0.5, size * 1.3, squareDist);

                    // Cluster behavior: some particles cluster together
                    float clusterHash = Hash12(cell.xz + 53.7);
                    if (clusterHash < _ParticleClusterChance)
                    {
                        float3 clusterCenter = cellCenter + float3(
                            (Hash12(cell.xy + 63.1) - 0.5) * 0.6,
                            (Hash12(cell.yz + 73.1) - 0.5) * 0.3,
                            (Hash12(cell.xz + 83.1) - 0.5) * 0.6
                        ) / spacing;
                        float clusterDist = length(positionWS - clusterCenter);
                        float clusterGlow = exp(-clusterDist * 8.0) * 0.25;
                        sqParticle += clusterGlow * (1.0 - sqParticle);
                    }

                    // Twinkle
                    float twinkle = lerp(1.0, sin(time * 4.5 + Hash12(cell.xy + 91.3) * 12.0) * 0.5 + 0.5, _ParticleTwinkle);

                    // Height fade (particles fade as they rise)
                    float riseFade = 1.0 - saturate(localPos.y * 0.8 + 0.5);

                    particle += sqParticle * twinkle * riseFade * 0.35;
                }

                return saturate(particle * 1.8);
            }

            // ── Chromatic Dispersion ───────────────────────────
            // Simple RGB separation at grazing angles

            float3 ChromaticShift(float3 normalWS, float3 viewDirWS, float amount)
            {
                float NdotV = saturate(dot(normalize(normalWS), normalize(viewDirWS)));
                float grazing = 1.0 - NdotV;
                float shift = grazing * amount;
                return float3(-shift, 0, shift); // R shifted left, B shifted right
            }

            // ── Vertex ─────────────────────────────────────────

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
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            // ── Fragment ───────────────────────────────────────

            half4 frag(Varyings input) : SV_Target
            {
                float time = _Time.y;

                // Sample textures
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 maskTex = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);
                half emissionMask = maskTex.b;

                // ── Top face detection ──
                float topFaceMask = smoothstep(0.15, 0.55, input.normalWS.y);
                float topOnly = lerp(1.0, topFaceMask, _TopOnly);

                // ── Edge strips ──
                float edgeStrip = EdgeStripMask(input.uv, _EdgeWidth, _EdgeSoftness);
                float pulse = 1.0 - _BreathingAmplitude * 0.35 +
                    _BreathingAmplitude * 0.35 * (sin(time * _BreathingSpeed) * 0.5 + 0.5);
                float edgeGlow = edgeStrip * _EdgeIntensity * pulse * topFaceMask;

                // ── Vertical beams ──
                float beams = BeamFromTopEdge(input.uv, input.positionOS, input.normalWS, time);

                // ── Scan lines ──
                float angleRad = radians(_ScanAngle);
                float2 scanDir = normalize(float2(cos(angleRad), sin(angleRad)));
                float2 centeredUv = input.uv - 0.5;
                float scanCoord = dot(centeredUv, scanDir);
                float sweep = frac(scanCoord * _ScanTiling - time * _ScanSpeed);
                float scanLine = smoothstep(0, _ScanWidth, sweep) *
                    (1.0 - smoothstep(_ScanWidth, _ScanWidth + _ScanWidth * 0.5, sweep));
                float scanGlow = scanLine * _ScanIntensity * topFaceMask * emissionMask;

                // ── Fresnel ──
                float NdotV = saturate(dot(normalize(input.normalWS), normalize(input.viewDirWS)));
                float fresnel = pow(1.0 - NdotV, _FresnelPower);

                // ── Chromatic dispersion ──
                float3 chromaShift = ChromaticShift(input.normalWS, input.viewDirWS, _ChromaticDispersion);
                // Apply as subtle color fringing at edges
                float3 chromaColor;
                chromaColor.r = fresnel * _EdgeColor.r * (1.0 + chromaShift.r * 80);
                chromaColor.g = fresnel * _EdgeColor.g;
                chromaColor.b = fresnel * _EdgeColor.b * (1.0 + chromaShift.b * 80);

                // ── Particles ──
                float particles = Particles(input.positionWS, time);

                // ── Holographic base ──
                float3 baseLit = baseTex.rgb * _BaseColor.rgb;
                float hologramBase = topFaceMask * _HoloOpacity * (0.15 + fresnel * 0.35);

                // ── Combine ──
                float3 color = 0;

                // Base holographic surface
                color += baseLit * hologramBase;

                // Edge strips (cyan glow)
                color += _EdgeColor.rgb * edgeGlow * 1.3;

                // Vertical beams
                color += _BeamColor.rgb * beams * 1.2;

                // Scan lines
                color += _EdgeColor.rgb * scanGlow;

                // Fresnel with chromatic dispersion
                color += chromaColor * _FresnelIntensity * 0.55;
                color += _EdgeColor.rgb * fresnel * _FresnelIntensity * 0.3;

                // Particles
                color += _ParticleColor.rgb * particles * 0.9;

                // Overall alpha
                float alpha = saturate(
                    edgeGlow * 0.55 +
                    beams * 0.6 +
                    fresnel * _FresnelIntensity * 0.4 +
                    particles * 0.5 +
                    hologramBase * 1.2 +
                    scanGlow * 0.4
                ) * topOnly;

                color *= _GlobalIntensity;

                return half4(color, alpha * _EdgeColor.a);
            }
            ENDHLSL
        }
    }
}
