# Unity6 角色详情界面 UI 还原 — 专业 AI 提示词文档

> 参考截图：`ScreenShot_2026-04-21_124716_162.png`  
> 风格定位：暗黑奇幻 RPG · 角色详情面板  
> 目标引擎：Unity 6 · UI Toolkit 或 uGUI（推荐 UI Toolkit）

---

## 一、整体布局（Layout）

```
提示词：
Create a full-screen dark fantasy RPG character detail panel in Unity 6 using UI Toolkit.
The layout is divided into three vertical columns:

LEFT COLUMN (width: 80px, height: 100%):
- Vertical icon navigation bar with 6 circular icon buttons
- Icons: Bow, Sword (active/highlighted), Horse, Crossed-swords, Horse2, Lock
- Active icon has a glowing cyan circle background (#00E5FF, opacity 0.9)
- Inactive icons are semi-transparent white (opacity 0.5)
- Anchored: left-center, fixed width 80px, stretch height

CENTER COLUMN (width: ~55%, height: 100%):
- Top-left: Gold eagle emblem logo (64x64) + title text "SON OF THE FOREST" in gold (#C9A84C)
- Below title: vertical tab menu list (Attributes, Arms, Relic, Life stone, Talent, Material)
- Active tab "Attributes" has a cyan diamond bullet (◆) and white bold text
- Inactive tabs have smaller diamond bullets and gray text
- Center: large character artwork (full-body illustration, transparent background)
  positioned center-bottom, overflowing slightly beyond panel bounds
- Anchored: stretch, padding-left 80px

RIGHT COLUMN (width: ~30%, height: 100%):
- Anchored: right, fixed width 380px, stretch height
- Contains: character name, star rating, level bar, stats list, details section, upgrade button
- Close button (X) top-right corner, white, 32x32
```

---

## 二、锚点与自适应（Anchors & Responsive）

```
提示词：
Set up Unity UI anchors for responsive layout:

1. Root Panel: anchor stretch-all (min 0,0 / max 1,1), pivot center
   - Background: dark teal gradient overlay (#0A1A1A to #0D2B2B), opacity 0.95
   - Add a radial vignette darkening at edges using a fullscreen Image with radial gradient sprite

2. Left Nav Bar: anchor left-stretch (min 0,0 / max 0,1), width 80px fixed
   - Each icon button: anchor top-center, size 56x56, margin 12px vertical

3. Center Content: anchor stretch (min 0.08, 0 / max 0.72, 1)
   - Title bar: anchor top-left, height 60px
   - Tab list: anchor top-left, offset top 70px, width 200px
   - Character art: anchor bottom-center, pivot bottom-center (0.5, 0)
     size 520x720, position offset Y: -20px (slight overflow)

4. Right Panel: anchor right-stretch (min 0.7, 0 / max 1.0, 1), padding 24px
   - Close button: anchor top-right, size 32x32, offset (-16, -16)
   - Name label: anchor top-left, offset top 40px
   - Star row: anchor top-left, offset top 90px
   - Level bar: anchor top-left, offset top 130px, width 100%
   - Stats list: anchor top-left, offset top 170px, width 100%
   - Details section: anchor top-left, offset top 420px
   - Upgrade button: anchor bottom-center, height 52px, width 90%, offset bottom 24px
```

---

## 三、色标（Color Palette）

```
提示词：
Use the following color palette for the UI:

Background:
  - Panel BG:         #0A1A1A (very dark teal-black)
  - Overlay gradient: #0D2B2B → #061212 (radial, center lighter)
  - Vignette:         #000000 at 60% opacity on edges

Accent / Highlight:
  - Cyan glow:        #00E5FF  (active icons, borders, UPGRADE button, DETAILS label)
  - Cyan dim:         #00B4CC  (secondary borders, diamond bullets)
  - Gold title:       #C9A84C  (game title, stat values)
  - Gold star:        #FFD700  (star rating icons)

Text:
  - Primary white:    #FFFFFF  (character name, active tab, stat labels)
  - Secondary gray:   #A0B0B0  (inactive tabs, description text)
  - Value highlight:  #C9A84C  (stat numbers on right panel)

UI Elements:
  - Separator line:   #1E4040  (thin 1px horizontal dividers)
  - Button BG:        #00C8D4  (UPGRADE button fill)
  - Button text:      #FFFFFF  bold, letter-spacing 2px
  - Icon active ring: #00E5FF  with 8px blur glow effect
  - Close button:     #FFFFFF  with hover state #FF4444
```

---

## 四、动效（Animations）

