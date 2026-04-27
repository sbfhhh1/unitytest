// ============================================================================
// PBR_Outline.shader - 卡通描边Shader（多Pass渲染）
// ============================================================================
// 
// 【PPT对应章节】
// - GPU渲染阶段 > 顶点Shader（顶点偏移实现描边）
// - 输出合并 > 深度测试（描边Pass的ZTest）
// - 渲染管线流程（多Pass渲染）
//
// 【核心知识点】
// 1. 多Pass渲染：一个物体分多次绘制
// 2. 描边原理：沿法线方向外扩顶点
// 3. Cull Front：剔除正面，只渲染背面描边
// 4. ZTest LEqual：深度测试，确保描边被遮挡时正确显示
// 5. ShadowCaster Pass：投射阴影
//
// 【描边算法】
// 沿法线方向将顶点向外偏移，渲染背面形成轮廓
// ============================================================================

Shader "TA_Course/PBR_Outline"
{
    // ==================== 属性面板 ====================
    Properties
    {
        // 主纹理
        _MainTex ("主纹理 (Base Map)", 2D) = "white" {}
        
        // 基础颜色
        _BaseColor ("基础颜色 (Base Color)", Color) = (1,1,1,1)
        
        // PBR参数
        _Metallic ("金属度 (Metallic)", Range(0.0, 1.0)) = 0.0
        _Smoothness ("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.9

        // 描边参数
        _OutlineColor ("描边颜色", Color) = (0,0.8,1,1)   // 描边颜色
        _OutlineWidth ("描边宽度", Range(0.0, 0.1)) = 0.015  // 描边粗细
    }

    SubShader
    {
        // ==================== 渲染标签 ====================
        Tags { 
            "RenderType"="Opaque"           // 不透明物体
            "RenderPipeline"="UniversalPipeline" 
            "Queue"="Geometry"               // 几何队列
        }
        LOD 200

        // ============================================================================
        // ==================== Pass 1：PBR 主渲染（接收阴影） ====================
        // ============================================================================
        // 【渲染顺序】先渲染主体，再渲染描边
        // 【原理】标准PBR光照计算
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // 阴影相关宏
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _Metallic;
                float _Smoothness;
            CBUFFER_END

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            // ==================== 顶点着色器 ====================
            v2f vert (appdata v)
            {
                v2f o;
                
                // 坐标变换
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal);

                o.pos = vertexInput.positionCS;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.positionWS = vertexInput.positionWS;
                o.normalWS = normalInput.normalWS;
                return o;
            }

            // ==================== 片元着色器 ====================
            // 简化的PBR光照（Blinn-Phong + 阴影）
            half4 frag (v2f i) : SV_Target
            {
                // 纹理采样
                half4 baseTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half3 albedo = baseTex.rgb * _BaseColor.rgb;

                float3 normalWS = normalize(i.normalWS);
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);

                // 计算阴影坐标
                // TransformWorldToShadowCoord：世界坐标转阴影贴图坐标
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                
                // 获取带阴影的主光源
                Light mainLight = GetMainLight(shadowCoord);

                // --- 漫反射 ---
                float ndotl = saturate(dot(normalWS, mainLight.direction));
                
                // shadowAttenuation：阴影衰减
                // 在阴影中 = 0，不在阴影中 = 1
                half3 diffuse = albedo * mainLight.color * ndotl * mainLight.shadowAttenuation;

                // --- 镜面反射 ---
                float3 halfDir = normalize(mainLight.direction + viewDirWS);
                float spec = pow(saturate(dot(normalWS, halfDir)), _Smoothness * 128.0) * _Smoothness;
                half3 specular = spec * mainLight.color * mainLight.shadowAttenuation;

                // --- 环境光 ---
                // SampleSH：采样球谐光照（环境光）
                half3 ambient = SampleSH(normalWS) * albedo * 0.6;

                half3 finalColor = diffuse + specular + ambient;
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // ============================================================================
        // ==================== Pass 2：描边 ====================
        // ============================================================================
        // 【核心原理】
        // 1. Cull Front：剔除正面，只渲染背面
        // 2. 沿法线方向外扩顶点
        // 3. 用纯色渲染背面，形成描边效果
        // 
        // 【为什么用Cull Front】
        // 正面会覆盖背面的描边
        // 所以只渲染背面作为描边
        // 
        // 【ZTest LEqual】
        // 对应PPT："深度测试"
        // LEqual = Less or Equal
        // 当描边深度 <= 缓冲区深度时，通过测试
        // 这样描边会被前方的物体正确遮挡
        // ============================================================================
        Pass
        {
            Name "OUTLINE"
            Tags { "LightMode"="SRPDefaultUnlit" }
            
            // Cull Front：剔除正面多边形，只渲染背面
            // 【原理】
            // 默认情况下，Unity渲染顺时针顶点的面（正面）
            // Cull Front后，只渲染逆时针顶点的面（背面）
            // 
            // 【效果】
            // 背面向外扩张，正面不渲染
            // 正面主Pass会覆盖掉背面的内部部分
            // 只剩下边缘部分形成描边
            Cull Front
            
            // ZWrite On：写入深度缓冲区
            // 描边需要参与深度测试
            ZWrite On
            
            // ZTest LEqual：深度测试条件
            // 对应PPT中的"ZTest深度测试"
            // LEqual：当片元深度 <= 深度缓冲区值时通过
            // 
            // 【效果】
            // 被前方物体遮挡的描边不会显示
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert_outline
            #pragma fragment frag_outline

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _OutlineWidth;
            float4 _OutlineColor;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            // ==================== 描边顶点着色器 ====================
            // 【核心算法】沿法线方向外扩顶点
            // 
            // 【公式】
            // newPos = oldPos + normal * width
            // 
            // 【为什么要在世界空间外扩】
            // 如果在模型空间外扩，非均匀缩放会导致描边粗细不均
            // 在世界空间外扩可以避免这个问题
            // ================================================
            v2f vert_outline (appdata v)
            {
                v2f o;
                
                // Step 1: 将法线从模型空间变换到世界空间
                // TransformObjectToWorldNormal：URP内置函数
                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                
                // Step 2: 将顶点位置变换到世界空间，然后沿法线外扩
                // TransformObjectToWorld：模型空间 → 世界空间
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz) + worldNormal * _OutlineWidth;
                
                // Step 3: 世界空间 → 裁剪空间
                // TransformWorldToHClip：世界空间 → 裁剪空间
                o.pos = TransformWorldToHClip(worldPos);
                
                return o;
            }

            // ==================== 描边片元着色器 ====================
            // 简单输出描边颜色
            half4 frag_outline (v2f i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDHLSL
        }

        // ============================================================================
        // ==================== Pass 3：ShadowCaster（投射阴影） ====================
        // ============================================================================
        // 【作用】让这个物体能够投射阴影到其他物体上
        // 
        // 【原理】
        // 从光源视角渲染深度图
        // 其他物体采样这个深度图来判断是否在阴影中
        // 
        // 【ColorMask 0】
        // 不写入颜色缓冲区，只写入深度缓冲区
        // 因为阴影Pass只需要深度信息
        // ============================================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            ZWrite On
            ZTest LEqual
            
            // ColorMask 0：不写入任何颜色通道
            // 只需要深度信息，不需要颜色
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // 阴影相关宏
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            // ShadowPassVertex和ShadowPassFragment由URP内置提供
            // 自动处理从光源视角的渲染

            ENDHLSL
        }
    }
}