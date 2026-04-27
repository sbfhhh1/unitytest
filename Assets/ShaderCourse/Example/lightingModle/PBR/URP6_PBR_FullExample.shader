Shader "Custom/URP6_PBR_FullExample_MaskMap_TBNFixed"
{
    Properties
    {
        [Header(Main Textures)]
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (1,1,1,1)

        [Header(Normal Map)]
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Range(0, 2)) = 1

        [Header(Mask Map)]
        _MaskMap ("Mask Map (R=Metal G=AO B=Emissive A=Smooth)", 2D) = "white" {}

        [Header(PBR Controls)]
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5

        [Header(Emission)]
        _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionStrength ("Emission Strength", Range(0, 8)) = 1

        [Header(Lighting Controls)]
        _DirectLightStrength ("Direct Light Strength", Range(0, 2)) = 1
        _IndirectDiffuseStrength ("Indirect Diffuse Strength", Range(0, 2)) = 0.35
        _IndirectSpecularStrength ("Indirect Specular Strength", Range(0, 2)) = 0.45
        _OcclusionStrength ("Occlusion Strength", Range(0, 2)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _NormalMap_ST;
                float4 _MaskMap_ST;
                float4 _EmissionColor;
                float _NormalScale;
                float _EmissionStrength;
                float _DirectLightStrength;
                float _IndirectDiffuseStrength;
                float _IndirectSpecularStrength;
                float _OcclusionStrength;
                float _Metallic;
                float _Smoothness;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MaskMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                half fogFactor : TEXCOORD5;
            };

            float DistributionGGX(float3 N, float3 H, float roughness)
            {
                float a = max(0.001, roughness * roughness);
                float a2 = a * a;
                float NdotH = saturate(dot(N, H));
                float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
                return a2 / max(PI * denom * denom, 1e-4);
            }

            float GeometrySchlickGGX(float NdotV, float roughness)
            {
                float r = roughness + 1.0;
                float k = (r * r) / 8.0;
                return NdotV / max(NdotV * (1.0 - k) + k, 1e-4);
            }

            float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
            {
                float NdotV = saturate(dot(N, V));
                float NdotL = saturate(dot(N, L));
                float ggxV = GeometrySchlickGGX(NdotV, roughness);
                float ggxL = GeometrySchlickGGX(NdotL, roughness);
                return ggxV * ggxL;
            }

            float3 FresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.normalWS = normalize(normalInputs.normalWS);
                output.tangentWS = normalize(normalInputs.tangentWS);
                output.bitangentWS = normalize(normalInputs.bitangentWS);
                output.fogFactor = ComputeFogFactor(posInputs.positionCS.z);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);

                half metallic = saturate(mask.r * _Metallic);
                half ao = saturate(mask.g);
                half emissiveMask = saturate(mask.b);
                half smoothness = saturate(mask.a * _Smoothness);
                half roughness = 1.0h - smoothness; // perceptual roughness (maps to GGX alpha via squaring in DistributionGGX)
                roughness = max(roughness, 0.088h); // minimum perceptual roughness, matches URP's HALF_MIN_SQRT clamp

                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalScale);
                half3x3 tbn = half3x3(normalize(input.tangentWS), normalize(input.bitangentWS), normalize(input.normalWS));
                half3 N = normalize(TransformTangentToWorld(normalTS, tbn));

                half3 albedo = baseSample.rgb * _BaseColor.rgb;
                half3 V = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
                Light mainLight = GetMainLight();
                half3 L = normalize(mainLight.direction);
                half3 H = SafeNormalize(V + L);

                half3 F0 = lerp(half3(0.04h, 0.04h, 0.04h), albedo, metallic);
                half NdotL = saturate(dot(N, L));
                half NdotV = saturate(dot(N, V));
                half HdotV = saturate(dot(H, V));

                half D = DistributionGGX(N, H, roughness);
                half G = GeometrySmith(N, V, L, roughness);
                half3 F = FresnelSchlick(HdotV, F0);

                half3 specular = (D * G * F) / max(4.0h * NdotL * NdotV, 1e-4h);
                half3 kS = F;
                half3 kD = (1.0h - kS) * (1.0h - metallic);

                half occlusion = lerp(1.0h, ao, saturate(_OcclusionStrength));
                half3 directColor = (kD * albedo + specular) * mainLight.color * NdotL * _DirectLightStrength;

                half3 indirectDiffuse = SampleSH(N) * albedo * kD * occlusion * _IndirectDiffuseStrength;

                half3 R = reflect(-V, N);
                half3 indirectSpecular = GlossyEnvironmentReflection(R, input.positionWS, roughness, 1.0);
                indirectSpecular *= lerp(occlusion, 1.0h, metallic) * _IndirectSpecularStrength;

                half3 emission = emissiveMask * _EmissionColor.rgb * _EmissionStrength;
                half3 color = directColor + indirectDiffuse + indirectSpecular + emission;
                color = MixFog(color, input.fogFactor);

                return half4(color, 1.0h);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_shadowcaster
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _NormalMap_ST;
                float4 _MaskMap_ST;
                float4 _EmissionColor;
                float _NormalScale;
                float _EmissionStrength;
                float _DirectLightStrength;
                float _IndirectDiffuseStrength;
                float _IndirectSpecularStrength;
                float _OcclusionStrength;
                float _Metallic;
                float _Smoothness;
            CBUFFER_END

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack Off
}