```
提示词：
Implement the following UI animations using Unity 6 UI Toolkit transitions or DOTween:

1. Panel Open Animation (duration: 0.4s, ease: OutCubic):
   - Background fades in: opacity 0 → 0.95
   - Left nav slides in from left: translateX(-80px) → 0
   - Right panel slides in from right: translateX(+380px) → 0
   - Character art scales up: scale(0.85) → scale(1.0) with fade-in
   - Stagger delay: left=0s, center=0.1s, right=0.15s, char=0.2s

2. Tab Switch Animation (duration: 0.2s, ease: OutQuad):
   - Active tab: color transition gray → white, bullet scale 0.8 → 1.0
   - Previous tab: color transition white → gray
   - Content area: fade out (0.1s) then fade in (0.1s)

3. Icon Navigation Hover (duration: 0.15s):
   - Scale: 1.0 → 1.1
   - Glow ring opacity: 0 → 0.6
   - On click: scale pulse 1.1 → 0.95 → 1.0 (0.1s)

4. Ambient Particle Effect (looping):
   - Small golden/cyan floating particles in background
   - 15-20 particles, random drift upward, opacity fade in/out
   - Use Unity Particle System placed behind UI canvas (World Space)

5. Character Art Idle Animation (looping, 3s cycle):
   - Subtle vertical float: translateY(0) → translateY(-8px) → translateY(0)
   - Ease: InOutSine
   - Slight glow pulse on character edges (shader-based rim light)

6. UPGRADE Button Pulse (looping, 2s cycle):
   - Border glow intensity: 0.6 → 1.0 → 0.6
   - Subtle scale: 1.0 → 1.02 → 1.0
   - Color shimmer: scan line effect moving left to right

7. Stats Number Count-Up (on panel open, 0.6s):
   - All stat numbers count up from 0 to final value
   - Ease: OutExpo
   - Stagger: 0.05s between each stat row
```

---

## 五、交互逻辑（Interaction）

```
提示词：
Implement the following interaction behaviors in Unity 6:

1. Left Navigation Icons:
   - Click: switch active icon (update visual state), trigger tab content change
   - Active state: cyan glow ring visible, icon fully opaque
   - Inactive state: no ring, icon 50% opacity
   - Locked icon (bottom): show lock overlay, click shows "Feature Locked" tooltip

2. Tab Menu (Attributes / Arms / Relic / Life stone / Talent / Material):
   - Click tab: animate active state, load corresponding content panel
   - Keyboard: Up/Down arrow keys navigate tabs
   - Current active: "Attributes" — shows stats panel on right

3. Close Button (X):
   - Click: play close animation (reverse of open), then destroy/hide panel
   - Hover: color change white → red (#FF4444), scale 1.0 → 1.15
   - ESC key: same as close button

4. UPGRADE Button:
   - Click: check if max level (LV 83/90 → not max)
   - If upgradeable: play upgrade animation, show cost popup
   - If max level: button grayed out, tooltip "Max Level Reached"
   - Hover: brightness +20%, cursor change to pointer

5. Star Rating (7 stars shown):
   - Click on stars: no interaction (display only)
   - Tooltip on hover: show "Hero Rank: 7 Stars"

6. Level Bar (LV 83/90):
   - Visual progress bar showing 83/90 fill
   - Hover: tooltip showing "EXP needed to next level"

7. Stats Rows (Life Limit, Attack Power, etc.):
   - Hover: row highlight with subtle cyan tint background
   - Click: show detailed breakdown popup

8. Scroll behavior:
   - If stats list exceeds panel height: enable vertical scroll
   - Custom scrollbar style matching dark theme (thin, cyan thumb)

9. Favorability row (in DETAILS section):
   - Shows heart icon + value 221
   - Hover: tooltip "Favorability affects story dialogue options"
```

---

## 六、音效（Audio / SFX）

```
提示词：
Add the following sound effects using Unity 6 AudioSource:

1. Panel Open:
   - SFX: deep whoosh + magical shimmer (0.4s)
   - Suggested: "ui_panel_open_fantasy.wav"
   - Volume: 0.7, pitch: 1.0

2. Tab / Icon Switch:
   - SFX: soft click + brief magical chime (0.15s)
   - Suggested: "ui_tab_switch.wav"
   - Volume: 0.5, pitch: randomize 0.95–1.05 for variation

3. Button Hover:
   - SFX: very subtle tick (0.05s)
   - Volume: 0.3

4. UPGRADE Button Click:
   - SFX: powerful magical activation sound (0.6s)
   - Suggested: "ui_upgrade_confirm.wav"
   - Volume: 0.85, pitch: 1.0

5. Close Button Click:
   - SFX: soft dismiss whoosh (0.2s)
   - Volume: 0.6

6. Stats Count-Up:
   - SFX: rapid soft ticking during number animation
   - Stop when animation completes
   - Volume: 0.25

7. Ambient Background:
   - Loop: subtle forest/mystical ambience (low volume)
   - Volume: 0.15, fade in with panel open

Implementation note:
  Use Unity AudioManager singleton pattern.
  All UI SFX should use AudioMixerGroup "UI_SFX" with slight reverb.
  Ambient loop uses "UI_Ambient" group.
  Respect global SFX volume setting from GameSettings.
```

