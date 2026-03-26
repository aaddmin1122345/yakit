# Yakit Linux 自用分支

<<<<<<< HEAD
<<<<<<< HEAD
<p align="center">
  <a href="https://yaklang.io/"><img src="imgs/head.jpg" style="width: 400px"/></a>
 <h2 align="center">Yakit-交互式应用安全测试平台</h2>
<p align="center">
<img src="https://img.shields.io/github/issues-pr/yaklang/yakit">
<a href="https://github.com/yaklang/yakit/releases"><img src="https://img.shields.io/github/downloads/yaklang/yakit/total">
<a href="https://github.com/yaklang/yakkit/graphs/contributors"><img src="https://img.shields.io/github/contributors-anon/yaklang/yakit">
<a href="https://github.com/yaklang/yakit/releases/"><img src="https://img.shields.io/github/release/yaklang/yakit">
<a href="https://github.com/yaklang/yakit/issues"><img src="https://img.shields.io/github/issues-raw/yaklang/yakit">
<a href="https://github.com/yaklang/yakit/discussions"><img src="https://img.shields.io/github/stars/yaklang/yakit">
<a href="https://github.com/yaklang/yakit/blob/main/LICENSE.md"><img src="https://img.shields.io/github/license/yaklang/yakit">
</p>

<p align="center">
  <a href="https://yaklang.oss-cn-beijing.aliyuncs.com/yakit-technical-white-paper.pdf">查看白皮书</a> •
  <a href="https://yaklang.io/products/intro/">官方文档</a> •
  <a href="https://github.com/yaklang/yakit/issues">问题反馈</a> •
  <a href="https://yaklang.io/">进入官网</a> •
  <a href="#社区 ">加入社区</a> •
  <a href="#项目架构">项目架构</a>
</p>

<p align="center">
 :book:语言选择： <a href="https://github.com/yaklang/yakit/blob/master/README-EN.md">English</a> •
  <a href="https://github.com/yaklang/yakit/blob/main/README.md">中文</a>
</p>
=======
这是一个基于官方 **Yakit** 的 **个人 Linux 自用分支**，用于解决 Linux 桌面环境下的实际使用体验问题。

除下述差异外，其余 **功能、行为、代码结构** 均与官方仓库保持一致：

* 官方仓库：
  [https://github.com/yaklang/yakit](https://github.com/yaklang/yakit)
>>>>>>> 3b652268d (使用bwrap容器限制运行路径)

---

## ✨ 与官方版本的差异

### 1. 通过环境变量指定项目目录

支持通过环境变量自定义 Yakit 的项目数据目录，避免数据默认散落在 `$HOME` 下。

```bash
export YAKIT_HOME="你的自定义目录"
```

---

### 2. 使用 Linux 原生窗口标题栏

* 移除官方使用的 **Windows 风格自绘标题栏**
* 更符合 KDE / GNOME / Wayland / X11 的使用习惯

---

## 🖼️ 标题栏效果预览
=======
这是一个基于官方 [Yakit](https://github.com/yaklang/yakit) 维护的个人 Linux 分支，目标很直接:

- 保持与官方仓库主体功能尽量一致
- 修正 Linux 桌面环境下的实际使用体验
- 让程序的数据目录和窗口行为更符合 Linux 用户习惯
>>>>>>> ea7147cfb (codex优化了一些细节)

<p align="center">
  <img src="imgs/linux-titlebar.png" width="560" alt="Yakit Linux Native Titlebar Preview">
</p>

## 这个分支改了什么

相对官方版本，这个分支目前主要保留两类调整:

### 1. 使用 Linux 原生窗口标题栏

- 移除了 Windows 风格的自绘标题栏
- 改为更适配 KDE、GNOME、Wayland、X11 的原生窗口装饰
- 在 Linux 桌面环境下观感和交互更自然

### 2. 调整数据目录写入方式

官方yakit会把数据硬编码写入 `~/yakit-projects` ，我重定向到:

```bash
~/.local/share/yakit-projects
```

这样做的目的:

- 不在用户 Home 根目录额外堆文件
- 更符合 Linux 常见目录规范
- 强迫症

当前仓库里的启动脚本实现见 [yakit.sh](yakit.sh)。

## 与官方仓库的关系

- 官方仓库: [yaklang/yakit](https://github.com/yaklang/yakit)
- 这个仓库默认以“尽量少改动”为原则维护
- 除 Linux 体验相关修改外，其余功能、结构、依赖和构建方式尽量跟随官方

如果你需要了解 Yakit 的完整产品能力、文档和生态，建议直接参考官方资料:

- 官方网站: <https://yaklang.io/>
- 官方文档: <https://yaklang.io/products/intro/>
- 官方仓库: <https://github.com/yaklang/yakit>

## 适合谁用

这个分支更适合下面这类用户:

- 日常使用 Linux 桌面环境
- 不喜欢应用把数据直接写进 Home 根目录
- 希望窗口标题栏、边框、拖拽行为尽量遵循系统原生表现

如果你主要在 Windows 或 macOS 上使用，通常直接使用官方版本更合适。

## 运行方式

如果你已经有打包好的 Linux 程序，可以直接通过仓库根目录的脚本启动:

```bash
./yakit.sh
```

脚本当前做了这些事:

- 创建临时 `HOME`
- 将 `yakit-projects` 映射到 `~/.local/share/yakit-projects`
- 追加 Wayland / GPU 相关启动参数
- 最终启动 `./release/linux-unpacked/yakit`

## 开发说明

仓库本体仍然是 Electron 工程，常用开发命令如下:

```bash
yarn
yarn install-render
yarn dev
```

常用脚本:

```bash
yarn start-electron
yarn build-render
yarn pack-linux
```

更多命令可以查看 [package.json](package.json)。

## 注意事项

- 这是个人自用分支，不保证和官方每个提交完全同步
- 如果官方后续已经合并了同类 Linux 适配，这个分支的存在意义会变小
- 使用 Yakit 请确保目标、环境与用途合法合规

## License

许可证与上游仓库保持一致，详见 [LICENSE.md](LICENSE.md)。
