// ============================================================================
// Blinn-Phong.shader - Blinn-Phong镜面反射光照模型
// ============================================================================
// 
// 【PPT对应章节】
// - GPU渲染阶段 > 片元Shader > 光照计算
// - Phong光照模型：直接光漫反射 + 直接光镜面反射
//
// 【核心知识点】
// 1. Lambert漫反射：N·L
// 2. Blinn-Phong镜面反射：(N·H)^shininess
// 3. 半向量H = normalize(L + V)
// 4. 光滑度影响高光范围
//
// 【完整Phong模型公式】
// I = I_ambient + I_diffuse + I_specular
// I_diffuse = k_d * (N·L)
// I_specular = k_s * (N·H)^n
// ============================================================================

Shader "Custom/URP_BlinnPhong_Full"
{
    // ==================== 属性面板 ====================
    // 对应PPT中的"灯光、材质参数"
    Properties
    {
        // 基础纹理：物体的表面纹理
        // [MainTexture]：告诉Unity这是主纹理，用于材质预览
        [MainTexture] _BaseMap("基础纹理 (Base Map)", 2D) = "white" {}
        
        // 基础颜色：整体色调调节
        // [MainColor]：告诉Unity这是主颜色
        [MainColor]   _BaseColor("基础颜色 (Base Color)", Color) = (1, 1, 1, 1)
        
        // 光滑度：控制高光的锐利程度
        // 0 = 粗糙表面，高光分散
        // 1 = 光滑表面，高光集中
        _Smoothness("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.5
        
        // 高光颜色：镜面反射的颜色
        // 金属的高光通常是白色，塑料可以是有色的
        _SpecularColor("高光颜色 (Specular Color)", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        // ==================== 渲染标签 ====================
        // 告诉Unity如何渲染这个物体
        Tags 
        { 
            "RenderPipeline" = "UniversalPipeline"  // 使用URP渲染管线
            "RenderType" = "Opaque"                 // 不透明物体
            "Queue" = "Geometry"                    // 几何队列（不透明物体）
        }

        Pass
        {
            // 指定光照模式为前向渲染
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            // 定义顶点和片元着色器入口
            #pragma vertex vert
            #pragma fragment frag

            // 引用URP核心库（包含常用宏和坐标变换）
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // 引用URP光照库（包含Light结构体和GetMainLight函数）
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ==================== 1. 结构体定义 ====================
            
            // appdata：顶点输入数据
            // 对应PPT："模型信息：顶点坐标、法线、UV..."
            struct appdata
            {
                float4 vertex : POSITION;  // 模型空间顶点坐标
                float2 uv     : TEXCOORD0; // 原始UV坐标（纹理坐标）
                float3 normal : NORMAL;    // 模型空间法线
            };

            // v2f：顶点到片元的数据传递
            // 光栅化阶段会对这些数据进行插值
            struct v2f
            {
                float4 posCS      : SV_POSITION;   // 裁剪空间坐标（必须）
                float2 uv         : TEXCOORD0;     // 变换后的UV
                float3 normalWS   : TEXCOORD1;     // 世界空间法线
                float3 positionWS : TEXCOORD2;     // 世界空间顶点位置
            };

            // ==================== 2. 常量缓冲区 ====================
            // SRP Batcher兼容优化
            // 所有材质属性放在一个CBUFFER中，可以批量渲染
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _SpecularColor;
                float _Smoothness;
                float4 _BaseMap_ST; // Tiling和Offset (x,y=缩放, z,w=偏移)
            CBUFFER_END

            // ==================== 3. 纹理和采样器声明 ====================
            // URP使用TEXTURE2D宏声明纹理
            // SAMPLER宏声明采样器（控制过滤模式）
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            // ==================== 4. 顶点着色器 ====================
            // 对应PPT："顶点Shader核心任务：坐标空间变换"
            // 
            // 【变换流程】
            // 模型空间 → 世界空间 → 观察空间 → 裁剪空间
            // 
            // 【为什么需要世界空间】
            // 光照计算需要世界空间的法线和位置
            // 因为光源方向是世界空间定义的
            // ================================================
            v2f vert(appdata v)
            {
                v2f o;

                // --- 位置变换 ---
                // GetVertexPositionInputs：一次性计算所有空间坐标
                VertexPositionInputs posInput = GetVertexPositionInputs(v.vertex.xyz);
                o.posCS = posInput.positionCS;      // 裁剪空间（给GPU光栅化用）
                o.positionWS = posInput.positionWS; // 世界空间（给光照计算用）

                // --- 法线变换 ---
                // 法线需要特殊处理（逆转置矩阵）
                VertexNormalInputs normInput = GetVertexNormalInputs(v.normal);
                o.normalWS = normInput.normalWS;

                // --- UV变换 ---
                // _BaseMap_ST.xy = Tiling（缩放）
                // _BaseMap_ST.zw = Offset（偏移）
                // 公式：uv' = uv * tiling + offset
                o.uv = v.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;

                return o;
            }

            // ==================== 5. 片元着色器 ====================
            // 对应PPT："片元Shader重要任务是上色"
            // 
            // 【Blinn-Phong模型】
            // 最终颜色 = 漫反射 + 镜面反射
            // 
            // 【漫反射】Lambert模型
            // diffuse = albedo * lightColor * (N·L)
            // 
            // 【镜面反射】Blinn-Phong模型
            // specular = specularColor * lightColor * (N·H)^shininess
            // ================================================
            half4 frag(v2f i) : SV_Target
            {
                // ==================== A. 基础准备 ====================
                
                // 归一化法线
                // 【原因】插值后法线长度可能不是1
                float3 N = normalize(i.normalWS);
                
                // 获取视线方向（从片元指向摄像机）
                // 用于镜面反射计算
                float3 V = GetWorldSpaceNormalizeViewDir(i.positionWS);
                
                // 获取主光源（平行光）
                Light mainLight = GetMainLight();
                float3 L = mainLight.direction;    // 光源方向
                float3 lightColor = mainLight.color; // 光颜色

                // ==================== B. 纹理采样与颜色混合 ====================
                // SAMPLE_TEXTURE2D：URP的纹理采样宏
                // 
                // 【纹理过滤机制】（对应PPT）
                // - Point：最近点采样，有锯齿
                // - Bilinear：双线性过滤，平滑
                // - Trilinear：三线性过滤，跨Mipmap层级
                half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                
                // 基础颜色 = 纹理颜色 × 材质颜色
                half3 albedo = texColor.rgb * _BaseColor.rgb;

                // ==================== C. 漫反射计算 (Lambert) ====================
                // 【Lambert定律】
                // 光照强度 = max(0, N·L)
                // 
                // dot(N, L)：点积表示法线与光方向的夹角余弦
                // - 0° (正对光源) → cos(0°) = 1 → 最亮
                // - 90° (边缘) → cos(90°) = 0 → 最暗
                // 
                // saturate()：限制到0~1范围
                float ndotl = saturate(dot(N, L));
                
                // 漫反射颜色 = 基础颜色 × 光颜色 × 光照强度
                half3 diffuse = albedo * lightColor * ndotl;

                // ==================== D. 镜面反射计算 (Blinn-Phong) ====================
                // 【半向量H】
                // H = normalize(L + V)
                // 
                // 【为什么用半向量】
                // 原始Phong模型需要计算反射向量R = reflect(-L, N)
                // Blinn-Phong用半向量代替，计算更快
                // 
                // 【镜面反射公式】
                // specular = (N·H)^shininess
                // 
                // shininess越大，高光越集中（光滑表面）
                // shininess越小，高光越分散（粗糙表面）
                // ================================================
                
                // 计算半向量
                float3 H = normalize(L + V);
                
                // N·H点积
                float ndoth = saturate(dot(N, H));
                
                // 计算高光强度
                // _Smoothness: 0~1 映射到指数 1~129
                // 光滑度越高，指数越大，高光越集中
                float specPower = pow(ndoth, _Smoothness * 128.0 + 1.0);
                
                // 镜面反射颜色
                half3 specular = _SpecularColor.rgb * lightColor * specPower;

                // ==================== E. 组合最终颜色 ====================
                // 考虑光照衰减（距离衰减和阴影）
                // 
                // distanceAttenuation：距离越远越暗
                // shadowAttenuation：阴影区域变暗
                float attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                
                // 最终颜色 = (漫反射 + 镜面反射) × 衰减
                half3 finalRGB = (diffuse + specular) * attenuation;

                // 返回最终颜色
                // Alpha = 纹理Alpha × 材质Alpha
                return half4(finalRGB, texColor.a * _BaseColor.a);
              
            }
            ENDHLSL
        }
    }
    
    // 如果显卡跑不动，回退到默认Shader
    Fallback "Universal Render Pipeline/Simple Lit"
}