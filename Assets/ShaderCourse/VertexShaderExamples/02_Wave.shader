Shader "TA_Course/VertexShader/Wave"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (0.2, 0.6, 0.9, 1)
        _WaveA ("Wave A Amplitude", Range(0, 0.5)) = 0.1
        _WaveASpeed ("Wave A Speed", Range(0, 5)) = 1.0
        _WaveADir ("Wave A Direction", Vector) = (1, 0, 0)
        _WaveB ("Wave B Amplitude", Range(0, 0.5)) = 0.08
        _WaveBSpeed ("Wave B Speed", Range(0, 5)) = 1.3
        _WaveBDir ("Wave B Direction", Vector) = (0.7, 0, 0.7)
        _WaveC ("Wave C Amplitude", Range(0, 0.5)) = 0.05
        _WaveCSpeed ("Wave C Speed", Range(0, 5)) = 1.7
        _WaveCDir ("Wave C Direction", Vector) = (-0.5, 0, 0.8)
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
                float3 worldPos : TEXCOORD2;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _WaveA, _WaveASpeed;
                float4 _WaveADir;
                float _WaveB, _WaveBSpeed;
                float4 _WaveBDir;
                float _WaveC, _WaveCSpeed;
                float4 _WaveCDir;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            float3 GerstnerWave(float amp, float speed, float3 dir, float3 pos)
            {
                float k = 2.0;
                float omega = speed * 1.5;
                float phase = k * dot(dir.xz, pos.xz) - omega * _Time.y;
                
                float y = amp * sin(phase);
                float x = dir.x * amp * cos(phase);
                float z = dir.z * amp * cos(phase);
                
                return float3(x, y, z);
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                
                float3 waveA = GerstnerWave(_WaveA, _WaveASpeed, normalize(_WaveADir.xyz), worldPos);
                float3 waveB = GerstnerWave(_WaveB, _WaveBSpeed, normalize(_WaveBDir.xyz), worldPos);
                float3 waveC = GerstnerWave(_WaveC, _WaveCSpeed, normalize(_WaveCDir.xyz), worldPos);
                
                float3 totalWave = waveA + waveB + waveC;
                worldPos += totalWave;
                
                o.pos = TransformWorldToHClip(worldPos);
                o.worldPos = worldPos;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                
                return o;
            }
            
            half4 frag (v2f i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                float height = i.worldPos.y;
                half3 deepColor = half3(0.1, 0.3, 0.5);
                half3 shallowColor = half3(0.2, 0.6, 0.9);
                half3 waterColor = lerp(deepColor, shallowColor, saturate(height * 5.0 + 0.5));
                
                return half4(waterColor * tex.rgb * _BaseColor.rgb, 0.85);
            }
            ENDHLSL
        }
    }
}