# 交接文档（Handoff）

> 最后更新：2026-08-30。本文档面向接下来在新目录接手维护的人（或 agent），总结项目现状、关键决定与日常维护操作。

## 1. 项目是什么

RunCat Neo **Twocats** 是 [RunCat Neo](https://runcat-dev.github.io/RunCatNeo/)（原作者
Kyome22 / Takuto Nakamura，仓库 [runcat-dev/RunCatNeo](https://github.com/runcat-dev/RunCatNeo)）的个人需求修改版，Apache-2.0 双向继承。

**本 fork 相对原版的全部差异**（其余功能与原版一致）：

| 差异 | 说明 |
| --- | --- |
| 双跑者同屏 | 菜单栏同时显示主跑者 + 第二跑者，各自独立动画与着色；菜单里可选/取消 |
| 跑者间距可配置 | 0–20px 滑块（设置 → 跑者 → 外观），默认 3px，实时生效并持久化 |
| 独立 Bundle ID | `com.changediff.twocats.RunCatNeo`，可与原版（`com.kyome.Neo.RunCat`）同时运行，偏好互不干扰 |

## 2. 仓库与分支状态

- **GitHub 仓库**：`changediff/RunCatNeo2cats`（**注意：已从 RunCatNeo2 改名**；旧地址由 GitHub 自动重定向，但本地 remote 应指向新地址：`git@github.com:changediff/RunCatNeo2cats.git`）
- **工作分支**：`twocats`（所有工作都在此分支），`main` 仍停留在上游基点 `b3b1543`，**尚未合并**
- `twocats` 分支上的提交（按序）：
  1. `4728890` Add support for a secondary runner in the menu bar（双跑者功能，含测试与 10 语言本地化）
  2. `46752da` Add AGENTS.md as the canonical agent guide（CLAUDE.md 改为指向 AGENTS.md）
  3. `998bdd4` Make the gap between runners configurable（可配置间隔）
  4. `dfe115e` Change the bundle identifier to com.changediff.twocats.RunCatNeo
  5. `ade42ed` Replace the landing page with a fork introduction（GitHub Pages 介绍页）
  6. `40bf6fc` Update repository links after the rename（仓库改名后更新 docs 链接）
- 关键代码位置：`RunnerService.swift`（runner 解析/下发）、`RunnerBar.swift`(双帧拼接与间距)、`Dashboard.swift`（菜单 action）、`UserDefaultsRepository.swift`（`RUNNER_GAP` 等键）、`RunnerSettingsView.swift`（滑块）。

## 3. GitHub Pages

- **地址**：https://changediff.github.io/RunCatNeo2cats/（改名后旧 URL 会重定向一段时间）
- **发布源**：`twocats` 分支的 `/docs` 目录（Settings → Pages 查看/修改）
- 页面是自包含单文件 `docs/index.html`（中文、深色主题），**不依赖**上游原来的 markdown 加载器；上游的 `content.md`、`style.css`、隐私政策等文件保留未动
- ⚠️ **合并后必须做的事**：把 twocats 合进 main 并删除分支前，先到 Settings → Pages 把发布源切到 `main /docs`，否则站点 404

## 4. 构建与测试速查

```sh
# 测试（在 LocalPackage/ 下，CI 同款方式）
cd LocalPackage && xcodebuild test -scheme LocalPackage-Package \
  -destination "platform=macOS,arch=arm64" -skipPackagePluginValidation

# Release 构建 + 本地包（仓库根目录；无签名证书时用 ad-hoc）
xcodebuild -project RunCatNeo.xcodeproj -scheme RunCatNeo \
  -configuration Release -derivedDataPath build/DerivedData \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
# 产物：build/DerivedData/Build/Products/Release/RunCatNeo2cats.app
```

坑：管道（如 `| tail`）会掩盖 xcodebuild 退出码，请检查日志里的 `** BUILD SUCCEEDED **` 或加 `set -o pipefail`。更多细节见 `AGENTS.md`。

## 5. 本机（Mac）当前状态

- `/Applications/RunCatNeo2cats.app`：本 fork 安装版（`PRODUCT_NAME=RunCatNeo2cats`，bundle id `com.changediff.twocats.RunCatNeo`，显示名仍为 RunCat Neo，ad-hoc 签名，含全部功能）
- 旧的 `/Applications/RunCatNeo2.app`、`/Applications/RunCatNeo.app` 副本均已删除，本机只保留 `RunCatNeo2cats.app` 一个
- 沙盒容器：`~/Library/Containers/com.changediff.twocats.RunCatNeo/`——偏好与自定义跑者都在容器内
  - 自定义跑者已播种：`…/Data/Library/Application Support/RunCatNeo/`（`CUSTOM_RUNNERS.json` + Fishman + Flash Cat + Golden Cat + Metal Cluster Cat，帧图为 `<id>/frame-<n>.png`）
  - 新机器/新容器需要重新播种，或通过 app 的设置界面导入
- 可清理项：home 下 `~/Library/Application Support/RunCatNeo/`（沙盒 app 读不到，无效残留）；孤儿容器 `~/Library/Containers/com.kyome.Neo.RunCat2/`（元数据受系统保护删不干净，无害）
- `defaults read` 读不到沙盒 app 的偏好（TCC 限制），检查偏好请在 app UI 里看

## 6. 切换到新目录维护的步骤

```sh
git clone git@github.com:changediff/RunCatNeo2cats.git
cd RunCatNeo2cats && git checkout twocats
# 之后按第 4 节构建/测试；build/ 目录不会被 git 跟踪
```

注意：`build/`（构建产物）不入库；`runners/`（跑者原始 PNG 素材）**已入库**。素材来源：fishman/flash-cat 来自更早的手动提取；golden-cat（金猫）/metal-cluster-cat（金属团猫）提取自初代 RunCat（App Store 版 `com.kyome.RunCat` v12.8，闭源）bundle 内 `LocalPackage_UserInterface.bundle` 的 Assets.car——该 car 里每个跑者是一张 APNG（Data asset），用 ImageIO 拆帧即可，帧图版权仍属 Kyome22，仅限个人使用勿分发。旧目录 `/Users/changediff/ZCodeProject/RunCatNeo2/` 与 `/Users/changediff/playground/RunCatNeo` 均可废弃。

## 7. 后续待办

- [ ] 决定 `twocats` → `main` 的合并时机；合并后切换 Pages 发布源（见第 3 节）
- [ ] 若未来要分发：按 App Store 要求重审签名/公证，内购商品 ID（`DonationProduct.swift`、`RunCatNeo.storekit`）需重新规划
- [ ] 上游有更新时，添加 remote `upstream → runcat-dev/RunCatNeo` 择期 rebase/merge

## 8. 仓库内文档索引

- `AGENTS.md` — agent/开发者工作约定（构建、测试、自定义跑者机制），**CLAUDE.md 只是它的指针**
- `ARCHITECTURE.md` — LUCA 架构权威规则（DataSource ← Model ← UserInterface）
- `CODING_STYLE.md` / `CONTRIBUTING.md` — 行级风格与贡献流程
- `docs/index.html` — GitHub Pages 介绍页
