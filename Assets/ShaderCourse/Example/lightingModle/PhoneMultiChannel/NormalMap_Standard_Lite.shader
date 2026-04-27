// ================================================
// 简化版教学 Shader：法线贴图技术精解（升级光照版）
// 光照模型：Blinn-Phong 高光 + 球谐（SH）环境光
// 核心教学目标：理解法线贴图在切线空间的工作原理
// ================================================

Shader "Tutorial/Lit/NormalMap_BlinnPhong_SH_Explained"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _MainTex ("Base Texture (Albedo)", 2D) = "white" {}
        
        [Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalIntensity("Normal Intensity", Range(0.0, 5.0)) = 1.0
        
        [Header(BlinnPhong )]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularIntensity("Specular Intensity", Range(0.0, 10.0)) = 2.0
        _Gloss("Gloss (Smoothness)", Range(1.0, 256.0)) = 50.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ====================== 输入输出结构体 ======================
            struct Attributes
            {
                float4 positionOS : POSITION;     // 模型空间顶点位置
                float2 uv         : TEXCOORD0;    // UV坐标
                float3 normalOS   : NORMAL;       // 模型空间法线
                float4 tangentOS  : TANGENT;      // 模型空间切线（必须包含w分量用于副切线方向）
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 lightDirTS : TEXCOORD1;   // 切线空间的光线方向
                float3 viewDirTS  : TEXCOORD2;   // 切线空间的视线方向
            };

            // ====================== 材质属性 ======================
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _MainTex_ST;
                float _NormalIntensity;
                float4 _SpecularColor;
                float _SpecularIntensity;
                float _Gloss;
            CBUFFER_END

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);

            // ====================== 顶点着色器 ======================
            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // ==================== 关键原理1：构建TBN矩阵 ====================
                // TBN矩阵 = Tangent + Bitangent + Normal
                // 作用：把世界空间的向量（光线、视线）转换到切线空间
                // 这样我们就可以直接用法线贴图中的法线向量进行光照计算
                
                float3 normalWS    = TransformObjectToWorldNormal(v.normalOS);
                float3 tangentWS   = TransformObjectToWorldDir(v.tangentOS.xyz);
                float3 bitangentWS = cross(normalWS, tangentWS) * v.tangentOS.w; // w分量决定副切线方向（防止镜像翻转）
                
                float3x3 tbnMatrix = float3x3(tangentWS, bitangentWS, normalWS);

                // ==================== 关键原理2：向量转换到切线空间 ====================
                // 光线和视线必须转换到切线空间，才能和法线贴图的法线做点积
                float3 lightDirWS = GetMainLight().direction;
                o.lightDirTS = mul(tbnMatrix, lightDirWS);        // 世界→切线空间
                
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(TransformObjectToWorld(v.positionOS.xyz));
                o.viewDirTS = mul(tbnMatrix, viewDirWS);          // 世界→切线空间

                return o;
            }

            // ====================== 片元着色器 ======================
            half4 frag(Varyings i) : SV_Target
            {
                // 1. 采样颜色贴图
                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _BaseColor.rgb;

                // ==================== 关键原理3：解包法线贴图 ====================
                // 法线贴图的RGB值范围是[0,1]，需要UnpackNormalScale转换到[-1,1]的真实法线方向
                // _NormalIntensity 用于控制凹凸强度（教学中常用1.0~3.0）
                float3 normalTS = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), 
                    _NormalIntensity
                );

                // ==================== 关键原理4：Blinn-Phong光照模型 ====================
                // Blinn-Phong相比Phong更高效，使用半向量（Half Vector）计算高光
                float3 lightDirTS = normalize(i.lightDirTS);
                float3 viewDirTS  = normalize(i.viewDirTS);
                float3 halfDirTS  = normalize(lightDirTS + viewDirTS);   // Blinn的核心：半向量

                float NdotL = saturate(dot(normalTS, lightDirTS));   // 漫反射强度
                float NdotH = saturate(dot(normalTS, halfDirTS));    // 高光强度

                // 漫反射
                half3 diffuse = _MainLightColor.rgb * NdotL * albedo;

                // 高光（Specular）
                float spec = pow(NdotH, _Gloss);
                half3 specular = _MainLightColor.rgb * _SpecularColor.rgb * spec * _SpecularIntensity;

                // ==================== 关键原理5：球谐（SH）环境光 ====================
                // SampleSH 使用球谐函数根据世界空间法线采样场景环境光照
                // 比固定 ambient * 0.2 更加自然、真实，能体现模型的朝向差异
                float3 normalWS = TransformTangentToWorld(normalTS, float3x3(
                    i.lightDirTS, cross(normalTS, i.lightDirTS), normalTS)); // 简化TBN重建
                
                half3 ambient = SampleSH(normalWS) * albedo;

                // ==================== 最终合成 ====================
                half3 finalColor = ambient + diffuse + specular;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}