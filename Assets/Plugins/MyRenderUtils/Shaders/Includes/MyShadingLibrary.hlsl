// MyShadingLibrary.hlsl
#ifndef MY_SHADING_LIBRARY_INCLUDE
#define MY_SHADING_LIBRARY_INCLUDE

// 让该文件被单独打开时也能被编辑器正确解析：
// 若外部尚未包含 URP Core.hlsl（导致宏未定义），这里提供最小兜底定义。
#ifndef TEXTURE2D
#define TEXTURE2D(textureName) Texture2D textureName
#endif

#ifndef SAMPLER
#define SAMPLER(samplerName) SamplerState samplerName
#endif

#ifndef TEXTURE2D_PARAM
#define TEXTURE2D_PARAM(textureName, samplerName) Texture2D textureName, SamplerState samplerName
#endif

#ifndef TEXTURE2D_ARGS
#define TEXTURE2D_ARGS(textureName, samplerName) textureName, samplerName
#endif

#ifndef SAMPLE_TEXTURE2D
#define SAMPLE_TEXTURE2D(textureName, samplerName, uv) textureName.Sample(samplerName, uv)
#endif

// =========================================================
// 通用着色辅助库（URP）
// 目标：把“法线、视差、光照、色彩校正”这类高频逻辑抽离，
//      让主 Shader 只保留流程编排，提升可读性和复用性。
// =========================================================

// -----------------------------------------
// 1) 法线与空间变换
// -----------------------------------------

// 使用切线空间法线 + TBN 转换到世界空间。
// normalIntensity 用于控制法线强度（只放大 xy，保持 z 由法线贴图提供）。
float3 ApplyNormalTSToWS(float3 normalTS, float3x3 tbn, float normalIntensity)
{
    normalTS.xy *= normalIntensity;
    return normalize(mul(normalTS, tbn));
}

// 构建 TBN 矩阵：列分别为切线、副切线、法线（都在世界空间）
float3x3 BuildTBN(float3 tangentWS, float3 bitangentWS, float3 normalWS)
{
    return float3x3(normalize(tangentWS), normalize(bitangentWS), normalize(normalWS));
}

// -----------------------------------------
// 2) 视差映射
// -----------------------------------------

// 迭代式视差 UV 偏移（与常见 Parallax Offset 逻辑一致）。
// parallaxScale 建议取小值（例如 0~5，再乘 0.01）。
float2 ApplyParallaxUVIterative(
    TEXTURE2D_PARAM(heightTex, samplerHeightTex),
    float2 uv,
    float3 viewDirTS,
    float parallaxScale,
    int steps)
{
    float2 uvParallax = uv;
    [loop]
    for (int step = 0; step < steps; step++)
    {
        float height = SAMPLE_TEXTURE2D(heightTex, samplerHeightTex, uvParallax).r;
        uvParallax -= (0.5 - height) * viewDirTS.xy * parallaxScale * 0.01;
    }
    return uvParallax;
}

// -----------------------------------------
// 3) 光照模型（Phong/Blinn-Phong）
// -----------------------------------------

// 单灯 Phong：返回 漫反射 + 高光 的贡献
float3 EvaluatePhongLighting(
    float3 normalWS,
    float3 lightDirWS,
    float3 viewDirWS,
    float3 lightColor,
    float atten,
    float3 baseColor,
    float3 specMask,
    float shininess,
    float specIntensity)
{
    float ndotl = max(0.0, dot(normalWS, lightDirWS));
    float diffTerm = min(atten, ndotl);
    float3 diffuse = diffTerm * lightColor * baseColor;

    float3 halfDir = normalize(lightDirWS + viewDirWS);
    float ndoth = max(0.0, dot(normalWS, halfDir));
    float3 specular = pow(ndoth, shininess) * diffTerm * lightColor * specIntensity * specMask;

    return diffuse + specular;
}

// -----------------------------------------
// 4) 色彩与输出
// -----------------------------------------

// ACES Filmic 近似（常用快速版）
float3 ToneMapACES(float3 x)
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

// 手动 sRGB -> 近似线性
float3 SRGBToLinearApprox(float3 c)
{
    return pow(c, 2.2);
}

// 手动近似线性 -> sRGB
float3 LinearToSRGBApprox(float3 c)
{
    return pow(max(c, 0.0), 1.0 / 2.2);
}

#endif
