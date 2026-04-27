Shader "ShaderCourse/ToonPBR_Object_URP"
{
    Properties
    {
        [MainTexture] _BaseMap ("主贴图", 2D) = "white" {}
        [MainColor] _BaseColor ("主颜色", Color) = (1, 1, 1, 1)

        _Metallic ("金属度", Range(0, 1)) = 0
        _Smoothness ("光滑度", Range(0, 1)) = 0.75

        _ShadowStep ("阴影分界", Range(0, 1)) = 0.45
        _HighlightStep ("高光分界", Range(0, 1)) = 0.82
        _BandSoftness ("分层软化", Range(0.001, 0.2)) = 0.04
        _ShadowStrength ("阴影强度", Range(0, 1)) = 0.55

        _SpecularColor ("高光颜色", Color) = (1, 1, 1, 1)
        _RimColor ("边缘光颜色", Color) = (0.8, 0.9, 1.0, 1.0)
        _RimPower ("边缘光指数", Range(0.5, 8)) = 3.2
        _RimStrength ("边缘光强度", Range(0, 2)) = 0.45

        _ReflectionTint ("反射颜色", Color) = (1, 1, 1, 1)
        _IBLStrength ("环境反射强度", Range(0, 2)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "UniversalMaterialType" = "Lit"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/ShaderCourse/Example/ToonWater/ToonPBRLightingCommon.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float4 _SpecularColor;
                float4 _RimColor;
                float4 _ReflectionTint;
                half _Metallic;
                half _Smoothness;
                half _ShadowStep;
                half _HighlightStep;
                half _BandSoftness;
                half _ShadowStrength;
                half _RimPower;
                half _RimStrength;
                half _IBLStrength;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalize(normalInputs.normalWS);
                output.shadowCoord = GetShadowCoord(positionInputs);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = baseTex.rgb * _BaseColor.rgb;

                half3 normalWS = normalize(input.normalWS);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));

                ToonPBRLightingInput lightingInput;
                lightingInput.albedo = albedo;
                lightingInput.normalWS = normalWS;
                lightingInput.viewDirWS = viewDirWS;
                lightingInput.positionWS = input.positionWS;
                lightingInput.shadowCoord = input.shadowCoord;

                ToonPBRLightingParams lightingParams;
                lightingParams.metallic = _Metallic;
                lightingParams.smoothness = _Smoothness;
                lightingParams.shadowStep = _ShadowStep;
                lightingParams.highlightStep = _HighlightStep;
                lightingParams.bandSoftness = _BandSoftness;
                lightingParams.shadowStrength = _ShadowStrength;
                lightingParams.specularColor = _SpecularColor.rgb;
                lightingParams.rimColor = _RimColor.rgb;
                lightingParams.rimPower = _RimPower;
                lightingParams.rimStrength = _RimStrength;
                lightingParams.reflectionTint = _ReflectionTint.rgb;
                lightingParams.iblStrength = _IBLStrength;

                half3 finalColor = EvaluateToonPBRLighting(lightingInput, lightingParams);

                return half4(finalColor, baseTex.a * _BaseColor.a);
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
            #pragma target 2.0
            #pragma vertex ShadowCasterVertex
            #pragma fragment ShadowCasterFragment

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowCasterAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct ShadowCasterVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            ShadowCasterVaryings ShadowCasterVertex(ShadowCasterAttributes input)
            {
                ShadowCasterVaryings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                return output;
            }

            half ShadowCasterFragment(ShadowCasterVaryings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct DepthOnlyAttributes
            {
                float4 positionOS : POSITION;
            };

            struct DepthOnlyVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            DepthOnlyVaryings DepthOnlyVertex(DepthOnlyAttributes input)
            {
                DepthOnlyVaryings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half DepthOnlyFragment(DepthOnlyVaryings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct DNAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct DNVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };

            DNVaryings DepthNormalsVertex(DNAttributes input)
            {
                DNVaryings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                return output;
            }

            void DepthNormalsFragment(
                DNVaryings input
                , out half4 outNormalWS : SV_Target0
            )
            {
                outNormalWS = half4(normalize(input.normalWS), 0.0);
            }
            ENDHLSL
        }
    }
}
