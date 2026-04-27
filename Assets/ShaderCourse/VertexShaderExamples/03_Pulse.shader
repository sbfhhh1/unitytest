Shader "TA_Course/VertexShader/Pulse"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _PulseSpeed ("Pulse Speed", Range(0.1, 5)) = 1.0
        _PulseStrength ("Pulse Strength", Range(0, 0.5)) = 0.1
        _PulseColor ("Pulse Color", Color) = (0.2, 0.8, 1, 1)
        _RimPower ("Rim Power", Range(1, 10)) = 3.0
        _RimIntensity ("Rim Intensity", Range(0, 5)) = 1.0
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
                float3 normalWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _PulseSpeed;
                float _PulseStrength;
                float4 _PulseColor;
                float _RimPower;
                float _RimIntensity;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            v2f vert (appdata v)
            {
                v2f o;
                
                half3 normalWS = TransformObjectToWorldNormal(v.normal);
                
                half pulseFactor = abs(sin(_Time.y * _PulseSpeed));
                
                half3 expandedPos = v.vertex.xyz + normalWS * pulseFactor * _PulseStrength;
                
                half3 worldPos = TransformObjectToWorld(expandedPos);
                o.worldPos = worldPos;
                o.pos = TransformWorldToHClip(worldPos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = normalWS;
                o.viewDirWS = _WorldSpaceCameraPos.xyz - worldPos;
                
                return o;
            }
            
            half4 frag (v2f i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                half3 normalWS = normalize(i.normalWS);
                half3 viewDirWS = normalize(i.viewDirWS);
                
                Light mainLight = GetMainLight();
                half ndotl = saturate(dot(normalWS, mainLight.direction));
                half3 baseColor = tex.rgb * _BaseColor.rgb * mainLight.color * ndotl;
                
                half fresnel = pow(1.0 - saturate(dot(viewDirWS, normalWS)), _RimPower);
                
                half pulseFactor = abs(sin(_Time.y * _PulseSpeed));
                half3 pulseEffect = _PulseColor.rgb * fresnel * _RimIntensity * pulseFactor;
                
                half3 finalColor = baseColor + pulseEffect;
                
                return half4(finalColor, tex.a * _BaseColor.a);
            }
            ENDHLSL
        }
    }
}