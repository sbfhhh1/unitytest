// ==========================================================
// 修复版：合并教学Shader（法线贴图 + 视差映射）
// 功能：展示如何实现法线贴图和视差映射效果
// 适用于：Unity Universal Render Pipeline (URP)
// ==========================================================

Shader "Tutorial/Lit/NormalMap_With_Parallax_Fixed"
{
    // ========================================
    // 材质属性面板：用户可调整的参数
    // ========================================
    Properties
    {
        // ==================== 基础属性 ====================
        _BaseColor("基础颜色", Color) = (1,1,1,1)           // 物体基础色调
        _MainTex ("反照率贴图", 2D) = "white" {}             // 主要颜色纹理
        
        // ==================== 法线贴图 ====================
        [Normal] _NormalMap("法线贴图", 2D) = "bump" {}      // 表面细节法线信息
        _NormalIntensity("法线强度", Range(0.0, 5.0)) = 1.0  // 法线效果的强度控制
        
        // ==================== 视差映射 ====================
        _HeightMap("高度贴图（灰度）", 2D) = "black" {}      // 表面高度信息
        [Toggle] _UseParallax("启用视差映射", Float) = 1.0   // 开关：是否使用视差效果
        _ParallaxStrength("视差强度", Range(0.0, 0.1)) = 0.03// 视差效果的深度程度
        _ParallaxSteps("视差采样步数（质量）", Range(1, 20)) = 8 // 视差计算的质量与性能平衡
        
        // ==================== Blinn-Phong 高光 ====================
        _SpecularColor("高光颜色", Color) = (1,1,1,1)        // 高光的颜色
        _SpecularIntensity("高光强度", Range(0.0, 10.0)) = 2.0 // 高光的亮度系数
        _Gloss("光泽度（平滑度）", Range(1.0, 256.0)) = 50.0 // 控制高光的大小和锐度
    }

    // ========================================
    // 子着色器：定义渲染管线和渲染状态
    // ========================================
    SubShader
    {
        // 渲染标签：定义物体的渲染类型和管线兼容性
        Tags { 
            "RenderType"="Opaque"                    // 不透明物体渲染队列
            "RenderPipeline"="UniversalPipeline"     // 适用于URP渲染管线
        }
        LOD 150  // 细节层次：决定何时切换到更简单的着色器

        // ========================================
        // 渲染通道：定义顶点和片段处理逻辑
        // ========================================
        Pass
        {
            // 使用HLSL编程语言
            HLSLPROGRAM
            // 编译指令：指定顶点和片段着色器函数
            #pragma vertex vert
            #pragma fragment frag

            // 包含URP核心库和光照库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ========================================
            // 输入结构：顶点着色器的输入数据
            // ========================================
            struct Attributes
            {
                float4 positionOS : POSITION;    // 物体空间顶点位置
                float2 uv         : TEXCOORD0;   // 纹理坐标
                float3 normalOS   : NORMAL;      // 物体空间法线
                float4 tangentOS  : TANGENT;     // 物体空间切线（w分量用于镜像）
            };

            // ========================================
            // 输出结构：传递给片段着色器的数据
            // ========================================
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // 裁剪空间位置（屏幕坐标）
                float2 uv         : TEXCOORD0;   // 纹理坐标
                float3 lightDirTS : TEXCOORD1;   // 切线空间光照方向
                float3 viewDirTS  : TEXCOORD2;   // 切线空间视角方向
            };

            // ========================================
            // 常量缓冲区：从材质属性传递的数据
            // ========================================
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;           // 基础颜色
                float4 _MainTex_ST;          // 主纹理的缩放和偏移
                float _NormalIntensity;      // 法线强度
                float _ParallaxStrength;     // 视差强度
                int   _ParallaxSteps;        // 视差采样步数
                float _UseParallax;          // 视差映射开关
                float4 _SpecularColor;       // 高光颜色
                float _SpecularIntensity;    // 高光强度
                float _Gloss;                // 光泽度
            CBUFFER_END

            // 纹理和采样器声明
            TEXTURE2D(_MainTex);     SAMPLER(sampler_MainTex);     // 反照率贴图
            TEXTURE2D(_NormalMap);   SAMPLER(sampler_NormalMap);   // 法线贴图
            TEXTURE2D(_HeightMap);   SAMPLER(sampler_HeightMap);   // 高度贴图

            // ========================================
            // 顶点着色器：处理顶点变换和数据准备
            // ========================================
            Varyings vert(Attributes v)
            {
                Varyings o;
                // 位置变换：物体空间 → 裁剪空间
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                
                // 纹理坐标变换：应用Tiling和Offset
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // 构建TBN矩阵：用于世界空间到切线空间的转换
                float3 normalWS    = TransformObjectToWorldNormal(v.normalOS);     // 世界空间法线
                float3 tangentWS   = TransformObjectToWorldDir(v.tangentOS.xyz);   // 世界空间切线
                float3 bitangentWS = cross(normalWS, tangentWS) * v.tangentOS.w;   // 世界空间副切线
                float3x3 tbnMatrix = float3x3(tangentWS, bitangentWS, normalWS);  // TBN变换矩阵

                // 光照方向：世界空间 → 切线空间
                float3 lightDirWS = GetMainLight().direction;  // 获取主光源方向
                o.lightDirTS = mul(tbnMatrix, lightDirWS);

                // 视角方向：世界空间 → 切线空间
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(TransformObjectToWorld(v.positionOS.xyz));
                o.viewDirTS = mul(tbnMatrix, viewDirWS);

                return o;
            }

            // ========================================
            // 视差映射函数：模拟深度效果
            // ========================================
            float2 ParallaxMapping(float2 uv, float3 viewDirTS)
            {
                float2 uvOffset = 0;               // UV偏移量
                float stepSize = 1.0 / _ParallaxSteps;  // 每步的采样间隔
                
                // 分层采样：逐步计算高度偏移
                for (int i = 0; i < _ParallaxSteps; i++)
                {
                    // 采样当前UV的高度值
                    float height = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv + uvOffset).r;
                    // 根据高度和视角方向计算UV偏移
                    uvOffset -= viewDirTS.xy * stepSize * _ParallaxStrength * height;
                }
                return uv + uvOffset;  // 返回偏移后的UV坐标
            }

            // ========================================
            // 片段着色器：计算最终像素颜色
            // ========================================
            half4 frag(Varyings i) : SV_Target
            {
                float2 finalUV = i.uv;  // 初始化最终UV坐标

                // ==================== 视差映射处理 ====================
                if (_UseParallax > 0.5)  // 如果启用视差映射
                {
                    float3 viewDirTS_norm = normalize(i.viewDirTS);  // 归一化视角方向
                    finalUV = ParallaxMapping(i.uv, viewDirTS_norm); // 计算偏移后的UV
                }

                // ==================== 基础颜色采样 ====================
                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, finalUV).rgb * _BaseColor.rgb;
                
                // ==================== 法线贴图处理 ====================
                float3 normalTS = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, finalUV), 
                    _NormalIntensity  // 应用法线强度
                );

                // ==================== 光照计算准备 ====================
                float3 lightDirTS = normalize(i.lightDirTS);  // 归一化光照方向
                float3 viewDirTS  = normalize(i.viewDirTS);   // 归一化视角方向
                float3 halfDirTS  = normalize(lightDirTS + viewDirTS);  // Blinn-Phong半角向量

                // ==================== 漫反射光照 ====================
                float NdotL = saturate(dot(normalTS, lightDirTS));  // 法线与光照的点积
                half3 diffuse = _MainLightColor.rgb * NdotL * albedo;  // 兰伯特漫反射

                // ==================== 镜面反射光照（Blinn-Phong） ====================
                float NdotH = saturate(dot(normalTS, halfDirTS));  // 法线与半角的点积
                float spec = pow(NdotH, _Gloss);  // 高光计算（指数控制锐度）
                half3 specular = _MainLightColor.rgb * _SpecularColor.rgb * spec * _SpecularIntensity;

                // ==================== 环境光 ====================
                // 将切线空间法线转换回世界空间用于环境光采样
                float3 normalWS = TransformTangentToWorld(normalTS, float3x3(i.lightDirTS, cross(normalTS, i.lightDirTS), normalTS));
                half3 ambient = SampleSH(normalWS) * albedo;  // 采样球谐函数获取环境光

                // ==================== 最终颜色合成 ====================
                half3 finalColor = ambient + diffuse + specular;  // 加权混合所有光照分量

                return half4(finalColor, 1.0);  // 返回最终颜色（Alpha为1，不透明）
            }
            ENDHLSL
        }
    }
}
