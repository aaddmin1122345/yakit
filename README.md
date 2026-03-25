# My Yakit（个人 Linux 自用分支）

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

<p align="center">
  <img src="imgs/linux-titlebar.png" width="500" alt="Yakit Linux Native Titlebar Preview">
</p>

---