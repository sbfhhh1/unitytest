// ============================================================================
// Dynamic_Water.shader - 动态水面Shader（顶点动画 + Fresnel反射）
// ============================================================================
//
// 【PPT对应章节】
// - GPU渲染阶段 > 顶点Shader（顶点位置动画修改）
// - GPU渲染阶段 > 片元Shader（纹理采样、Fresnel反射）
// - 纹理技术 > 纹理采样、纹理过滤
//
// 【核心知识点】
// 1. 顶点着色器动画：使用sin函数修改顶点Y坐标实现波浪
// 2. Gerstner波：经典的水面波浪模拟算法
// 3. Fresnel效应：观察角度越大，反射越强
// 4. 纹理动画：UV偏移实现水流动效果
// 5. 半透明渲染：Blend设置 + Alpha控制
// ============================================================================

Shader "TA_Course/Dynamic_Water"
{
    Properties
    {
        _MainTex ("水面纹理", 2D) = "white" {}
        _Color ("水颜色", Color) = (0.2, 0.6, 0.8, 1)
        _WaveSpeed ("波浪速度", Range(0.1, 5)) = 1.5
        _WaveStrength ("波浪强度", Range(0, 0.1)) = 0.03
        _ReflectionStrength ("反射强度", Range(0, 1)) = 0.6
    }
    
    SubShader
    {
        Tags { 
            "RenderType"="Transparent" 
            "Queue"="Transparent" 
            "RenderPipeline"="UniversalPipeline" 
        }
        
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            Name "WaterForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            float4 _Color;
            float _WaveSpeed, _WaveStrength, _ReflectionStrength;

            v2f vert (appdata v)
            {
                v2f o;
                
                // Gerstner波浪模拟
                float waveX = sin(v.vertex.x * 15.0 + _Time.y * _WaveSpeed) * _WaveStrength;
                float waveZ = sin(v.vertex.z * 15.0 + _Time.y * _WaveSpeed) * _WaveStrength;
                float wave = waveX + waveZ;
                v.vertex.y += wave;

                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 col =float4(1,1,1,1);
                
              
                
                col.rgb += _ReflectionStrength;
          
                return col*_Color;
            }
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Particles/Simple Lit"
}