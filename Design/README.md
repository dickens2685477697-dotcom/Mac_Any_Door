# Design assets

本目录是 Mac 任意门视觉资产的单一设计源。运行时代码位于
`Sources/MacAnyDoor/DesignSystem/`，两处必须同步维护。

## 目录

- `References/glass-icon-master.png`：用户本轮提供的唯一视觉源，同时复制到 Swift Package Resources。
- `Icons/Source/glass-icons.svg`：直接裁取参考图 4×4 网格的 image-backed SVG source，含所有语义 `<symbol>`。
- `Icons/Optimized/glass-icons.svg`：发布/交付副本；与 source 保持相同裁切和内嵌源图。
- `docs/DESIGN_SYSTEM.md`：颜色、材质、图标、组件、状态、动效和无障碍规范。

## 维护规则

1. 语义名称优先，业务界面只调用 `PortalGlyph`，不直接使用 SF Symbol 字符串。
2. 本轮“直接使用参考图”例外采用 image-backed SVG：每个 symbol 使用 `222×222` tile viewBox；源 PNG 以 data URI 嵌入 SVG，资产可独立携带，不依赖网络或外部文件。
3. 小尺寸控件只显示 template glyph；32 pt 以上才显示玻璃底座，避免缩小时材质糊成一团。
4. 菜单栏使用单色 template 图标；真实图片缩略图不套用玻璃图标。
5. 修改源图或裁切坐标后同步更新 `Optimized/` 与 `Sources/MacAnyDoor/Resources/Icons/glass-icon-master.png`；代码内 `PortalGlyphShape` 仅作为小尺寸运行时 fallback，运行 `xmllint --noout` 与 `swift test`。

## 生成记录

本轮不重新生成图像：用户提供的 `glass-icon-master.png` 是唯一视觉源。SVG 通过 `<image>` / `<use>` 裁切并嵌入该文件，确保 Logo 与 16 个图标的玻璃高光、蓝色辉光和像素细节完全一致。当前环境未提供 `OPENAI_API_KEY`，因此不调用 CLI Image-2。
