Shader "Custom/SciFi_Ultimate_Button_V2"
{
    Properties
    {
        [Header(Base Settings)]
        _MainColor ("Energy Color", Color) = (0, 0.8, 1, 1)
        _SubColor ("Fill Color", Color) = (0, 0.1, 0.2, 0.8)
        
        [Header(Shape Control)]
        _Size ("Button Size (XY)", Vector) = (0.9, 0.4, 0, 0)
        _Sides ("Corner Sides (3-32)", Range(3, 32)) = 8
        _Roundness ("Roundness", Range(0, 1)) = 0.2
        _EdgeWidth ("Edge Width", Range(0.01, 0.2)) = 0.05
        
        [Header(Energy Flow)]
        _VoroDensity ("Energy Density", Float) = 5.0
        _VoroSpeed ("Energy Speed", Float) = 0.5
        _NoiseThreshold ("Noise Threshold", Range(0, 1)) = 0.5 // 噪声阈值
        _NoiseSoftness ("Noise Softness (虚实)", Range(0.001, 0.5)) = 0.1 // 虚实控制
        [Header(Advanced Scanline)]
        _ScanColor ("Scanline Color", Color) = (1, 1, 1, 1) // 新增：扫描线颜色
        _ScanSpeed ("Scan Speed", Float) = 0.3
        _ScanWidth ("Scan Width", Range(0.001, 0.5)) = 0.05
        _ScanDensity ("Scan Density", Float) = 2.0
        _ScanAngle ("Scan Angle (Deg)", Range(0, 360)) = 45
        
        [Header(Interaction)]
        _Glow ("Edge Glow Intensity", Range(1, 10)) = 2.0
        _Hover ("Hover Intensity", Range(0, 1)) = 0.0 // 由 C# 脚本控制
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Assets/Plugins/MyRenderUtils/Shaders/Includes/MyLibrary.hlsl"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float4 _MainColor, _SubColor, _ScanColor, _Size;
            float _Sides, _Roundness, _EdgeWidth, _Glow, _Hover,_NoiseThreshold, _NoiseSoftness;
            float _VoroDensity, _VoroSpeed, _ScanSpeed, _ScanWidth, _ScanDensity, _ScanAngle;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 1. 交互增强逻辑
                // 悬停时颜色亮度提升，并带有基于时间的轻微闪烁
                float hoverBreathe = _Hover * 0.15 * sin(_Time.z * 5.0);
                float3 activeColor = _MainColor.rgb * (1.0 + _Hover + hoverBreathe);
                
                // 2. 形状构建 (使用 Sides 动态控制)
                float mask = RoundedPolygon(i.uv, _Size.x, _Size.y, _Sides, _Roundness);
                float inner = RoundedPolygon(i.uv, _Size.x - _EdgeWidth, _Size.y - _EdgeWidth, _Sides, _Roundness);
                float edge = saturate(mask - inner);

                // 3. 内部能量细节
                float vDist, vID;
                Voronoi(i.uv, _Time.y * _VoroSpeed, _VoroDensity, vDist, vID);
              
                float3 energyFlow = lerp(_SubColor.rgb, activeColor, (1.0 -vID) * 0.2);

                // 4. 扫描线逻辑 (支持独立颜色和旋转)
                float2 rotatedUV = RotateDegrees(i.uv, float2(0.5, 0.5), _ScanAngle);
                float scanMask = ScanLine(rotatedUV, _ScanSpeed, _ScanWidth, _ScanDensity, 0);
                float3 scanEffect = _ScanColor.rgb * scanMask * _ScanColor.a;
                
                // 5. 颜色合成
                float3 finalRGB = energyFlow;
                // 混合扫描线
                finalRGB = Blend_Screen(finalRGB, scanEffect, 1.0);
                // 混合边缘发光
                finalRGB += edge * activeColor * _Glow;
                
                // 6. 交互高亮 (Hover 时整体提亮)
                finalRGB += mask * _Hover * activeColor * 0.3;

                // 透明度控制
                float finalAlpha = mask * (_SubColor.a + edge + scanMask);

                return float4(finalRGB, saturate(finalAlpha));
            }
            ENDCG
        }
    }
}