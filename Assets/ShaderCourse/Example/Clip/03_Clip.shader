Shader "CS02/Clip" //Shader的真正名字  可以是路径式的格式
{
	/*材质球参数及UI面板
	https://docs.unity3d.com/cn/current/Manual/SL-Properties.html
	https://docs.unity3d.com/cn/current/ScriptReference/MaterialPropertyDrawer.html
	https://zhuanlan.zhihu.com/p/93194054
	*/
	Properties 
	{
		_MainTex ("Texture", 2D) = "" {}
		_MainColor("Main Color",Color) = (1,1,1,1)
		_NoiseMap("NoiseMap", 2D) = "" {}
		_Cutout("Cutout", Range(0.0,1.1)) = 0.0
		_Speed("Speed", Vector) = (.34, .85, .92, 1)
	}
	/*
	这是为了让你可以在一个Shader文件中写多种版本的Shader，但只有一个会被使用。
	提供多个版本的SubShader，Unity可以根据对应平台选择最合适的Shader
	或者配合LOD机制一起使用。
	一般写一个即可
	*/
	SubShader
	{
		/*
		标签属性，有两种：一种是SubShader层级，一种在Pass层级
		https://docs.unity3d.com/cn/current/Manual/SL-SubShaderTags.html
		https://docs.unity3d.com/cn/current/Manual/SL-PassTags.html
		*/
		Tags { "RenderType"="Opaque" "DisableBatching"="True" "RenderPipeline"="UniversalPipeline"} 
		/*
		Pass里面的内容Shader代码真正起作用的地方，
		一个Pass对应一个真正意义上运行在GPU上的完整着色器(Vertex-Fragment Shader)
		一个SubShader里面可以包含多个Pass，每个Pass会被按顺序执行
		*/
		Pass 
		{
			Tags { "LightMode" = "UniversalForward" }
			HLSLPROGRAM  // Shader代码从这里开始
			#pragma vertex vert //指定一个名为"vert"的函数为顶点Shader
			#pragma fragment frag //指定一个名为"frag"函数为片元Shader
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			//https://docs.unity3d.com/Manual/SL-VertexProgramInputs.html
			struct Attributes  //CPU向顶点Shader提供的模型数据
			{
				//冒号后面的是特定语义词，告诉CPU需要哪些类似的数据
				float4 positionOS : POSITION; //模型空间顶点坐标
				half2 texcoord0 : TEXCOORD0; //第一套UV
			//	half2 texcoord1 : TEXCOORD1; //第二套UV
			//	half2 texcoord2 : TEXCOORD2; //第二套UV
			//	half2 texcoord4 : TEXCOORD3;  //模型最多只能有4套UV

				half4 color : COLOR; //顶点颜色
				half3 normal : NORMAL; //顶点法线
				half4 tangent : TANGENT; //顶点切线(模型导入Unity后自动计算得到)
			};

			struct Varyings  //自定义数据结构体，顶点着色器输出的数据，也是片元着色器输入数据
			{
				float4 positionHCS : SV_POSITION; //输出裁剪空间下的顶点坐标数据，给光栅化使用，必须要写的数据
				float4 uv : TEXCOORD0; //自定义数据体
				//注意跟上方的TEXCOORD的意义是不一样的，上方代表的是UV，这里可以是任意数据。
				//插值器：输出后会被光栅化进行插值，而后作为输入数据，进入片元Shader
				//最多可以写16个：TEXCOORD0 ~ TEXCOORD15。
				//float3 pos_local : TEXCOORD1;
				//float3 pos_pivot : TEXCOORD2;
			};

			/*
			Shader内的变量声明，如果跟上面Properties模块内的参数同名，就可以产生链接
			*/
			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			TEXTURE2D(_NoiseMap);
			SAMPLER(sampler_NoiseMap);

			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
				float _Cutout;
				float4 _Speed;
				float4 _NoiseMap_ST;
				float4 _MainColor;
			CBUFFER_END
			
			//顶点Shader
			Varyings vert (Attributes v)
			{
				// 1) 声明输出结构体，后面会把顶点阶段算好的数据写进去，传给片元阶段
				Varyings o;

				// 2) 把模型空间(Object Space)顶点坐标转换到齐次裁剪空间(HClip)
				//    这一步是光栅化必需数据：SV_POSITION。
				//    等价于 MVP 变换：clipPos = P * V * M * positionOS
				o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);

				// 3) 计算主纹理UV：
				//    _MainTex_ST.xy = Tiling(缩放)
				//    _MainTex_ST.zw = Offset(偏移)
				//    最终公式：uvMain = uv0 * tiling + offset
				o.uv.xy = v.texcoord0 * _MainTex_ST.xy + _MainTex_ST.zw;

				// 4) 计算噪声纹理UV，规则同上，但使用 _NoiseMap_ST
				//    片元阶段会用它采样噪声贴图，参与 clip 裁剪阈值计算
				o.uv.zw = v.texcoord0 * _NoiseMap_ST.xy + _NoiseMap_ST.zw;

				// 5) 旧管线写法参考（URP里推荐手动写公式或使用 TRANSFORM_TEX 宏）
				//o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				// 6) 额外把模型空间位置传下去（当前片元里未使用）
				//    常见用途：做局部空间渐变、局部空间裁剪、基于高度/方向的特效
				//o.pos_local = v.positionOS.xyz;

				// 7) 返回给光栅化阶段，随后插值后进入 frag(Varyings i)
				return o;
			}
			//片元Shader
			half4 frag (Varyings i) : SV_Target //SV_Target表示为：片元Shader输出的目标地（渲染目标）
			{
				half gradient = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy + _Time.y * 0.1f * _Speed.xy).r * (1.0 - i.uv.y);
				half noise = 1.0 - SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, i.uv.zw + _Time.y * 0.1f * _Speed.zw).r;
				clip(gradient - noise -  _Cutout);
				return _MainColor;

			}
			ENDHLSL // Shader代码从这里结束
		}
	}
}
