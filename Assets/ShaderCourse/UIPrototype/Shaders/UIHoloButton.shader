Shader "ShaderCourse/UI/HoloButton"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.05, 0.12, 0.20, 1.0)
        _AccentColor ("Accent Color", Color) = (0.40, 0.90, 1.00, 1.00)
        _SecondaryColor ("Secondary Color", Color) = (0.12, 0.28, 0.45, 1.00)
        _CornerRadius ("Corner Radius", Range(0.01, 0.4)) = 0.18
        _EdgeWidth ("Edge Width", Range(0.002, 0.1)) = 0.022
        _Hover ("Hover", Range(0, 1)) = 0
        _Pressed ("Pressed", Range(0, 1)) = 0
        _Selected ("Selected", Range(0, 1)) = 0
        _SweepOffset ("Sweep Offset", Float) = 0
        _SweepWidth ("Sweep Width", Range(0.02, 0.4)) = 0.24
        _ScanAngle ("Scan Angle", Range(-180, 180)) = 45
        _NoiseTiling ("Noise Tiling", Float) = 28
        _RectSize ("Rect Size", Vector) = (320, 72, 0, 0)
        _ClipRect ("Clip Rect", Vector) = (-32767, -32767, 32767, 32767)
        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
        _ColorMask ("Color Mask", Float) = 15
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "UIHoloButton"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata_t
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                half4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _AccentColor;
                half4 _SecondaryColor;
                float _CornerRadius;
                float _EdgeWidth;
                float _Hover;
                float _Pressed;
                float _Selected;
                float _SweepOffset;
                float _SweepWidth;
                float _ScanAngle;
                float _NoiseTiling;
                float4 _RectSize;
            CBUFFER_END

            float RoundedRectangle(float2 uv, float width, float height, float radius)
            {
                radius = max(min(min(abs(radius * 2.0), abs(width)), abs(height)), 1e-5);
                float2 d = abs(uv * 2.0 - 1.0) - float2(width, height) + radius;
                float dist = length(max(0.0, d)) / radius;
                float fwd = max(fwidth(dist), 1e-5);
                return saturate((1.0 - dist) / fwd);
            }

            float RoundedRectangleAspect(float2 uv, float width, float height, float radius, float aspect)
            {
                float2 correctedUv = (uv - 0.5) * float2(aspect, 1.0) + 0.5;
                return RoundedRectangle(correctedUv, width * aspect, height, radius);
            }

            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 345.45));
                p += dot(p, p + 34.23);
                return frac(p.x * p.y);
            }

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.texcoord;
                o.color = v.color;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float aspect = max(_RectSize.x / max(_RectSize.y, 1.0), 1.0);
                float outer = RoundedRectangleAspect(uv, 0.94, 0.84, _CornerRadius, aspect);
                float inner = RoundedRectangleAspect(uv, 0.94 - _EdgeWidth * 3.0, 0.84 - _EdgeWidth * 4.2, max(_CornerRadius - _EdgeWidth * 1.35, 0.01), aspect);
                float bodyMask = outer;
                float borderMask = saturate(outer - inner);

                float pulse = saturate(_Hover * 0.85 + _Selected * 1.15 - _Pressed * 0.25);
                float angleRad = radians(_ScanAngle);
                float2 scanDir = normalize(float2(cos(angleRad), sin(angleRad)));
                float2 centeredUv = uv - 0.5;
                float2 correctedUv = float2(centeredUv.x * aspect, centeredUv.y);
                float scanCoord = dot(correctedUv, scanDir);
                float scan = frac(scanCoord * (_NoiseTiling * 0.76) - _Time.y * (0.90 + _Hover * 0.35) + _SweepOffset);
                float scanBands = smoothstep(0.10, 0.38, scan) * (1.0 - smoothstep(0.58, 0.92, scan));
                float scanWide = smoothstep(0.00, _SweepWidth, scan) * (1.0 - smoothstep(_SweepWidth, _SweepWidth + 0.22, scan));
                float scanSoft = sin(scanCoord * (_NoiseTiling * 0.90) - _Time.y * 2.8) * 0.5 + 0.5;
                float topLine = smoothstep(0.86, 0.98, uv.y);
                float bottomShade = 1.0 - smoothstep(0.08, 0.25, uv.y);
                float noise = hash21(floor(uv * _NoiseTiling) + floor(_Time.y * 6.0));

                half3 baseCol = lerp(_BaseColor.rgb, _SecondaryColor.rgb, saturate(uv.y * 1.1));
                baseCol += scanBands * _AccentColor.rgb * 0.16;
                baseCol += scanWide * _AccentColor.rgb * (0.18 + pulse * 0.12);
                baseCol += scanSoft * 0.03;
                baseCol += borderMask * _AccentColor.rgb * (0.70 + pulse * 0.45);
                baseCol += topLine * _AccentColor.rgb * 0.18;
                baseCol += noise * 0.012;
                baseCol -= bottomShade * 0.08;
                baseCol = lerp(baseCol, baseCol + _AccentColor.rgb * 0.08, pulse);
                baseCol -= _Pressed * 0.10;

                float alpha = bodyMask * saturate(0.96 + borderMask * 0.18 + pulse * 0.06) * i.color.a;
                return half4(baseCol * i.color.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
