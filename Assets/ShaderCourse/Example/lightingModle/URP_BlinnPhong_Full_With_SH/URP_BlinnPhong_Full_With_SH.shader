// ============================================================================
// Blinn-Phong.shader - Blinn-Phong + Spherical Harmonics 环境光
// ============================================================================
// 新增功能：
// 1. 使用 SampleSH() 添加球谐（Spherical Harmonics）环境光
// 2. 避免背光面过暗（无光照时至少有柔和的环境光）
// 3. 环境光只影响漫反射部分（符合物理直观）
//
// 推荐：场景中开启 Light Probes + Reflection Probes 效果更佳
// ============================================================================

Shader "Custom/URP_BlinnPhong_Full_With_SH"
{
    Properties
    {
        [MainTexture] _BaseMap("基础纹理 (Base Map)", 2D) = "white" {}
        [MainColor]   _BaseColor("基础颜色 (Base Color)", Color) = (1, 1, 1, 1)
        _Smoothness("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.5
        _SpecularColor("高光颜色 (Specular Color)", Color) = (1, 1, 1, 1)
        
        // 新增：环境光强度调节（可选）
        _AmbientStrength("环境光强度", Range(0.0, 2.0)) = 1.0
    }

    SubShader
    {
        Tags 
        { 
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 posCS      : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _SpecularColor;
                float _Smoothness;
                float4 _BaseMap_ST;
                float _AmbientStrength;   // 新增
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            v2f vert(appdata v)
            {
                v2f o;

                VertexPositionInputs posInput = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS = posInput.positionCS;
                o.positionWS = posInput.positionWS;

                VertexNormalInputs normInput = GetVertexNormalInputs(v.normal);
                o.normalWS = normInput.normalWS;

                o.uv = v.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;

                return o;
            }
            float3 lighting(v2f i)
            {
                 // ==================== 基础准备 ====================
                float3 N = normalize(i.normalWS);
                float3 V = GetWorldSpaceNormalizeViewDir(i.positionWS);

                Light mainLight = GetMainLight();
                float3 L = mainLight.direction;
                float3 lightColor = mainLight.color;
                  // ==================== 漫反射 (Lambert) ====================
                float ndotl = saturate(dot(N, L));
                half3 diffuse = lightColor * ndotl;

                // ==================== 镜面反射 (Blinn-Phong) ====================
                float3 H = normalize(L + V);
                float ndoth = saturate(dot(N, H));
                float specPower = pow(ndoth, _Smoothness * 128.0 + 1.0);
                half3 specular = _SpecularColor.rgb * lightColor * specPower;

                // ==================== 【新增】球谐环境光 (SH) ====================
                // SampleSH 返回基于世界空间法线的低频环境光照（Light Probes + Ambient）
                half3 shAmbient = SampleSH(N);                    // 关键函数！
                
                // 只让环境光影响漫反射部分（更自然）
                half3 ambient =  shAmbient * _AmbientStrength;

                // ==================== 最终组合 ====================
                float attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                // 环境光通常不需要乘衰减（它是全局的）
                half3 finalRGB = ambient + (diffuse + specular) * attenuation;
                return  finalRGB ;
                }

            half4 frag(v2f i) : SV_Target
            {
               

                // ==================== 纹理采样 ====================
                half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half3 albedo = texColor.rgb * _BaseColor.rgb;

              float3 lightCol=lighting(i);
                
               float3 finalRGB =albedo *lightCol;

                return half4(finalRGB, texColor.a * _BaseColor.a);
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Simple Lit"
}