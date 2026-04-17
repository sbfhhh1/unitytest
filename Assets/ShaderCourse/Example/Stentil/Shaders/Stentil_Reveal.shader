// ============================================================================
// Stentil_Reveal.shader - Reveal Plane Shader（透视内部形状）
// ============================================================================
//
// 【Reveal Plane 的作用】
// Reveal Plane 是放置在装配体内部的半透明平面，用于"显示"内部形状的内容。
// 它本身用标准 PBR 渲染，叠加在几何体之上，让用户能透过它看到内部。
//
// 【两种 Reveal Plane 方案】
//
// 【方案 A：纯透明平面（无 Stencil）】
// 适合效果：透视内部结构（就像玻璃观察窗）
// 设置：Standard Shader + Transparent 渲染队列
//
// 【方案 B：Stencil 遮蔽（用于不可能几何体）】
// 适合效果：每个 Reveal Plane 只显示特定 ID 的形状
// 设置：Stencil { Ref X Comp Equal Pass Keep }
//
// 本 Shader 采用方案 B，演示 Stencil 遮蔽的 Reveal Plane 用法。
//
// 【Stencil 参数解释】
// Ref [_StencilID]   → Reveal Plane 的 Stencil ID
// Comp Always        → 所有像素都通过（Allow All）
// Pass Keep          → 通过后保留当前 Stencil 值
//
// 为什么用 Always/Keep？
// Reveal Plane 的 Stencil 设置只是为了让它的像素通过测试（不被遮挡）。
// 它本身不需要写入或检查 Stencil 值。
//
// 如果 Reveal Plane 用 Comp Always Pass Keep，
// 那么它的像素会正常渲染（前提是深度通过）。
// 深度测试在 Stencil 测试之前执行，所以深度决定哪些像素能走到 Stencil 阶段。
// ============================================================================

Shader "ShaderCourse/Stentil_Reveal"
{
    Properties
    {
        // Reveal Plane 自身的 Stencil ID（用于调试显示）
        _StencilID ("Stencil ID (0-255)", Range(0, 255)) = 1

        // 基础颜色（用于区分不同面）
        [HDR] _BaseColor ("基础颜色 (Base Color)", Color) = (1, 1, 1, 0.05)

        // 是否开启 Reveal 模式（关闭时为普通透明平面）
        [Toggle(_REVEAL_MODE)] _EnableRevealMode ("开启 Reveal 模式", Float) = 1

        // Reveal 模式下显示的颜色
        [HDR] _RevealColor ("Reveal 颜色", Color) = (0.2, 0.8, 1, 0.3)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"     = "Transparent"
            "Queue"         = "Transparent"
        }

        Pass
        {
            // 透明混合模式：Source × SourceAlpha + Dest × (1 - SourceAlpha)
            Blend SrcAlpha OneMinusSrcAlpha

            // 不写入深度（半透明物体不应遮挡后面的不透明物体）
            ZWrite Off

            // 半透明物体通常用 LEqual（渲染在 Geometry 之后）
            ZTest LEqual

            // --------------------------------------------------------------------
            // 【Stencil 设置（Reveal 模式）】
            //
            // Reveal Plane 的Stencil ID 与对应的形状 ID 相同。
            // 例如：Sphere 用 ID=1，则 Front Reveal Plane 也用 ID=1。
            // 这样 Reveal Plane 只会显示 Sphere 旋转到它面前时的像素。
            //
            // 为什么用 Comp Always Pass Keep？
            // Reveal Plane 需要渲染在装配体内部的像素上。
            // 由于 Reveal Plane 在装配体内部，它本身不需要遮蔽任何东西。
            // Comp Always = 始终通过（不对现有 Stencil 值做任何限制）
            // Pass Keep = 渲染后保留 Stencil 值不变
            // --------------------------------------------------------------------
            Stencil
            {
                Ref [_StencilID]
                Comp Always
                Pass Keep
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _REVEAL_MODE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _StencilID;
                float4 _RevealColor;
            CBUFFER_END

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.positionHCS = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                // 简单的法线朝向光照
                half3 n = normalize(i.normalWS);
                half3 lightDir = normalize(_MainLightPosition.xyz);
                half3 viewDir = normalize(GetWorldSpaceNormalizeViewDir(i.positionWS));
                half3 halfVec = normalize(lightDir + viewDir);

                half NdotL = max(0, dot(n, lightDir)) * 0.5 + 0.5;
                half spec = pow(max(0, dot(n, halfVec)), 32) * 0.2;

                half3 baseCol = _BaseColor.rgb * NdotL + spec;

                #if defined(_REVEAL_MODE)
                    // Reveal 模式：使用 RevealColor，半透明叠加
                    half alpha = _RevealColor.a;
                    half3 col = lerp(baseCol, _RevealColor.rgb * NdotL, 0.7);
                    return half4(col, alpha);
                #else
                    return half4(baseCol, _BaseColor.a);
                #endif
            }
            ENDHLSL
        }
    }
}
