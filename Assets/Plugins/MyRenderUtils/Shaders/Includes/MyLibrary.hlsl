// MyLibrary.hlsl
#ifndef MY_LIBRARY_INCLUDE
#define MY_LIBRARY_INCLUDE
// 基础常量定义
#define PI 3.14159265359
#define HALF_PI 1.57079632679
// 内部使用的随机函数（加个下划线前缀表示内部调用）
inline float _rnd(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

// 内部使用的值噪声核心
inline float _vnoise(float2 uv)
{
    float2 i = floor(uv);
    float2 f = frac(uv);
    f = f * f * (3.0 - 2.0 * f);

    float r0 = _rnd(i);
    float r1 = _rnd(i + float2(1.0, 0.0));
    float r2 = _rnd(i + float2(0.0, 1.0));
    float r3 = _rnd(i + float2(1.0, 1.0));

    return lerp(lerp(r0, r1, f.x), lerp(r2, r3, f.x), f.y);
}

// --- 公开调用的精简函数 ---

// 1. 基础值噪声 (Value Noise)
float ValueNoise(float2 uv)
{
    return _vnoise(uv);
}

// 2. 叠加后的简单噪声 (Simple Noise / FBM)
float SimpleNoise(float2 uv, float scale)
{
    float t = 0.0;
    for (int i = 0; i < 3; i++)
    {
        float freq = pow(2.0, float(i));
        float amp = pow(0.5, float(3 - i));
        t += _vnoise(uv * scale / freq) * amp;
    }
    return t;
}
// 辅助函数：离散角度
            float steppedAngle(float a, float steps) {
                return floor(a * steps) / steps;
            }
// --- 圆角多边形函数 ---
float RoundedPolygon(float2 UV, float Width, float Height, float Sides, float Roundness)
{
    // 空间映射 [-1, 1]
    UV = UV * 2.0 - 1.0;
    
    // 防止除以 0
    float eps = 1e-6;
    UV.x /= (Width + (Width == 0) * eps);
    UV.y /= (Height + (Height == 0) * eps);
    
    Roundness = clamp(Roundness, eps, 1.0);
    float i_sides = floor(abs(Sides));
    float fullAngle = 2.0 * PI / i_sides;
    float halfAngle = fullAngle / 2.0;
    float diagonal = 1.0 / cos(halfAngle);
    
    // 圆角计算
    float chamferAngle = Roundness * halfAngle;
    float remainingAngle = halfAngle - chamferAngle;
    float ratio = tan(remainingAngle) / tan(halfAngle);
    
    float2 chamferCenter = float2(cos(halfAngle), sin(halfAngle)) * ratio * diagonal;
    float distA = length(chamferCenter);
    float distB = 1.0 - chamferCenter.x;
    
    // 极坐标转换与对称化
    UV *= diagonal;
    float angle = atan2(UV.y, UV.x) + HALF_PI + 2.0 * PI;
    angle = abs(fmod(angle + halfAngle, fullAngle) - halfAngle);
    float dist = length(UV);
    
    // 余弦定理 (Al Kashi) 计算圆角过渡
    float angleRatio = 1.0 - (angle - remainingAngle) / chamferAngle;
    float distC = sqrt(distA * distA + distB * distB - 2.0 * distA * distB * cos(PI - halfAngle * angleRatio));
    
    // 结果混合
    float result = (angle < remainingAngle) ? (dist * cos(angle)) : (dist / distC);
    
    // 返回抗锯齿后的 Mask
    return saturate((1.0 - result) / fwidth(result));
}
float RoundedRectangle(float2 UV, float Width, float Height, float Radius)
{
    Radius = max(min(min(abs(Radius * 2), abs(Width)), abs(Height)), 1e-5);
    float2 uv = abs(UV * 2 - 1) - float2(Width, Height) + Radius;
    float d = length(max(0, uv)) / Radius;
    return saturate((1 - d) / fwidth(d));
}
float Rectangle(float2 UV, float Width, float Height)
{
    float2 d = abs(UV - 0.5) * 2.0;
    float2 res = float2(Width, Height);
    float2 q = d - res;
    float distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    return saturate((0.0 - distance) / fwidth(distance));
}

// 2. 椭圆 (Ellipse)
float Ellipse(float2 UV, float Width, float Height)
{
    float d = length((UV - 0.5) * 2.0 / float2(Width, Height));
    return saturate((1.0 - d) / fwidth(d));
}

// 3. 正多边形 (Polygon)
// Sides: 边数, Scale: 缩放
float Polygon(float2 UV, float Sides, float Scale)
{
    float2 p = (UV - 0.5) * 2.0;
    float a = atan2(p.x, p.y) + PI;
    float r = 2.0 * PI / floor(Sides);
    float d = cos(floor(0.5 + a / r) * r - a) * length(p);
    return saturate((Scale - d) / fwidth(d));
}

// 4. 圆环/光圈 (Disc)
float Disc(float2 UV, float Radius, float Thickness)
{
    float d = length((UV - 0.5) * 2.0);
    float circle = saturate((Radius - d) / fwidth(d));
    float hole = saturate((Radius - Thickness - d) / fwidth(d));
    return circle - hole;
}
// 极坐标转换 (Polar Coordinates)
// 将笛卡尔坐标 (XY) 转换为 极径(R) 和 极角(Theta)
float2 PolarCoordinates(float2 UV, float2 Center, float RadialScale, float LengthScale)
{
    float2 delta = UV - Center;
    float radius = length(delta) * 2 * RadialScale;
    float angle = atan2(delta.x, delta.y) * (1.0 / 6.2831853) * LengthScale;
    return float2(radius, angle);
}
// 色阶/分级效果 (Posterize)
// 用于产生阶梯状的不连续效果，常用于能量条或复古像素感
float4 Posterize(float4 In, float4 Steps)
{
    return float4(floor(In * Steps) / Steps);
}

// 提供一个 float 版本的 Posterize 方便单通道处理
float Posterize(float In, float Steps)
{
    return floor(In * Steps) / Steps;
}

// 5. 直线/条纹 (Line)
// Direction: 方向(0为横, 1为纵), Offset: 偏移, Width: 宽度
float ProceduralLine(float2 UV, float Direction, float Offset, float Width)
{
    float coord = Direction > 0.5 ? UV.x : UV.y;
    float d = abs(coord - Offset);
    return saturate((Width * 0.5 - d) / fwidth(d));
}
// 维诺图噪声 (Voronoi / Cellular Noise)
// ---------------------------------------------------------

// 内部使用的随机向量函数
inline float2 _voronoi_rnd(float2 uv, float offset)
{
    float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
    uv = frac(sin(mul(uv, m)) * 46839.32);
    return float2(sin(uv.y + offset) * 0.5 + 0.5, cos(uv.x * offset) * 0.5 + 0.5);
}

// 1. 完整版 Voronoi (带单元格 ID 输出)
// Out: 距离场 (0-1)
// Cells: 单元格随机色/ID
void Voronoi(float2 uv, float angleOffset, float density, out float Out, out float Cells)
{
    float2 g = floor(uv * density);
    float2 f = frac(uv * density);
    float t = 8.0;
    float2 res = float2(0, 0);

    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 lattice = float2(x, y);
            float2 offset = _voronoi_rnd(lattice + g, angleOffset);
            float d = distance(lattice + offset, f);
            if (d < t)
            {
                t = d;
                res = offset;
            }
        }
    }
    Out = t;
    Cells = res.x; // 通常用 offset 的一个分量作为 ID
}

