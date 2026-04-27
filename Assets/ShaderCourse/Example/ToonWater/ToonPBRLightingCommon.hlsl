// ============================================================================
// ToonPBRLightingCommon.hlsl
// 作用：
// 1. 把“PBR 参数驱动下的卡通光照”整理成可复用函数
// 2. 给水面、石头、木头、道具等不同 shader 统一调用
// 3. 让整个场景保持同一种明暗分层、高光和边缘光风格
//
// 设计思路：
// - 保留 PBR 里最常见的几个参数：albedo、metallic、smoothness
// - 不直接输出写实 PBR，而是把光照重新压成“卡通分层”
// - 再叠加卡通高光、环境反射和边缘光，形成统一风格
// ============================================================================

#ifndef SHADERCOURSE_TOON_PBR_LIGHTING_COMMON_INCLUDED
#define SHADERCOURSE_TOON_PBR_LIGHTING_COMMON_INCLUDED

// 这是“输入数据包”：
// 把一个像素做光照时所需的最基本信息打包起来，方便复用。
struct ToonPBRLightingInput
{
    half3 albedo;
    half3 normalWS;
    half3 viewDirWS;
    float3 positionWS;
    float4 shadowCoord;
};

// 这是“风格参数包”：
// 这些参数决定了卡通光照的视觉风格。
struct ToonPBRLightingParams
{
    half metallic;
    half smoothness;
    half shadowStep;
    half highlightStep;
    half bandSoftness;
    half shadowStrength;
    half3 specularColor;
    half3 rimColor;
    half rimPower;
    half rimStrength;
    half3 reflectionTint;
    half iblStrength;
};

// ----------------------------------------------------------------------------
// 1. 卡通漫反射分层
// ----------------------------------------------------------------------------
// ndotl 是法线与光方向的点积：
// - 1 说明完全朝向光
// - 0 说明与光垂直
// 我们不用真实连续渐变，而是切成几层色阶，让它更卡通。
half ToonBandStep(half ndotl, ToonPBRLightingParams params)
{
    half shadowBand = smoothstep(
        params.shadowStep - params.bandSoftness,
        params.shadowStep + params.bandSoftness,
        ndotl
    );

    half highlightBand = smoothstep(
        params.highlightStep - params.bandSoftness,
        params.highlightStep + params.bandSoftness,
        ndotl
    );

    // 第一层：阴影层，整体偏暗。
    half toon = lerp(params.shadowStrength, 0.85h, shadowBand);

    // 第二层：高亮层，让受光面更“跳”一些。
    toon = lerp(toon, 1.1h, highlightBand);
    return toon;
}

// ----------------------------------------------------------------------------
// 2. 卡通高光
// ----------------------------------------------------------------------------
// 先按 PBR/Blinn-Phong 常见思路算半角向量，再把结果裁成高光块。
// 这样既保留 smoothness 带来的“材质差别”，又不会太写实。
half ToonSpecularStep(
    half3 normalWS,
    half3 lightDirWS,
    half3 viewDirWS,
    half smoothness,
    half bandSoftness)
{
    half3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
    half spec = pow(saturate(dot(normalWS, halfDir)), lerp(8.0h, 128.0h, smoothness));
    return smoothstep(0.5h, 0.5h + bandSoftness, spec);
}

// ----------------------------------------------------------------------------
// 3. 边缘光
// ----------------------------------------------------------------------------
// 用观察方向与法线的夹角决定边缘亮度。
// 这一步很适合卡通风格，因为它能明确地强调轮廓。
half ToonRimLight(half3 normalWS, half3 viewDirWS, half rimPower, half rimStrength)
{
    half rim = pow(1.0h - saturate(dot(normalWS, viewDirWS)), rimPower);
    return rim * rimStrength;
}

// ----------------------------------------------------------------------------
// 4. 主光 + 附加光 + 环境反射 的统一求值
// ----------------------------------------------------------------------------
// 这是整个“卡通 PBR 光照”的核心函数。
// 调用方只需要准备好输入结构和参数结构，就能得到统一风格的结果。
half3 EvaluateToonPBRLighting(ToonPBRLightingInput input, ToonPBRLightingParams params)
{
    Light mainLight = GetMainLight(input.shadowCoord);
    half3 lightDirWS = normalize(mainLight.direction);
    half ndotl = saturate(dot(input.normalWS, lightDirWS));

    // 主光的卡通漫反射。
    half toonBand = ToonBandStep(ndotl, params);
    half attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
    half3 diffuse = input.albedo * toonBand * attenuation * mainLight.color;

    // 用 metallic 构造一个基础反射率 F0。
    // 金属度越高，物体本身颜色越参与高光。
    half3 F0 = lerp(half3(0.04h, 0.04h, 0.04h), input.albedo, params.metallic);

    // 再把高光裁成“卡通亮斑”。
    half toonSpecular = ToonSpecularStep(
        input.normalWS,
        lightDirWS,
        input.viewDirWS,
        params.smoothness,
        params.bandSoftness
    ) * attenuation;

    half3 specular = params.specularColor * toonSpecular * lerp(0.35h, 1.0h, F0);

    // 附加光只做少量补光，避免打碎主层次。
    #if defined(_ADDITIONAL_LIGHTS)
        uint additionalLightsCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < additionalLightsCount; ++lightIndex)
        {
            Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);
            half addNdotL = saturate(dot(input.normalWS, additionalLight.direction));
            half addBand = ToonBandStep(addNdotL, params);
            half addAtten = additionalLight.distanceAttenuation * additionalLight.shadowAttenuation;
            diffuse += input.albedo * addBand * addAtten * additionalLight.color * 0.3h;
        }
    #endif

    // 环境反射：
    // 让物体保留一点“PBR 反射味道”，避免卡通之后显得过于死板。
    half roughness = max(1.0h - params.smoothness, 0.04h);
    half3 reflectDirWS = reflect(-input.viewDirWS, input.normalWS);
    half3 ibl = GlossyEnvironmentReflection(reflectDirWS, roughness, 1.0h).rgb;
    ibl *= params.reflectionTint * params.iblStrength;

    // 边缘光：
    // 用来勾轮廓，尤其适合场景统一风格。
    half rim = ToonRimLight(input.normalWS, input.viewDirWS, params.rimPower, params.rimStrength);
    half3 rimColor = params.rimColor * rim;

    return diffuse + specular + ibl + rimColor;
}

#endif
