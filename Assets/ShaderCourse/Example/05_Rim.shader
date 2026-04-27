Shader "CS02/Rim" //Shader的真正名字  可以是路径式的格式
{
	/*材质球参数及UI面板
	https://docs.unity3d.com/cn/current/Manual/SL-Properties.html
	https://docs.unity3d.com/cn/current/ScriptReference/MaterialPropertyDrawer.html
	*/
	Properties 
	{
		_MainTex ("Texture", 2D) = "" {}
		_MainColor("Main Color",Color) = (1,1,1,1)
		_Emiss("Emiss", Float) = 1.0
		_Speed("Speed", Vector) = (.34, .85, .92, 1)
	}
	SubShader
	{
		/*
		标签属性，有两种：一种是SubShader层级，一种在Pass层级
		https://docs.unity3d.com/cn/current/Manual/SL-SubShaderTags.html
		https://docs.unity3d.com/cn/current/Manual/SL-PassTags.html
		*/
		Tags { "Queue" = "Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
		Pass {
			Tags { "LightMode" = "DepthOnly" }
			Cull Off 
			ZWrite On 
			ColorMask 0
			HLSLPROGRAM
			#pragma vertex vert 
			#pragma fragment frag
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			// URP/SRP Batcher 材质常量缓冲：本 Pass 只需要 _MainColor
			CBUFFER_START(UnityPerMaterial)
				float4 _MainColor;
			CBUFFER_END

			// DepthOnly 顶点阶段：只负责输出裁剪空间坐标用于写深度，不做额外光照计算
			float4 vert(float4 positionOS : POSITION) : SV_POSITION
			{
				return TransformObjectToHClip(positionOS.xyz);
			}

			// DepthOnly 片元阶段：由于 ColorMask 0，返回颜色不会写入颜色缓冲，仅保留深度写入效果
			float4 frag(void) : SV_Target
			{
				return _MainColor;
			}
			ENDHLSL
		}
		Pass 
		{
			Tags { "LightMode" = "UniversalForward" }
			//Blending:https://docs.unity3d.com/Manual/SL-Blend.html
			ZWrite Off
			//Blend SrcAlpha OneMinusSrcAlpha 
			Blend SrcAlpha One
			//Blend DstColor Zero

			HLSLPROGRAM  // Shader代码从这里开始	
			#pragma vertex vert //指定一个名为"vert"的函数为顶点Shader
			#pragma fragment frag //指定一个名为"frag"函数为片元Shader

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct Attributes  //CPU向顶点Shader提供的模型数据
			{
				float4 positionOS : POSITION; //模型空间顶点坐标
				half2 texcoord0 : TEXCOORD0; //第一套UV
				half3 normalOS : NORMAL; //顶点法线
			};

			struct Varyings  //自定义数据结构体，顶点着色器输出的数据，也是片元着色器输入数据
			{
				float4 positionHCS : SV_POSITION; 
				float2 uv : TEXCOORD0;
				float3 pos_world : TEXCOORD1;
				float3 normal_world : TEXCOORD2;
			};

			/*
			Shader内的变量声明，如果跟上面Properties模块内的参数同名，就可以产生链接
			*/
			// URP/SRP Batcher 材质常量缓冲：把与材质相关的标量/向量放这里
			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
				float4 _MainColor;
				float _Emiss;
			CBUFFER_END
			
			//Unity内置变量：https://docs.unity3d.com/Manual/SL-VertexProgramInputs.html

			//顶点Shader
			Varyings vert (Attributes v)
			{
				// 1) 声明输出结构体：把顶点阶段结果传给片元阶段
				Varyings o;

				// 2) 对象空间 -> 齐次裁剪空间(HClip)
				//    这是光栅化必须的位置信息，对应语义 SV_POSITION
				o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);

				// 3) 计算主纹理UV（虽然当前frag没采样_MainTex，但保留这步便于后续扩展）
				//    _MainTex_ST.xy = Tiling(缩放), _MainTex_ST.zw = Offset(偏移)
				//    公式：uv = uv0 * tiling + offset
				o.uv.xy = v.texcoord0 * _MainTex_ST.xy + _MainTex_ST.zw;

				// 4) 对象空间位置 -> 世界空间位置
				//    片元阶段用它与相机位置做差，得到观察方向(view dir)
				float4 pos_world = mul(GetObjectToWorldMatrix(), v.positionOS);
				o.pos_world = pos_world.xyz;

				// 5) 法线从对象空间转换到世界空间
				//    TransformObjectToWorldNormal 会处理非等比缩放下的法线变换
				o.normal_world = TransformObjectToWorldNormal(v.normalOS);

				// 6) 返回给光栅化阶段，插值后进入 frag(Varyings i)
				return o;
			}
			//片元Shader
			half4 frag (Varyings i) : SV_Target //SV_Target表示为：片元Shader输出的目标地（渲染目标）
			{
				// 1) 归一化世界空间法线，确保点乘结果稳定在可预期范围
				float3 normal_world = normalize(i.normal_world);

				// 2) 计算观察方向：从当前像素世界坐标指向相机位置
				float3 view_world = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);

				// 3) NdotV = 法线 与 视线 的夹角余弦，并限制到[0,1]
				//    越接近 1 表示越“正对相机”，越接近 0 表示越“掠角”(轮廓区域)
				float NdotV = saturate(dot(normal_world, view_world));

				// 4) Rim 核心：alpha 与 NdotV 反比
				//    NdotV 小(轮廓边缘) -> alpha 更大，边缘更亮/更明显
				//    max(..., 1e-4) 避免除零导致闪烁或NaN
				float alpha = saturate(_MainColor.a / max(NdotV, 1e-4));

				// 5) 输出颜色：RGB 用主色 * 强度，A 用上面计算的rim透明度
				//    配合 Pass 的 Blend SrcAlpha One，得到加法高光式边缘效果
				return float4(_MainColor.xyz * _Emiss, alpha);
			}
			ENDHLSL // Shader代码从这里结束
		}
	}
}
