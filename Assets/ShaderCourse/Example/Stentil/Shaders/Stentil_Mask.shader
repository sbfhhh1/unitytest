Shader "ShaderCourse/Stentil_Mask"
{
    Properties
    {
        // 这个值会被写入模板缓冲。
        // 后面读取模板的物体，只有 ID 相同才会显示。
        _StencilID ("模板 ID", Range(0, 255)) = 1
    }

    SubShader
    {
        Tags
        {
            // 这套模板只面向 URP。
            "RenderPipeline" = "UniversalPipeline"

            // Mask 本身不是透明物体，但它也不会真正输出颜色。
            "RenderType" = "Opaque"

            // 让 Mask 比普通几何体更早渲染。
            // 这样模板值会先写好，后面的 Geometry 才能正确读取。
            "Queue" = "Geometry-1"
        }

        Pass
        {
            Name "StencilMask"

            // ColorMask 0：不写入任何颜色通道。
            // 也就是说，这个物体虽然被渲染，但屏幕上看不见它。
            ColorMask 0

            // 不写深度。
            // 如果这里写深度，后面的内容物体可能会被深度测试挡住。
            ZWrite Off

            // Always：无论当前深度缓冲里有什么，都执行这次绘制。
            // 教学案例里，这样最直观，能稳定把模板值写进去。
            ZTest Always

            // 模板写入规则：
            // Ref [_StencilID]     当前材质设定的模板值
            // Comp Always          一定通过模板比较
            // Pass Replace         通过后，把当前像素的模板值替换成 Ref
            Stencil
            {
                Ref [_StencilID]
                Comp Always
                Pass Replace
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            // 顶点着色器只做一件事：
            // 把模型空间顶点转换到裁剪空间，交给 GPU 光栅化。
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            // 片元着色器返回 0。
            // 因为上面已经 ColorMask 0 了，这里的颜色不会真正写进屏幕。
            // 关键效果来自 Stencil，而不是颜色输出。
            half4 frag(Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
