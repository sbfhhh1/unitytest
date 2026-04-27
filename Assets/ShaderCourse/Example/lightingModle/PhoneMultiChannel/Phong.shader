Shader "lit/Phong"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_NormalMap("NormalMap",2D) = "bump" {}
		_NormalIntensity("Normal Intensity",Range(0.0,5.0)) = 1.0
		_AOMap("AO Map",2D) = "white" {}
		_SpecMask("Spec Mask",2D) = "white" {}
		_Shininess("Shininess",Range(0.01,100)) = 1.0
		_SpecIntensity("SpecIntensity",Range(0.01,5)) = 1.0
		_ParallaxMap("ParallaxMap",2D) = "black" {}
		_Parallax("_Parallax",float) = 2
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
		LOD 100

		Pass
		{
			Tags { "LightMode" = "UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// URP 光照关键字：主光阴影、附加光、附加光阴影、软阴影
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile _ _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _SHADOWS_SOFT

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Assets/Plugins/MyRenderUtils/Shaders/Includes/MyShadingLibrary.hlsl"

			struct Attributes
			{
				float4 positionOS : POSITION;
				float2 uv : TEXCOORD0;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
				float3 tangentWS : TEXCOORD3;
				float3 bitangentWS : TEXCOORD4;
				float4 shadowCoord : TEXCOORD5;
			};

			struct SurfaceDataCustom
			{
				float3 baseColor;
				float3 ao;
				float3 specMask;
				float3 normalWS;
			};

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);
			TEXTURE2D(_AOMap);
			SAMPLER(sampler_AOMap);
			TEXTURE2D(_SpecMask);
			SAMPLER(sampler_SpecMask);
			TEXTURE2D(_ParallaxMap);
			SAMPLER(sampler_ParallaxMap);

			// URP/SRP Batcher 材质参数：统一放在 UnityPerMaterial
			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
				float _NormalIntensity;
				float _Shininess;
				float _SpecIntensity;
				float _Parallax;
			CBUFFER_END

			// 采样主贴图/AO/高光遮罩/法线，并把法线从切线空间转到世界空间
			SurfaceDataCustom SampleSurfaceData(float2 uvParallax, float3x3 tbn)
			{
				SurfaceDataCustom s;

				float3 baseColorSRGB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvParallax).rgb;
				// 保留旧逻辑：先手动转到近似线性空间，再参与光照
				s.baseColor = SRGBToLinearApprox(baseColorSRGB);

				s.ao = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, uvParallax).rgb;
				s.specMask = SAMPLE_TEXTURE2D(_SpecMask, sampler_SpecMask, uvParallax).rgb;

				float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uvParallax));
				s.normalWS = ApplyNormalTSToWS(normalTS, tbn, _NormalIntensity);

				return s;
			}

			Varyings vert(Attributes v)
			{
				// 顶点阶段输出结构体：把后续片元阶段会用到的数据打包传下去
				Varyings o;

				// URP 内置的顶点空间转换结果：
				// - positionCS: 裁剪空间坐标（用于光栅化，必须输出到 SV_POSITION）
				// - positionWS: 世界空间坐标（用于视线方向、阴影采样、附加光计算）
				VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
				// URP 内置法线基向量结果：
				// - normalWS / tangentWS / bitangentWS 已考虑对象变换（含缩放）后的方向
				VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS, v.tangentOS);

				// 顶点最终位置（裁剪空间），GPU 后续据此完成三角形光栅化
				o.positionHCS = positionInputs.positionCS;
				// 世界空间位置传给片元：用于计算 viewDirWS、点光源方向等
				o.positionWS = positionInputs.positionWS;
				// 阴影坐标：主光阴影图采样要用
				o.shadowCoord = TransformWorldToShadowCoord(positionInputs.positionWS);
				// 纹理坐标变换：uv * tiling + offset（由 _MainTex_ST 驱动）
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				// 三个方向都再归一化一遍，避免插值和数值误差放大
				o.normalWS = normalize(normalInputs.normalWS);
				o.tangentWS = normalize(normalInputs.tangentWS);
				o.bitangentWS = normalize(normalInputs.bitangentWS);

				// 返回到光栅化阶段，随后会插值后传给 frag(Varyings i)
				return o;
			}

			half4 frag(Varyings i) : SV_Target
			{
				// 1) 视线方向（世界空间）：从当前片元指向相机
				float3 viewDirWS = normalize(GetWorldSpaceViewDir(i.positionWS));
				// 2) 取回插值后的世界空间法线/切线/副切线，并再次归一化
				float3 normalWS = normalize(i.normalWS);
				float3 tangentWS = normalize(i.tangentWS);
				float3 bitangentWS = normalize(i.bitangentWS);

				// 3) 构建 TBN 矩阵：把切线空间向量和世界空间向量互相变换的基底
				float3x3 tbn = BuildTBN(tangentWS, bitangentWS, normalWS);
				// 4) 把视线方向投到切线空间，供视差映射使用
				float3 viewDirTS = normalize(mul(tbn, viewDirWS));
				// 5) 视差迭代：根据高度图 + 视线方向偏移 UV，得到更有深度感的采样坐标
				float2 uvParallax = ApplyParallaxUVIterative(
					TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap),
					i.uv,
					viewDirTS,
					_Parallax,
					10
				);

				// 6) 用“同一套偏移后的 uvParallax”采样主纹理/AO/高光遮罩/法线，保证一致性
				SurfaceDataCustom s = SampleSurfaceData(uvParallax, tbn);

				// 主平行光（含阴影衰减）
				Light mainLight = GetMainLight(i.shadowCoord);
				float3 colorAccum = EvaluatePhongLighting(
					s.normalWS,
					normalize(mainLight.direction),
					viewDirWS,
					mainLight.color,
					mainLight.distanceAttenuation * mainLight.shadowAttenuation,
					s.baseColor,
					s.specMask,
					_Shininess,
					_SpecIntensity
				);

				

				// 与旧版一致：环境光 + AO，再做 ACES + Gamma 输出
				float3 ambient = SampleSH(s.normalWS) * s.baseColor;
				float3 finalColor = (colorAccum + ambient) * s.ao;
				float3 toneColor = ToneMapACES(finalColor);
				toneColor = LinearToSRGBApprox(toneColor);

				return half4(toneColor, 1.0);
			}
			ENDHLSL
		}
	}
}
