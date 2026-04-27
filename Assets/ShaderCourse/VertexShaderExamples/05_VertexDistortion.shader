Shader "TA_Course/VertexShader/Distortion"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _DistortionStrength ("Distortion Strength", Range(0, 0.5)) = 0.05
        _DistortionSpeed ("Distortion Speed", Range(0, 5)) = 1.0
        _DistortionScale ("Distortion Scale", Range(0.1, 10)) = 2.0
        _GlowColor ("Glow Color", Color) = (0.2, 0.5, 1, 1)
        _GlowIntensity ("Glow Intensity", Range(0, 5)) = 1.0
    }
    
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        
        Pass
        {
            Name "DistortionPass"
            Tags { "LightMode"="UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
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
                float2 distortedUV : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _DistortionStrength;
                float _DistortionSpeed;
                float _DistortionScale;
                float4 _GlowColor;
                float _GlowIntensity;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            half noise(half2 p)
            {
                return frac(sin(dot(p, half2(127.1, 311.7))) * 43758.5453);
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                
                half3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                
                half2 noiseCoord = worldPos.xz * _DistortionScale + _Time.y * _DistortionSpeed;
                half n = noise(noiseCoord);
                
                half2 distortion = half2(
                    sin(worldPos.z * 10.0 + _Time.y * _DistortionSpeed) * n,
                    cos(worldPos.x * 10.0 + _Time.y * _DistortionSpeed * 1.3) * n
                ) * _DistortionStrength;
                
                worldPos.x += distortion.x;
                worldPos.z += distortion.y;
                worldPos.y += sin(worldPos.x * 5.0 + _Time.y) * _DistortionStrength * 0.5;
                
                o.pos = TransformWorldToHClip(worldPos);
                o.worldPos = worldPos;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.distortedUV = o.uv + distortion;
                
                return o;
            }
            
            half4 frag (v2f i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.distortedUV);
                
                half3 baseColor = tex.rgb * _BaseColor.rgb;
                
                half2 uvOffset = abs(i.distortedUV - i.uv);
                half distortionIntensity = saturate(length(uvOffset) * 20.0);
                
                half3 glow = _GlowColor.rgb * _GlowIntensity * distortionIntensity;
                
                half3 finalColor = baseColor + glow;
                
                half alpha = tex.a * _BaseColor.a * (0.7 + distortionIntensity * 0.3);
                
                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}