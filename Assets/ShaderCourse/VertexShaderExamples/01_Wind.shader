Shader "TA_Course/VertexShader/Wind"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _WindSpeed ("Wind Speed", Range(0.1, 10)) = 2.0
        _WindStrength ("Wind Strength", Range(0, 0.5)) = 0.1
        _WindDirection ("Wind Direction", Vector) = (1, 0, 0, 0)
        _WindNoise ("Wind Noise", Range(0, 1)) = 0.3
        _HeightStart ("Height Start", Range(-1, 1)) = 0
        _HeightEnd ("Height End", Range(0, 3)) = 1
    }
    
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        
        Pass
        {
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
                float3 normalWS : TEXCOORD1;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _WindSpeed;
                float _WindStrength;
                float4 _WindDirection;
                float _WindNoise;
                float _HeightStart;
                float _HeightEnd;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            v2f vert (appdata v)
            {
                v2f o;
                
                half3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                
                half heightFactor = smoothstep(_HeightStart, _HeightEnd, v.vertex.y);
                
                half windPhase = worldPos.x * 2.0 + worldPos.z * 1.5;
                half mainWind = sin(windPhase + _Time.y * _WindSpeed) * _WindStrength;
                
                half noiseOffset = sin(windPhase * 3.0 + _Time.y * _WindSpeed * 1.7) * _WindNoise * _WindStrength;
                
                half totalWind = (mainWind + noiseOffset) * heightFactor;
                
                worldPos.x += _WindDirection.x * totalWind;
                worldPos.z += _WindDirection.z * totalWind;
                worldPos.y -= abs(totalWind) * 0.1;
                
                o.pos = TransformWorldToHClip(worldPos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                
                return o;
            }
            
            half4 frag (v2f i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half3 normal = normalize(i.normalWS);
                
                half3 lightDir = half3(0.5, 1.0, 0.3);
                half ndotl = saturate(dot(normal, lightDir));
                
                return tex * _BaseColor * (ndotl * 0.7 + 0.3);
            }
            ENDHLSL
        }
    }
}