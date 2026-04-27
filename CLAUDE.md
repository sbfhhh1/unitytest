# Shader Course URP

Unity 6000.3.2f1  Shader 教学项目，使用 URP 17.3.0 + VFX Graph 17.3.0。

## 项目结构

```
Assets/
├── Courseware/        # 课程材料
├── Editor/            # 编辑器脚本
├── Materials/         # 材质
├── Plugins/           # DOTween
├── Scenes/            # 场景文件
├── Screenshots/       # 截图
├── Settings/          # URP 管线配置
├── ShaderCourse/      # 主 Shader 教学内容
│   ├── Example/       # 示例 shader
│   ├── Shaders/       # 进阶 shader
│   ├── Scripts/       # 运行时脚本
│   ├── UIPrototype/   # UI 原型
│   └── VertexShaderExamples/  # 顶点 shader 示例
├── Shaders/           # 项目 shader
├── TextMesh Pro/      # TMP 资源
├── TutorialInfo/      # 模板脚本
└── VFX/               # VFX Graph 内容
```

## 技术栈

- **渲染管线**: Universal Render Pipeline 17.3.0
- **VFX**: Visual Effect Graph 17.3.0
- **输入**: Input System 1.17.0
- **动画**: DOTween (Plugins), Timeline 1.8.9
- **UI**: TextMesh Pro, UI Toolkit

## 常用命令

- Unity 编辑器通过 MCP 控制
- VFX Graph 在 Assets/VFX/ 目录下
- Shader 文件在 Assets/ShaderCourse/ 下

## MCP

Unity MCP 通过 SSE 连接 http://127.0.0.1:8080/mcp

## 代码规范

- Shader: HLSL, URP 兼容
- C#: 命名空间按功能划分
- VFX: VFX Graph (.vfx) + C# Controller
