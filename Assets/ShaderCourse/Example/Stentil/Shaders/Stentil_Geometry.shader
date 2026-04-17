// ============================================================================
// Stentil_Geometry.shader - Stencil 几何体 Shader（PBR 光照 + Stencil 测试）
// ============================================================================
//
// 【PPT对应章节】
// - GPU 渲染阶段 > 逐像素操作 > Stencil Test 详解
// - 光照模型 > PBR（Metallic/Smoothness 工作流）
// - 渲染状态控制 > Stencil Fail/Success/ZFail 三种操作
//
// 【Stencil Test 完整原理】
// GPU 在渲染每个像素时，按以下顺序执行测试：
//
//   ┌─────────────────────────────┐
//   │ 1. Depth Test（深度测试）    │  ZTest 模式：Always / LEqual / Greater ...
//   │    ↓ Fail → 丢弃像素         │  像素深度 vs 深度缓冲 → 丢弃超出范围的像素
//   ├─────────────────────────────┤
//   │ 2. Stencil Test（模板测试）  │  Comp 函数：Always / Equal / Greater ...
//   │    ↓ Fail → 执行 Fail 操作    │  BufferValue vs Ref → 执行对应操作
//   │ 3. 全部通过                  │
//   │    ↓ 执行 Pass 操作          │
//   └─────────────────────────────┘
//
// 【三种 Stencil 操作详解（Fail / Pass / ZFail）】
// - Fail  操作：Stencil Test 失败时执行（本 Shader 中为 Keep，不改变 Stencil）
// - Pass  操作：Stencil Test 通过时执行（本 Shader 中为 Keep，保留已写入的值）
// - ZFail 操作：Depth Test 失败但 Stencil Test 通过时执行
//
// 【本 Shader 的 Stencil 逻辑】
// Ref [_StencilID]     → 目标 ID（例如 1）
// Comp Equal           → Buffer == Ref 时通过（Buffer 中只有遮罩写入的 ID 位置能通过）
// Pass Keep            → 通过后 Stencil 值不变
// Fail Zero            → 不通过时把 Stencil 写成 0（丢弃这些像素，下一个遮罩无法覆盖）
// ZFail Zero           → 深度失败时也写成 0
//
// 【PBR 光照流程】
// Cook-Torrance BRDF = (D × F × G) / (4 × NdotV × NdotL) + 附加项
// D: GGX 法线分布函数
// F: Fresnel-Schlick 菲涅尔项
// G: Smith 几何遮蔽函数
// NdotL: 法线 × 光源方向（漫反射强度）
// ============================================================================