// 2. 精简版 Voronoi (仅返回距离，最常用)
float VoronoiDistance(float2 uv, float angleOffset, float density)
{
    float outDist, outCells;
    Voronoi(uv, angleOffset, density, outDist, outCells);
    return outDist;
}
// 内部使用的 SDF 常量
#ifndef SHAPE_CONSTANTS
#define SHAPE_CONSTANTS
#define AA_SMOOTHNESS 0.001 // 基础抗锯齿平滑度
#endif
// 圆形 SDF 函数 (完整还原 Shader Graph 功能)
// UV: 纹理坐标
// Size: 圆的大小 (0-1)
// Smooth: 边缘平滑度 (0-1), 0.0 为标准抗锯齿
// Thickness: 描边厚度 (0-1)
// RelativeThick: 如果为真，厚度相对于 Size；如果为假，厚度为绝对值
void SDF_Circle_float(float2 UV, float Size, float Smooth, float Thickness, bool RelativeThick, out float Filled, out float Stroke)
{
    // 1. 坐标转换：将 UV 移到中心并映射到 [-1, 1] 空间
    float2 p = (UV - 0.5) * 2.0;
    
    // 2. 计算有向距离场 (Distance Field)
    float d = length(p);
    
    // 3. 计算边缘平滑范围 (AA range)
    // 结合用户自定义 Smooth 和屏幕像素变化率 (fwidth)
    float aa_range = fwidth(d) + AA_SMOOTHNESS + Smooth;
    
    // 4. 处理描边厚度逻辑
    float targetSize = max(Size, 0.0);
    float thick;
    if (RelativeThick)
    {
        // 相对厚度： Thickness 为 1.0 时填满圆
        thick = targetSize * Thickness;
    }
    else
    {
        // 绝对厚度：1.0 为填满整个屏幕空间
        thick = Thickness * 2.0;
    }
    
    // 5. 生成圆面 (Solid Circle) Output
    // 使用 smoothstep 做抗锯齿
    Filled = 1.0 - smoothstep(targetSize - aa_range, targetSize, d);
    
    // 6. 生成圆环 (Stroke Circle) Output
    // 原理：Filled圆 - (内缩一个Thick的Filled圆) = 圆环
    float d_stroke = abs(d - targetSize + thick * 0.5) - thick * 0.5;
    Stroke = 1.0 - smoothstep(aa_range, 0.0, -d_stroke);
    
    // 确保结果在 0-1 之间
    Filled = saturate(Filled);
    Stroke = saturate(Stroke);
}
// 常用混合模式 (Blending Modes)
// Base: 底色, Blend: 混合色, Opacity: 不透明度
// ---------------------------------------------------------