---

## 七、Shader / 视觉特效补充

```
提示词：
Add the following shader and visual effects:

1. Character Art Edge Glow (URP Shader Graph):
   - Rim lighting effect: cyan (#00E5FF) glow on character silhouette edges
   - Intensity: 0.6, width: 8px
   - Animate: pulse with 3s cycle (matches idle float animation)

2. Panel Background Shader:
   - Dark teal noise texture overlay (subtle, opacity 0.08)
   - Animated slow drift: UV scroll speed (0.005, 0.003)
   - Creates organic "living darkness" feel

3. UPGRADE Button Scan Line:
   - Horizontal scan line moving left to right, looping every 2s
   - Color: white at 30% opacity
   - Width: 4px, blur: 2px

4. Active Icon Glow:
   - Bloom-like glow using UI material with additive blending
   - Cyan color, radius 12px, intensity 0.8

5. Particle System (background):
   - 20 particles max, lifetime 3-5s
   - Start size: 2-4px, color: gold (#FFD700) to cyan (#00E5FF)
   - Emission: 3 per second
   - Movement: upward drift with slight horizontal sway
   - Render mode: Billboard, Layer: UI (sorting layer above background)
```

---

## 八、Unity 6 实现建议

### 推荐架构

```
CharacterDetailPanel (UI Document)
├── PanelRoot (VisualElement, fullscreen)
│   ├── BackgroundLayer (Image, dark gradient)
│   ├── ParticleContainer (GameObject, World Space)
│   ├── LeftNavBar (VisualElement)
│   │   └── NavIconButton × 6 (Button)
│   ├── CenterContent (VisualElement)
│   │   ├── TitleBar (VisualElement)
│   │   ├── TabMenu (VisualElement)
│   │   │   └── TabItem × 6 (Button)
│   │   └── CharacterArtwork (Image)
│   └── RightPanel (VisualElement)
│       ├── CloseButton (Button)
│       ├── CharacterName (Label)
│       ├── StarRating (VisualElement)
│       ├── LevelBar (VisualElement)
│       ├── StatsList (ScrollView)
│       │   └── StatRow × 5 (VisualElement)
│       ├── DetailsSection (VisualElement)
│       └── UpgradeButton (Button)
```

### 关键 USS 样式片段

```css
/* Panel Root */
.panel-root {
    background-color: rgba(10, 26, 26, 0.95);
    width: 100%;
    height: 100%;
    flex-direction: row;
}

/* Active Nav Icon */
.nav-icon--active {
    background-color: rgba(0, 229, 255, 0.25);
    border-radius: 50%;
    border-width: 2px;
    border-color: #00E5FF;
}

/* Upgrade Button */
.upgrade-button {
    background-color: #00C8D4;
    color: white;
    font-size: 18px;
    letter-spacing: 3px;
    -unity-font-style: bold;
    border-radius: 4px;
    height: 52px;
}

/* Stat Value */
.stat-value {
    color: #C9A84C;
    font-size: 16px;
    -unity-font-style: bold;
}
```

---

## 九、资源清单

| 资源类型 | 说明 | 建议来源 |
|---------|------|---------|
| 角色立绘 | 全身透明背景PNG，≥1024px高 | 美术团队 / AI生成 |
| 图标精灵图 | 6个导航图标，白色线条风格 | Unity Asset Store / Kenney.nl |
| 噪声纹理 | 背景扰动用，256x256灰度 | 程序生成 |
| 粒子贴图 | 小圆点/星形，4x4px | 程序生成 |
| 字体 | 标题用衬线金色字体，正文用无衬线 | Google Fonts: Cinzel (标题), Rajdhani (正文) |
| 音效 | 见第六节清单 | Freesound.org / Unity Asset Store |
| 扫描线Shader | UPGRADE按钮特效 | 自制 (见第七节) |

---

*文档生成时间：2026-04-21*  
*参考截图：Son of the Forest — 角色详情界面*  
*适用版本：Unity 6.0+，URP 17+*
