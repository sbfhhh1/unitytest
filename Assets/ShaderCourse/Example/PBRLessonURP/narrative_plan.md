## Audience

- Students who have learned Unity render pipeline basics and foundational lighting models
- Learners transitioning from Lambert / Blinn-Phong thinking toward physically based shading

## Objective

- Explain why PBR is needed after traditional lighting models
- Build a clear mental model of metallic, roughness, Fresnel, microfacet BRDF, and IBL
- Reuse the course's existing URP PBR code structure so students see continuity instead of a conceptual reset
- Deliver one editable PPT and one URP example shader in a new Example folder

## Narrative Arc

1. Review the limits of basic lighting models
2. Introduce the goals of PBR: consistency, energy conservation, and material realism
3. Explain the three BRDF pillars: D, G, F
4. Explain metallic / smoothness parameter meaning
5. Explain direct light vs indirect light division of labor
6. Explain IBL and SH in URP
7. Land the ideas in a course-consistent URP example shader
8. Summarize and assign practice

## Slide List

1. Cover
2. Bridge from basic lighting to PBR
3. Why traditional lighting is not enough
4. What PBR is solving
5. Material parameters: metallic and smoothness
6. Microfacet BRDF overview
7. Fresnel and view-angle change
8. IBL and SH in URP
9. URP example shader structure
10. Key code walkthrough
11. Debug / observation checklist
12. Wrap-up and exercises

## Source Plan

- Desktop local PPT: `C:\Users\lafa\Desktop\Unity URP PBR光照原理深度解析.pptx`
- Reused extracted media from that PPT
- `Assets/ShaderCourse/Example/Stentil/Shaders/Stentil_Geometry.shader`
- `Assets/ShaderCourse/Example/lightingModle/URP_BlinnPhong_Full_With_SH/URP_BlinnPhong_Full_With_SH.shader`
- `Assets/ShaderCourse/Example/DepthTestURP/Shaders/DepthTest_PBR_Demo.shader`

## Output

- `Assets/ShaderCourse/Example/PBRLessonURP/Unity Shader编程_PBR光照课件.pptx`
- `Assets/ShaderCourse/Example/PBRLessonURP/Shaders/URP_PBR_Lesson.shader`
