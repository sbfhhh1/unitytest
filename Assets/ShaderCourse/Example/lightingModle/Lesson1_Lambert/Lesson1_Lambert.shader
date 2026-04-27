// ============================================================================
// Lesson1_Lambert.shader - Lambert漫反射光照模型
// ============================================================================
// 
// 【PPT对应章节】
// - GPU渲染阶段 > 片元Shader > 光照计算
// - Phong光照模型：直接光漫反射
//
// 【核心知识点】
// 1. 顶点Shader：模型空间 → 裁剪空间变换
// 2. 片元Shader：光照计算
// 3. Lambert定律：光照强度 = 法线·光方向
//
// 【Lambert公式】
// I = N·L
// N = 表面法线（归一化）
// L = 光源方向（归一化）
// 结果在 0~1 之间，saturate确保不出现负值
// ============================================================================

Shader "TA_Course/Lesson1_Lambert"
{
    // ==================== 属性面板 ====================
    // 这些参数可以在Unity材质面板中调节
    Properties 
    { 
        // 基础颜色：物体的固有颜色
        _BaseColor ("颜色", Color) = (1,1,1,1) 
    }
    
    SubShader
    {
        Pass
        {
            // ==================== HLSL代码块 ====================
            // Unity使用HLSL语言编写Shader
            HLSLPROGRAM
            
            // 指定顶点和片元着色器函数名
            #pragma vertex vert    // 顶点着色器
            #pragma fragment frag  // 片元着色器
            
            // 引入URP核心库（包含坐标变换函数）
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // 引入URP光照库（包含Light结构体和GetMainLight函数）
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ==================== 数据结构定义 ====================
            
            // appdata：从CPU传递到顶点着色器的数据
            // 对应PPT中的"打包数据发给GPU"
            struct appdata 
            { 
                float4 vertex : POSITION;  // 模型空间顶点坐标（来自Mesh）
                float3 normal : NORMAL;    // 模型空间法线（用于光照计算）
            };
            
            // v2f：从顶点着色器传递到片元着色器的数据
            // 经过插值后每个片元都有独立的数据
            struct v2f 
            { 
                float4 pos : SV_POSITION;      // 裁剪空间坐标（必填，用于光栅化）
                float3 normalWS : TEXCOORD0;   // 世界空间法线（用于光照）
            };

            // 材质属性变量
            float4 _BaseColor;

            // ==================== 顶点着色器 ====================
            // 对应PPT："将顶点坐标从模型空间变换为裁剪空间"
            // 
            // 【渲染管线流程】
            // 输入：模型空间顶点坐标
            // 输出：裁剪空间顶点坐标（GPU后续进行裁剪、NDC、光栅化）
            // 
            // 【坐标空间转换链】
            // 模型空间 → 世界空间 → 观察空间 → 裁剪空间
            //           (M矩阵)      (V矩阵)      (P矩阵)
            // ================================================
            v2f vert (appdata v)
            {
                v2f o;
                
                // --- 位置变换 ---
                // GetVertexPositionInputs：URP封装的坐标变换函数
                // 输入：模型空间坐标
                // 输出：包含多个空间坐标的结构体
                // 
                // 内部实现：MVP矩阵乘法
                // positionCS = P * V * M * vertex
                // 
                // .positionCS = Clip Space（裁剪空间）
                // .positionWS = World Space（世界空间）
                // .positionVS = View Space（观察空间）
                o.pos = GetVertexPositionInputs(v.vertex.xyz).positionCS;
                
                // --- 法线变换 ---
                // GetVertexNormalInputs：将法线从模型空间变换到世界空间
                // 
                // 【注意】法线变换不能直接用M矩阵
                // 需要用M的逆转置矩阵：(M^-1)^T
                // 因为非均匀缩放会导致法线方向错误
                // 
                // URP内部已处理这个问题
                o.normalWS = GetVertexNormalInputs(v.normal).normalWS;
                
                return o;
            }

            // ==================== 片元着色器 ====================
            // 对应PPT："片元Shader重要任务是上色"
            // 
            // 【执行时机】
            // 光栅化后，每个像素都会调用片元着色器
            // 
            // 【输入】
            // - 插值后的顶点数据（法线、UV等）
            // - Uniform变量（材质属性、灯光参数）
            // 
            // 【输出】
            // - SV_Target：像素颜色（RGBA）
            // ================================================
            half4 frag (v2f i) : SV_Target
            {
                // --- Step 1: 准备法线 ---
                // 插值后法线可能不再归一化，需要重新normalize
                // 【原因】顶点之间线性插值会改变向量长度
                float3 normalWS = normalize(i.normalWS);
                
                // --- Step 2: 获取主光源 ---
                // GetMainLight()：URP获取主平行光（如太阳光）
                // 
                // Light结构体包含：
                // - direction：光方向（指向光源的向量）
                // - color：光颜色
                // - distanceAttenuation：距离衰减
                // - shadowAttenuation：阴影衰减
                Light mainLight = GetMainLight();
                
                // --- Step 3: Lambert漫反射计算 ---
                // 【Lambert定律】
                // 光照强度 = max(0, N·L)
                // 
                // dot(N, L)：法线与光方向的点积
                // - 值为1：法线正对光源，最亮
                // - 值为0：法线垂直光方向，边缘
                // - 值为负：法线背对光源，应该为暗
                // 
                // saturate()：将值限制在0~1范围
                // 相当于 max(0, value)
                float ndotl = saturate(dot(normalWS, mainLight.direction));
                
                // --- Step 4: 计算最终颜色 ---
                // 漫反射颜色 = 基础颜色 × 光颜色 × 光照强度
                // 
                // 【颜色混合原理】
                // 物体颜色是反射光的颜色
                // 白光下显示物体本色
                // 红光下红色物体会更亮，绿色物体会变暗
                half3 color = _BaseColor.rgb * mainLight.color * ndotl;
                
                // 返回最终颜色，Alpha=1表示不透明
                return half4(color, 1);
               

            }
            ENDHLSL
        }
    }
    
    // 如果显卡不支持URP，回退到内置Shader
    Fallback "Universal Render Pipeline/Simple Lit"
}