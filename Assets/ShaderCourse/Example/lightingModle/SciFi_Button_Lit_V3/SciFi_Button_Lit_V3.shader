Shader "Custom/SciFi_Button_Lit_V3_Clip_DoubleSided_Lerp"
{
    Properties
    {
        [Header(Base Settings)]
        _MainColor ("Energy Color", Color) = (0, 0.8, 1, 1)
        _SubColor ("Fill Color", Color) = (0, 0.1, 0.2, 1.0)
        
        [Header(Shape Control)]
        _Size ("Button Size (XY)", Vector) = (0.9, 0.4, 0, 0)
        _Sides ("Corner Sides (3-32)", Range(3, 32)) = 8
        _Roundness ("Roundness", Range(0, 1)) = 0.2
        _EdgeWidth ("Edge Width", Range(0.01, 0.2)) = 0.05
        
        [Header(Energy Flow)]
        _VoroDensity ("Energy Density", Float) = 5.0
        _VoroSpeed ("Energy Speed", Float) = 0.5
        
        [Header(Advanced Scanline)]
        _ScanColor ("Scanline Color", Color) = (1, 1, 1, 1)
        _ScanSpeed ("Scan Speed", Float) = 0.3
        _ScanWidth ("Scan Width", Range(0.001, 0.5)) = 0.05
        _ScanDensity ("Scan Density", Float) = 2.0
        _ScanAngle ("Scan Angle (Deg)", Range(0, 360)) = 45
        
        [Header(Lighting)]
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.8
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _AmbientStrength ("Ambient Strength", Range(0.0, 2.0)) = 1.0
        _Glow ("Edge Glow Intensity", Range(1, 10)) = 3.0
        
        [Header(Clip Settings)]
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        
      
    }

    SubShader
    {
        Tags 
        { 
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Cull Off
        ZWrite On

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Plugins/MyRenderUtils/Shaders/Includes/MyLibrary.hlsl"

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
                float  faceSign   : TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _MainColor, _SubColor, _ScanColor, _SpecularColor;
                float4 _Size;
                float _Sides, _Roundness, _EdgeWidth;
                float _VoroDensity, _VoroSpeed;
                float _ScanSpeed, _ScanWidth, _ScanDensity, _ScanAngle;
                float _Smoothness, _Glow, _AmbientStrength;
                float _Cutoff;
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs posInput = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs normInput = GetVertexNormalInputs(v.normal);

                o.posCS = posInput.positionCS;
                o.positionWS = posInput.positionWS;
                o.normalWS = normInput.normalWS;
                o.uv = v.uv;
                o.faceSign = dot(normInput.normalWS, GetWorldSpaceNormalizeViewDir(posInput.positionWS)) > 0 ? 1 : -1;
                return o;
            }
            float3 ScifiButton(v2f i)
            {
                // ==================== 形状生成 ====================
                float mask = RoundedPolygon(i.uv, _Size.x, _Size.y, _Sides, _Roundness);
                float inner = RoundedPolygon(i.uv, _Size.x - _EdgeWidth, _Size.y - _EdgeWidth, _Sides, _Roundness);
                float edge = saturate(mask - inner);

                // ==================== 能量流动 ====================
                float vDist, vID;
                Voronoi(i.uv, _Time.y * _VoroSpeed, _VoroDensity, vDist, vID);
                
                float hoverBreathe =  0.15 * sin(_Time.z * 5.0);
                float3 activeColor = _MainColor.rgb * (1.0 +  hoverBreathe);
                
                float3 energyFlow = lerp(_SubColor.rgb, activeColor, (1.0 - vID) * 0.3);

                // ==================== 扫描线 ====================
                float2 rotatedUV = RotateDegrees(i.uv, float2(0.5, 0.5), _ScanAngle);
                float scanMask = ScanLine(rotatedUV, _ScanSpeed, _ScanWidth, _ScanDensity, 0);
                float3 scanEffect = _ScanColor.rgb * scanMask * _ScanColor.a;

                // ==================== 【关键修改】使用 lerp 层层融合 ====================
                // 1. 基础能量
                float3 baseColor = energyFlow;

                // 2. 融合扫描线（使用 lerp 代替 Screen Blend）
                float scanBlend = scanMask * 0.6;                    // 控制扫描线混合强度
                baseColor = lerp(baseColor, scanEffect, scanBlend);

                // 3. 融合边缘发光
                float edgeBlend = edge * _Glow * 0.25;               // 可调节强度
                baseColor = lerp(baseColor, activeColor, edgeBlend);

                // 4. 融合 Hover 高亮
                float hoverBlend = mask *  0.35;
                baseColor = lerp(baseColor, activeColor, hoverBlend);
                return baseColor;
            }
            float3 LightingCalculate(v2f i)
            {
                float3 baseColor=ScifiButton(i);

                float3 N = normalize(i.normalWS) * i.faceSign;
                float3 V = GetWorldSpaceNormalizeViewDir(i.positionWS);
                Light mainLight = GetMainLight();


                // ==================== 光照计算 ====================
                float ndotl = saturate(dot(N, mainLight.direction));
                half3 diffuse = baseColor * mainLight.color * ndotl;

                float3 H = normalize(mainLight.direction + V);
                float ndoth = saturate(dot(N, H));
                float specPower = pow(ndoth, _Smoothness * 128.0 + 1.0);
                half3 specular = _SpecularColor.rgb * mainLight.color * specPower * 2.0;

                half3 shAmbient = SampleSH(N);
                half3 ambient = baseColor * shAmbient * _AmbientStrength;

                float attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;

                half3 finalRGB = ambient + (diffuse + specular) * attenuation;
                return finalRGB ;
            }

            half4 frag (v2f i) : SV_Target
            {

                float3 finalRGB =LightingCalculate(i);
                float mask = RoundedPolygon(i.uv, _Size.x, _Size.y, _Sides, _Roundness);
                // ==================== Alpha Clip ====================
               // float finalAlpha = mask * (_SubColor.a + edge * 1.2 + scanMask * 0.5);
                clip(mask - _Cutoff);

                return half4(finalRGB, 1.0);
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Simple Lit"
}