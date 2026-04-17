# MagicBox Stentil Shader 测试说明

## 文件结构
- `MagicBox.fbx` - 模型文件
- `Materials/MagicBox_StentilMask.mat` - Mask材质（红色，Stencil ID=1）
- `Materials/MagicBox_StentilGeometry.mat` - Geometry材质（绿色，通过Stencil测试）
- `Materials/MagicBox_StentilReveal.mat` - Reveal材质（蓝色，显示遮罩内容）

## 快速测试步骤

### 1. 基础 Stentil Mask 测试
1. 把 `MagicBox.fbx` 拖到场景里
2. 在 Project 窗口选中 `Materials/MagicBox_StentilMask.mat`
3. 拖到场景中的 MagicBox 上
4. 观察效果：模型应该显示为红色，并写入 Stencil Buffer (ID=1)

### 2. Stentil Geometry 测试（需要配合 Mask）
1. 复制一个 MagicBox，稍微偏移位置
2. 一个用 Mask 材质，一个用 Geometry 材质
3. Geometry 材质只在 Mask 的 Stencil 区域内显示

### 3. Stentil Reveal 测试
1. 创建两个重叠的 MagicBox
2. 后面的用 Mask 材质
3. 前面的用 Reveal 材质
4. 观察 Reveal 效果

## Shader 参数说明

### Stentil_Mask
- `_BaseColor` - 基础颜色（默认红色）
- `_StencilID` - Stencil ID（默认1）

### Stentil_Geometry
- `_BaseColor` - 基础颜色（默认绿色）
- `_StencilID` - 要匹配的 Stencil ID（默认1）
- `_StencilComp` - 比较操作（默认6=Equal）
- `_StencilOp` - 通过后的操作（默认2=Keep）

### Stentil_Reveal
- `_BaseColor` - 基础颜色（默认蓝色）
- `_RevealColor` - 揭示高亮颜色（默认白色）
- `_StencilID` - Stencil ID（默认1）
- `_RevealIntensity` - 揭示强度（默认1）
