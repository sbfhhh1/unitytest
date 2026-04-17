// ============================================================================
// Stentil_Mask.shader - Stencil 遮罩 Shader（完全不可见，只写 Stencil）
// ============================================================================
//
// 【PPT对应章节】
// - GPU 渲染阶段 > 逐像素操作 > Stencil Buffer
// - 渲染状态控制 > Blend/ZWrite/ZTest/Stencil 测试
//
// 【Stencil Buffer 核心原理】
// Stencil Buffer 是屏幕每个像素挂载的一个 0~255 整数值（8bit）。
// 默认值为 0，所有物体渲染时都会从 0 开始。
//
// 【遮罩原理】
// 本 Shader 的物体本身完全不参与光照计算，也不可见（Blend Zero One）。
// 它只做一件事：在每个像素上写入一个指定的 Stencil 值。
// 后续物体通过 Stencil Test 决定是否在该像素上渲染。
//
// 【遮罩三要素（缺一不可）】
// 1. Blend Zero One      → 输出颜色为 0，物体完全不可见
// 2. ZWrite Off           → 不写入深度缓冲，不遮挡其他物体
// 3. Stencil { Pass Replace } → 写入 Ref 值到 Stencil Buffer
//
// 【应用场景】
// - 不可能几何体（Antichamber）：物体 A 占据空间，但物体 B 只在 A 占据的
//   空间内渲染，造成"同一空间被多物体共享"的视错觉。
// - 魔法特效：传送门内部渲染另一个场景（Portals）。
// - 描边：第二个 Pass 用 Front Culling + Negative Scaled 渲染背面描边。
// - 体积光：只在特定区域渲染体积效果。
// ============================================================================

Shader "ShaderCourse/Stentil_Mask"
{
    // ==================== 属性面板 ====================
    Properties
    {
        // Stencil 参考值（0-255）
        // 每个遮罩使用不同的 ID 号，ID 相同的 Geometry 才会渲染
        // 例如：ID=1 的 Mask 只对 ID=1 的 Geometry 生效
        _StencilID ("Stencil ID (0-255)", Range(0, 255)) = 1
    }

    SubShader
    {
        // ==================== 渲染标签 ====================
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"     = "Opaque"
            // Geometry-1：在所有 Geometry 物体之前渲染（确保遮罩先写入 Stencil）
            // 注意：如果遮罩物体太靠后，Geometry 可能在遮罩之前渲染，导致失效
            "Queue"          = "Geometry-1"
        }

        // ============================================================================
        // ==================== Pass：遮罩渲染（只写 Stencil） ====================
        // ============================================================================
        Pass
        {
            // --------------------------------------------------------------------
            // 【混合模式】Blend SrcFactor DstFactor
            // 公式：FinalColor = SrcFactor * SrcColor [Op] DstFactor * DstColor
            //
            // Blend Zero One 的含义：
            // - SrcFactor = Zero  → 输出颜色 × 0 = 黑色（透明）
            // - DstFactor = One  → 保留目标缓冲区原有颜色
            // 最终公式：Final = 0 + 1 × Dst = Dst（即：完全不变！）
            //
            // 为什么这样设置？
            // 我们不需要往 FrameBuffer 写任何颜色，只要 Stencil 通过就行。
            // 这行代码让输出的颜色直接透传到屏幕，不影响画面。
            // --------------------------------------------------------------------
            Blend Zero One

            // --------------------------------------------------------------------
            // 【深度写入】ZWrite Off
            //
            // ZWrite = On  时：物体在深度缓冲写入自己的深度值
            // ZWrite = Off 时：物体不写入深度，但仍然参与深度测试
            //
            // 为什么要关闭深度写入？
            // 如果遮罩写入深度，Geometry 在深度测试时会认为被遮罩遮挡，
            // 导致即使 Stencil 匹配也因为深度被挡住而不渲染（ZTest Fail）。
            // 关闭后，Geometry 可以正常渲染在遮罩物体之上（同一像素位置）。
            // --------------------------------------------------------------------
            ZWrite Off

            // --------------------------------------------------------------------
            // 【深度测试】ZTest Always
            //
            // Always  = 始终通过深度测试（无论深度是多少都渲染）
            // LEqual   = 通过（物体深度 <= 缓冲区深度），默认值
            // Greater  = 只有物体在相机更远处才渲染
            // Less     = 只有物体在相机更近处才渲染
            //
            // 为什么用 Always？
            // 遮罩需要"穿过"任何已渲染物体，在它们的像素上写入 Stencil。
            // 只有这样，遮罩才能真正控制"哪些像素被某个 Geometry 占据"。
            // --------------------------------------------------------------------
            ZTest Always

            // --------------------------------------------------------------------
            // 【Stencil 测试】GPU 对每个像素执行的遮罩逻辑
            //
            // Ref [_StencilID]      → 参考值（来自材质面板的 ID）
            // Comp Always           → 比较函数，Always = 始终通过
            // Pass Replace          → 通过时的操作：直接用 Ref 替换 Stencil 值
            //
            // 执行流程（每个像素）：
            // 1. 读取该像素当前 Stencil 值（BufferValue）
            // 2. 与 Ref 值比较：Always 通过 → 直接跳到第3步
            // 3. Pass Replace：Buffer[xy] = Ref（把 Stencil 写成我们指定的 ID）
            // 4. 颜色混合：Blend Zero One → 颜色不变，渲染完成
            //
            // 结果：屏幕每个像素都被写入了该遮罩的 Stencil ID。
            // 后续渲染的 Geometry 通过 Stencil Test 决定是否覆盖这些像素。
            // --------------------------------------------------------------------
            Stencil
            {
                Ref [_StencilID]
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // URP 核心库：包含 TransformObjectToHClip 等坐标变换函数
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // -------------------- 输入输出结构体 --------------------
            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 positionHCS : SV_POSITION;
            };

            // -------------------- 顶点着色器 --------------------
            // 功能：把物体顶点从模型空间变换到裁剪空间
            //
            // 变换流程（模型空间 → 世界空间 → 观察空间 → 裁剪空间）：
            // 裁剪坐标 = MVP × 模型顶点
            // MVP = Projection × View × Model（Unity 已封装在 TransformObjectToHClip 中）
            //
            // 为什么需要裁剪空间坐标？
            // GPU 需要知道每个像素的深度（用于深度测试）和屏幕位置（用于光栅化）
            v2f vert(appdata v)
            {
                v2f o;
                // TransformObjectToHClip：等价于 UnityCG.cginc 的 UnityObjectToClipPos
                o.positionHCS = TransformObjectToHClip(v.vertex.xyz);
                return o;
            }

            // -------------------- 片元着色器 --------------------
            // 功能：遮罩物体不输出任何颜色
            //
            // 为什么不直接丢弃像素（clip/-1）？
            // discard 会完全跳过该像素，导致 Stencil 指令也不执行！
            // 使用 return 0 既保持像素存在（Stencil 生效），又不写颜色（保持透明）
            half4 frag(v2f i) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