Shader "ShaderCourse/Stentil_Geometry"
{
    // ==================== 属性面板 ====================
    // 注意：
    //   _BaseMap / _BaseColor / _Metallic / _Smoothness / _EmissionColor
    //   这些标准 Lit 属性已在 LitInput.hlsl 中声明，无需重复定义。
    //   Unity 会在 HLSL 转换时自动生成对应的 CBUFFER 声明。
    //   在 Properties 中重新声明会导致 CBUFFER 变量重定义错误。
    Properties
    {
        // ===== Stencil 配置 =====
        // 必须与对应的 Mask 物体使用相同的 ID
        // 例如：Mask 物体使用 ID=1，则此材质也需要 ID=1
        _StencilID ("Stencil ID (0-255)", Range(0, 255)) = 1

        // ===== 自定义 PBR 参数（超出 LitInput 标准的扩展） =====
        [Toggle(_NORMALMAP)] _EnableNormalMap ("开启法线贴图", Float) = 0
        [NormalMap] _NormalMap ("法线贴图 (Normal Map)", 2D) = "bump" {}
        _NormalScale ("法线强度 (Normal Scale)", Range(0.0, 2.0)) = 1.0

        [Toggle(_EMISSION)] _EnableEmission ("开启自发光", Float) = 0
        _EmissionIntensity ("自发光强度", Range(0.0, 10.0)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"     = "Opaque"
            "Queue"          = "Geometry"
        }

        // ============================================================================
        // ==================== Pass 1：主渲染（Forward Lit + Stencil Test） ====================
        // ============================================================================
        Pass
        {
            // --------------------------------------------------------------------
            // 【Stencil 测试】核心逻辑
            //
            // Ref [_StencilID]     → 参考值（必须与 Mask 一致）
            // Comp Equal           → 比较函数：BufferValue == Ref 时通过
            //
            // 执行过程（像素级别）：
            // 假设屏幕某像素当前 BufferValue = 1（遮罩已写入）
            // 1. 读取 BufferValue = 1
            // 2. Ref = 1
            // 3. Comp Equal：1 == 1 → ✓ 通过
            // 4. 执行 Pass 操作：Keep（保留 Buffer 值）
            // 5. 渲染该像素（进入光照计算）
            //
            // 如果该像素没有被遮罩写入（BufferValue = 0）：
            // 1. 读取 BufferValue = 0
            // 2. Ref = 1
            // 3. Comp Equal：0 == 1 → ✗ 失败
            // 4. 执行 Fail 操作：Zero → 把 BufferValue 写成 0
            // 5. 丢弃像素，不渲染
            //
            // 效果：Geometry 只在对应 Mask 占据的像素上渲染！
            // --------------------------------------------------------------------
            Stencil
            {
                Ref [_StencilID]
                Comp Equal
                Pass Keep   // 通过：保留 Stencil 值（不重复写入）
                Fail Zero  // 失败：重置为 0（让后续遮罩有机会覆盖）
                ZFail Zero // 深度失败：也重置为 0
            }

            // --------------------------------------------------------------------
            // 【光照模式标签】
            // URP 会自动注入对应 Pass 代码，接收主光源阴影
            // UniversalForward：前向渲染主通道
            // --------------------------------------------------------------------
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // ==================== Shader 编译指令 ====================
            // 阴影相关：接收主光源阴影（MainLightShadows）
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            // 附加光源：URP 默认最多 8 个附加点光源/聚光灯
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            // Forward Plus：启用时使用更快的 GPU 光照路径
            #pragma multi_compile _ _FORWARD_PLUS
            // 软阴影：采样多次降低阴影锯齿
            #pragma multi_compile _ _SHADOWS_SOFT

            // ==================== 功能开关 ====================
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _EMISSION

            // ==================== URP 核心库引用 ====================
            // Core.hlsl：坐标变换、矩阵运算、插值器定义等基础功能
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Lighting.hlsl：光源数据结构、主光源计算、GI、BRDF 函数
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // LitInput.hlsl：包含 SurfaceInput.hlsl + Lit 材质全部标准 CBUFFER 声明
            // 注意：必须放在自定义 CBUFFER 之前！避免变量重定义
            // 已声明：_BaseMap_ST, _BaseMap, sampler_BaseMap, _BaseColor, _Metallic, _Smoothness, _EmissionColor
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LitInput.hlsl"

            // ============================================================
            // ==================== 1. 输入输出结构体 ====================
            // ============================================================

            // appdata：CPU → GPU（顶点着色器的输入）
            // 顶点着色器从 Mesh 数据中读取这些信息
            struct appdata
            {
                float4 vertex     : POSITION;   // 模型空间顶点坐标（物体局部坐标）
                float3 normal     : NORMAL;     // 模型空间法线（垂直于表面）
                float4 tangent    : TANGENT;    // 切线方向（用于法线贴图展开）
                float2 uv        : TEXCOORD0;  // 第一套 UV（Base Map 使用）
            };

            // v2f：GPU 内部传递（顶点着色器 → 片元着色器）
            // 经过光栅化插值后，每个像素接收插值后的数据
            struct v2f
            {
                float4 positionHCS  : SV_POSITION;   // 裁剪空间坐标（必须输出）
                float2 uv          : TEXCOORD0;      // 插值后的 Base Map UV
                float3 normalWS    : TEXCOORD1;     // 世界空间法线（已归一化）
                float3 positionWS   : TEXCOORD2;     // 世界空间顶点位置
                float3 tangentWS    : TEXCOORD3;     // 世界空间切线
                float3 bitangentWS  : TEXCOORD4;     // 世界空间副切线（TBN 矩阵）
                UNITY_VERTEX_INPUT_INSTANCE_ID // 多实例渲染支持
                UNITY_VERTEX_OUTPUT_STEREO    // XR 立体渲染支持
            };

            // ============================================================
            // ==================== 2. 材质参数缓冲 ====================
            // ============================================================
            // LitInput.hlsl 已声明以下标准变量（不可重复声明）：
            //   _BaseMap_ST, _BaseMap, sampler_BaseMap, _BaseColor, _Metallic,
            //   _Smoothness, _EmissionColor, _Cutoff, _SpecColor 等
            //
            // 仅在此处声明 Stentil 自定义参数和法线贴图相关变量：
            CBUFFER_START(UnityPerMaterial)
                float _StencilID;    // Stencil 参考值（自定义）
                float _NormalScale;  // 法线贴图强度（自定义）
                float _EmissionIntensity; // 自发光强度（自定义）
            CBUFFER_END

            // ============================================================
            // ==================== 3. 纹理声明 ====================
            // ============================================================
            // _BaseMap 和 sampler_BaseMap 已在 SurfaceInput.hlsl 中声明
            // 仅声明额外的法线贴图：
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            // ============================================================
            // ==================== 4. 顶点着色器 ====================
            // ============================================================
            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // --- 坐标变换 ---
                // TransformObjectToHClip：将模型空间坐标变换到裁剪空间
                // 等价于：UnityObjectToClipPos(v.vertex)
                // 最终传给 SV_POSITION，光栅化后每个像素对应一个片元
                o.positionHCS = TransformObjectToHClip(v.vertex.xyz);

                // --- UV 变换 ---
                // _BaseMap_ST：x=TilingX, y=TilingY, z=OffsetX, w=OffsetY
                // 公式：UV = OriginalUV * Tiling + Offset
                o.uv = v.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;

                // --- 法线从模型空间变换到世界空间 ---
                // TransformObjectToWorldNormal：等价于 UnityObjectToWorldNormal
                // 法线矩阵 = (M^(-1))^T，去除非均匀缩放的影响
                // 注意：如果模型有非均匀缩放（x/y/z 缩放值不同），法线会变形
                o.normalWS = TransformObjectToWorldNormal(v.normal);

                // --- 切线空间计算（用于法线贴图） ---
                // v.tangent.xyz = 切线方向（已包含切线 w 分量：±1，表示副切线方向）
                // TransformObjectToWorldDir：将模型空间方向变换到世界空间
                o.tangentWS = TransformObjectToWorldDir(v.tangent.xyz);

                // --- 构建 TBN 矩阵（切线空间基） ---
                // TBN = Tangent, Bitangent, Normal，三者构成切线空间正交基
                // 用于将法线贴图从切线空间转换到世界空间
                //
                // bitangent = cross(normal, tangent) × tangent.w
                // tangent.w 决定副切线翻转方向（解决 UV 镜像问题）
                o.bitangentWS = cross(o.normalWS, o.tangentWS) * v.tangent.w;

                // --- 世界空间位置（用于光照计算） ---
                // TransformObjectToWorld：将模型空间位置变换到世界空间
                // 用于计算视向量（相机位置 - 表面位置）
                o.positionWS = TransformObjectToWorld(v.vertex.xyz);

                return o;
            }

            // ============================================================
            // ==================== 5. 片元着色器 ====================
            // ============================================================
            float4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // --------------------------------------------------------
                // 步骤 1：采样基础纹理和颜色
                // --------------------------------------------------------
                // SAMPLE_TEXTURE2D：带偏差的纹理采样（可控制采样细节层级）
                // _BaseMap_ST 已包含 Tiling 和 Offset
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;

                // --------------------------------------------------------
                // 步骤 2：计算法线（支持法线贴图）
                // --------------------------------------------------------
                // 如果没有开启法线贴图，直接使用顶点插值法线
                #if defined(_NORMALMAP)
                    // SampleNormal：采样法线贴图（BC5 格式，RG = XY）
                    // UnpackNormalScale：将 [0,1] 范围解压缩为法线向量，并乘以强度
                    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);

                    // 构建 TBN 矩阵，将切线空间法线变换到世界空间
                    // 使用 dot 为了编译器优化（避免显式矩阵乘法开销）
                    half3x3 TBN = half3x3(
                        i.tangentWS,
                        i.bitangentWS,
                        i.normalWS
                    );
                    half3 normalWS = normalize(mul(normalTS, TBN));
                #else
                    half3 normalWS = normalize(i.normalWS);
                #endif

                // --------------------------------------------------------
                // 步骤 3：准备光照参数
                // --------------------------------------------------------
                // GetMainLight()：从 Lighting.hlsl 获取主光源数据
                // 包含方向、颜色、距离衰减（直射光无衰减，点光源有衰减）
                Light mainLight = GetMainLight();

                // 主光源方向（从表面指向光源）
                half3 lightDirWS = mainLight.direction;
                // 主光源颜色（已包含强度衰减）
                half3 lightColor = mainLight.color;

                // 世界空间视向量（从表面指向相机）
                half3 viewDirWS = normalize(GetWorldSpaceNormalizeViewDir(i.positionWS));

                // --------------------------------------------------------
                // 步骤 4：计算 PBR 各项参数
                // --------------------------------------------------------

                // --- 金属度工作流关键参数 ---
                // F0（零度入射菲涅尔值）：表面在法线入射时的反射率
                // 金属：F0 = BaseColor（金属会吞噬反射，只剩 BaseColor）
                // 非金属：F0 = 0.04（固定值，常见玻璃/水面/皮肤等）
                half oneMinusReflectivity = OneMinusReflectivityMetallic(_Metallic);
                half3 diffColor = albedo * (1.0 - oneMinusReflectivity); // 漫反射颜色（去除金属反射部分）
                half3 specColor = lerp(half3(0.04, 0.04, 0.04), albedo, _Metallic); // 镜面反射颜色（F0）

                // --- 光照向量 ---
                half NdotL = saturate(dot(normalWS, lightDirWS)); // 法线 × 光源方向（漫反射强度）
                half NdotV = saturate(dot(normalWS, viewDirWS));  // 法线 × 视方向（用于 BRDF 积分）
                half NdotH = saturate(dot(normalWS, normalize(lightDirWS + viewDirWS))); // 法线 × 半向量（Blinn-Phong / GGX）
                half LdotH = saturate(dot(lightDirWS, viewDirWS)); // 光源 × 视方向（菲涅尔项输入）
                half VdotH = LdotH; // 等价（对称性）

                // --- 粗糙度（由光滑度推导） ---
                // 粗糙度 = 1 - 光滑度
                // URP 中 roughness = Smoothness^2（更符合人眼感知）
                half roughness = max(half(0.002), (1.0 - _Smoothness));

                // --------------------------------------------------------
                // 步骤 5：计算 Direct Lighting（直接光照 = 主光源 + 附加光源）
                // --------------------------------------------------------

                // --- Cook-Torrance BRDF ---
                // BRDF 描述：给定入射光方向和视角，物体表面如何散射反射光
                // 完整公式：f(l,v) = (D×F×G) / (4×NdotL×NdotV) + kD×diffuse/π
                //
                // D（法线分布函数，NDF）：GGX，描述微表面法线集中程度
                //   高光滑度 → D 峰值尖锐 → 高光集中（镜面）
                //   低光滑度 → D 峰值平缓 → 高光分散（粗糙）
                //
                // F（菲涅尔项）：Schlick 近似，F0 + (1-F0) × (1-VdotH)^5
                //   掠射角（几乎平行表面）时反射率趋近 1（像镜子一样）
                //
                // G（几何遮蔽函数）：Smith 近似，描述微表面自遮挡程度
                //   粗糙表面微表面多，互相遮挡导致某些方向看不见

                // D 项：GGX 法线分布
                // roughness^4 = (roughness²)²，优化版
                half a2 = roughness * roughness;
                half a = a2 * a2;
                half NdotH2 = NdotH * NdotH;
                half denom = (NdotH2 * (a - 1.0) + 1.0);
                half D = a / (UNITY_PI * denom * denom + 1e-5); // +1e-5 防止除零

                // F 项：Schlick 菲涅尔近似
                // 掠射角时反射更强，中间入射时反射弱
                half3 F = specColor + (1.0 - specColor) * pow(1.0 - VdotH, 5);

                // G 项：Smith 几何遮蔽（分母优化版本）
                half k = (roughness + 1.0) * (roughness + 1.0) / 8.0; // 直接光照的 k
                half G_V = NdotV / (NdotV * (1.0 - k) + k); // 视图方向遮蔽
                half G_L = NdotL / (NdotL * (1.0 - k) + k); // 光源方向遮蔽
                half G = G_V * G_L;

                // 镜面反射项：(D × F × G) / (4 × NdotV × NdotL)
                half3 specular = (D * F * G) / (4.0 * NdotV * NdotL + 1e-5);

                // --- 漫反射项 ---
                // Lambertian：最简单的漫反射模型，均匀散射
                // kD = 1 - F（能量守恒：漫反射 + 镜面反射 = 1）
                // /UNITY_PI：漫反射归一化因子（使所有方向积分等于 1）
                half3 kD = (half3(1, 1, 1) - F) * (1.0 - _Metallic); // 金属没有漫反射
                half diffuse = NdotL / UNITY_PI;

                // --- 直接光照 = 漫反射 + 镜面反射 ---
                half3 directLighting = (kD * diffColor / UNITY_PI + specular) * lightColor * diffuse;

                // --- 阴影（URP 主光源阴影投射） ---
                // half4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                // half shadow = MainLightRealtimeShadow(shadowCoord);
                // directLighting *= shadow;

                // --- 附加光源（点光源/聚光灯） ---
                // URP 支持最多 8 个附加光源，每个单独计算 BRDF
                #if defined(_ADDITIONAL_LIGHTS)
                    uint pixelLightCount = GetAdditionalLightsCount();
                    half attenuation = 1.0; // 初始化衰减（附加光源默认无衰减）
                    for (uint pLightIndex = 0u; pLightIndex < pixelLightCount; ++pLightIndex)
                    {
                        // 逐光源计算
                        Light additionalLight = GetAdditionalLight(pLightIndex, i.positionWS, attenuation);
                        half3 additionalColor = additionalLight.color;
                        half3 aLightDirWS = normalize(additionalLight.direction);
                        half3 aLightAtten = additionalLight.distanceAttenuation * additionalLight.shadowAttenuation;

                        half aNdotL = saturate(dot(normalWS, aLightDirWS));
                        half3 aDiff = albedo * (1.0 - _Metallic) / UNITY_PI;
                        half3 aSpec = (D * F * G) / (4.0 * NdotV * aNdotL + 1e-5);
                        directLighting += (kD * aDiff + aSpec) * additionalColor * aNdotL * aLightAtten;
                    }
                #endif

                // --- 环境光（球谐函数，Ambient Light Probe） ---
                // 由 Unity 在场景烘焙时计算，存储在 SH 系数中
                half3 bakedGI = SampleSHPixel(normalWS, float4(0, 0, 0, 1)).rgb;
                half3 indirectDiffuse = bakedGI * diffColor; // 环境光漫反射
                half3 indirectSpecular = GlossyEnvironmentReflection(reflect(-viewDirWS, normalWS), roughness, 1.0).rgb * specColor; // 反射探针
                half3 indirectLighting = indirectDiffuse + indirectSpecular;

                // --- 自发光 ---
                #if defined(_EMISSION)
                    // 自发光直接叠加到最终颜色，支持 HDR 溢出（用于 Bloom 效果）
                    half3 emission = _EmissionColor.rgb * _EmissionIntensity;
                #else
                    half3 emission = half3(0, 0, 0);
                #endif

                // --------------------------------------------------------
                // 步骤 6：合成最终颜色
                // --------------------------------------------------------
                half3 finalColor = directLighting + indirectLighting + emission;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // ============================================================================
        // ==================== Pass 2：阴影投射（ShadowCaster） ====================
        // ============================================================================
        // 功能：将物体形状投射到地面/其他物体上
        // URP 自动处理：接收阴影的物体需要对应的 ShadowCaster Pass
        // 注意：Stencil 不影响阴影投射，所以这里不需要 Stencil 设置
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
