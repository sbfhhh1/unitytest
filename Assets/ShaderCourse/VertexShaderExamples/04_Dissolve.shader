Shader "TA_Course/VertexShader/Dissolve"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        [Toggle(ANIMATION)] _Animation ("Auto Animation", Float) = 1
        _DissolveThreshold ("Dissolve Amount", Range(0, 1)) = 0.0
        _DissolveSpeed ("Animation Speed", Range(0, 1)) = 0.15
        _VoronoiDensity ("Voronoi Density", Range(1, 20)) = 5.0
        _VoronoiAngle ("Voronoi Angle Offset", Range(0, 10)) = 2.0
        _EdgeWidth ("Edge Width", Range(0.01, 0.3)) = 0.1
        _EdgeColor ("Edge Color", Color) = (1, 0.4, 0, 1)
        _EdgeIntensity ("Edge Intensity", Range(1, 5)) = 2.5
    }
    
    SubShader
    {
        Tags { 
            "RenderPipeline"="UniversalPipeline" 
            "RenderType"="TransparentCutout" 
            "Queue"="AlphaTest"
        }
        
        Pass
        {
            Name "DissolvePass"
            Tags { "LightMode"="UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature ANIMATION
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _DissolveThreshold;
                float _DissolveSpeed;
                float _VoronoiDensity;
                float _VoronoiAngle;
                float _EdgeWidth;
                float4 _EdgeColor;
                float _EdgeIntensity;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            // Voronoi noise function (inline)
            float2 _voronoi_rnd(float2 uv, float offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                uv = frac(sin(mul(uv, m)) * 46839.32);
                return float2(sin(uv.y + offset) * 0.5 + 0.5, cos(uv.x * offset) * 0.5 + 0.5);
            }
            
            float VoronoiDistance(float2 uv, float angleOffset, float density)
            {
                float2 g = floor(uv * density);
                float2 f = frac(uv * density);
                float t = 8.0;
                
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 lattice = float2(x, y);
                        float2 offset = _voronoi_rnd(lattice + g, angleOffset);
                        float d = distance(lattice + offset, f);
                        if (d < t)
                        {
                            t = d;
                        }
                    }
                }
                return t;
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                return o;
            }
            
            half4 frag (v2f i) : SV_Target
            {
                // Sample main texture
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                // Use Voronoi noise
                half voronoiDist = VoronoiDistance(i.uv, _VoronoiAngle, _VoronoiDensity);
                
                // Calculate threshold with optional animation
                #ifdef ANIMATION
                    half threshold = _DissolveThreshold + _Time.y * _DissolveSpeed;
                    threshold = frac(threshold);
                #else
                    half threshold = _DissolveThreshold;
                #endif
                
                // Dissolve: discard pixels where voronoi distance < threshold
                clip(voronoiDist - threshold);
                
                // Base color with lighting
                half3 albedo = texColor.rgb * _BaseColor.rgb;
                half3 normalWS = normalize(i.normalWS);
                Light mainLight = GetMainLight();
                half ndotl = saturate(dot(normalWS, mainLight.direction));
                half3 color = albedo * (ndotl * 0.7 + 0.3);
                
                // Edge glow
                half diff = voronoiDist - threshold;
                if (diff < _EdgeWidth)
                {
                    half edgeFactor = 1.0 - (diff / _EdgeWidth);
                    edgeFactor = pow(edgeFactor, 2.0);
                    color = lerp(color, _EdgeColor.rgb * _EdgeIntensity, edgeFactor);
                }
                
                return half4(color, texColor.a * _BaseColor.a);
            }
            ENDHLSL
        }
    }
}