// 1. 叠加 (Overlay) - 增强对比度，明处更亮，暗处更暗
float3 Blend_Overlay(float3 Base, float3 Blend, float Opacity)
{
    float3 result;
    for (int i = 0; i < 3; i++)
    {
        result[i] = (Base[i] < 0.5) ? (2.0 * Base[i] * Blend[i]) : (1.0 - 2.0 * (1.0 - Base[i]) * (1.0 - Blend[i]));
    }
    return lerp(Base, result, Opacity);
}

// 2. 滤色 (Screen) - 漂白效果，常用于光晕、爆炸
float3 Blend_Screen(float3 Base, float3 Blend, float Opacity)
{
    float3 result = 1.0 - (1.0 - Base) * (1.0 - Blend);
    return lerp(Base, result, Opacity);
}

// 3. 强光 (Hard Light) - 类似叠加，但效果更强烈
float3 Blend_HardLight(float3 Base, float3 Blend, float Opacity)
{
    float3 result;
    for (int i = 0; i < 3; i++)
    {
        result[i] = (Blend[i] < 0.5) ? (2.0 * Base[i] * Blend[i]) : (1.0 - 2.0 * (1.0 - Base[i]) * (1.0 - Blend[i]));
    }
    return lerp(Base, result, Opacity);
}

// 4. 柔光 (Soft Light) - 比较温和的对比度增强
float3 Blend_SoftLight(float3 Base, float3 Blend, float Opacity)
{
    float3 result = (1.0 - 2.0 * Blend) * (Base * Base) + 2.0 * Base * Blend;
    return lerp(Base, result, Opacity);
}

// 5. 线性减淡/相加 (Linear Dodge / Add) - 直接叠加亮度
float3 Blend_LinearDodge(float3 Base, float3 Blend, float Opacity)
{
    float3 result = saturate(Base + Blend);
    return lerp(Base, result, Opacity);
}

// 6. 线性加深 (Linear Burn) - 变暗，常用于阴影
float3 Blend_LinearBurn(float3 Base, float3 Blend, float Opacity)
{
    float3 result = saturate(Base + Blend - 1.0);
    return lerp(Base, result, Opacity);
}

// 7. 差值 (Difference) - 常用语特效或比较两张图的差异
float3 Blend_Difference(float3 Base, float3 Blend, float Opacity)
{
    float3 result = abs(Base - Blend);
    return lerp(Base, result, Opacity);
}
// 1. 基础旋转 (弧度制)
float2 Rotate(float2 uv, float2 center, float rotation)
{
    float s, c;
    sincos(rotation, s, c);
    uv -= center;
    float2 r;
    r.x = uv.x * c - uv.y * s;
    r.y = uv.x * s + uv.y * c;
    return r + center;
}

// 2. 角度旋转 (角度制 - 对应你提供的逻辑)
float2 RotateDegrees(float2 uv, float2 center, float rotation)
{
    return Rotate(uv, center, rotation * (PI / 180.0));
}
// uv: 输入坐标
// speed: 移动速度
// width: 线条粗细 (0-1)
// density: 条纹密度（重复次数）
// angle: 旋转角度（弧度制，如 45度写成 45 * PI / 180）
float ScanLine(float2 uv, float speed, float width, float density, float angle)
{
    // 1. 将 UV 居中并进行旋转
    float2 p = uv - 0.5;
    float s = sin(angle);
    float c = cos(angle);
    // 旋转矩阵应用：我们只需要 Y 轴的分量来生成横向/斜向条纹
    float rotY = p.x * s + p.y * c;
    
    // 2. 引入时间和密度
    // 使用 frac 实现循环，通过 density 控制条纹数量
    float linePos = frac(rotY * density - _Time.y * speed);
    
    // 3. 计算距离并平滑输出
    // 0.5 是 frac 的中点，通过 abs(linePos - 0.5) 得到居中的线条
    float d = abs(linePos - 0.5);
    return saturate((width * 0.5 - d) / fwidth(d));
}
// 1. 角度分割 (Angular Segment)
// 利用 frac(angle * frequency) 产生断续效果
float AngularSegment(float2 polarUV, float frequency, float threshold)
{
    float segVal = frac(polarUV.y * frequency);
    return step(threshold, segVal);
}
float3 BasicHSVtoRGB(float h)
{
    float4 t = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(float3(h, h, h) + t.xyz) * 6.0 - 3.0);
    return saturate(p - 1.0);
}
// 离散化/步进函数：用于产生阶梯状的非连续效果，常用于 UI 刻度或能量条
float steppedAngleFunc(float In, float Steps)
{
    return floor(In * Steps) / Steps;
}

float DrawRing(float dist, float radius, float width, float smoothness)
{
    float rOuter = radius + width * 0.5;
    float rInner = radius - width * 0.5;
    return smoothstep(rInner - smoothness, rInner + smoothness, dist)
         * (1.0 - smoothstep(rOuter - smoothness, rOuter + smoothness, dist));
}
#endif