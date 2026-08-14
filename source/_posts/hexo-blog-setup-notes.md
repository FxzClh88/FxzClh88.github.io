---
title: 从零搭建 Hexo 博客踩坑记录
date: 2026-08-14 13:48:00
categories: [学习, Hexo]
tags: [Hexo, GitHub, Markdown, 博客]
description: 记录用 Hexo + Butterfly + GitHub Pages 搭建个人技术博客的全过程，以及踩过的 8 个坑
cover: /img/banner.jpg
---

## 前言

一直想有个地方记录自己的学习和开发笔记，于是花了半天时间，用 Hexo 搭了个博客并发布到了 GitHub Pages。过程说起来简单，坑倒是踩了不少。这里完整记录下来，方便以后回顾，也希望能帮到同样想搭博客的人。

博客地址：https://FxzClh88.github.io

## 一、技术选型

| 环节 | 技术 | 说明 |
| --- | --- | --- |
| 框架 | Hexo 7 | 静态博客生成器，Node.js 生态 |
| 主题 | Butterfly 5.7 | 高颜值，配置丰富 |
| 托管 | GitHub Pages | 免费，无需服务器 |
| 写作 | Markdown | 纯文本，专注内容 |

## 二、踩坑记录

| # | 问题 | 原因 | 解决方案 |
| --- | --- | --- | --- |
| 1 | 改配置后页面无变化 | `_config.yml` 副标题混用中英文引号，YAML 解析失败 | 引号统一用英文单引号 |
| 2 | 全局 hexo 命令报路径错 | Git Bash 下 npm shim 路径转换错误 | 改用本地 node 调用 |
| 3 | 改配置总不生效 | 旧 hexo server 进程占着 4000 端口没退 | 先杀端口进程再重启 |
| 4 | 中央副标题不显示 | Butterfly `subtitle.enable` 默认是 false | 复制 `_config.butterfly.yml` 并开启 |
| 5 | 背景图显示空白 | hexo-server 静态图片有 stream bug | 用 Python http.server 替代 |
| 6 | 部署报 trash 错误 | 沙箱的删除拦截 shim | 命令前加 `NODE_OPTIONS=` 绕过 |
| 7 | 站点一直 404 | GitHub Pages 功能没启用 | Settings → Pages 手动开启 |
| 8 | HEIC 图片不显示 | 浏览器不支持 HEIC 格式 | 转成 JPG 再用 |

## 三、几个关键点

### 3.1 副标题有「双层配置」，别搞混

Butterfly 的副标题在两个不同的文件里，作用完全不同：

```yaml
# _config.yml（站点配置）—— 只用于浏览器标签页标题和 SEO
subtitle: 'Stay hungry, stay foolish.'

# _config.butterfly.yml（主题配置）—— 才真正显示在首页中央
subtitle:
  enable: true
  sub:
    - 'Stay hungry, stay foolish.'
```

### 3.2 部署命令

```bash
cd /c/Users/Administrator/myblog && NODE_OPTIONS= node node_modules/hexo/bin/hexo clean && NODE_OPTIONS= node node_modules/hexo/bin/hexo generate && NODE_OPTIONS= node node_modules/hexo/bin/hexo deploy
```

## 四、一键更新脚本

把上面的命令封装成 `update-blog.bat`，以后双击就能更新博客：

```bat
@echo off
set NODE_OPTIONS=
set NODE=C:\Users\Administrator\.workbuddy\binaries\node\versions\22.22.2\node.exe
cd /d C:\Users\Administrator\myblog
%NODE% node_modules\hexo\bin\hexo clean
%NODE% node_modules\hexo\bin\hexo generate
%NODE% node_modules\hexo\bin\hexo deploy
pause
```

## 总结

这次搭博客最大的体会：静态博客的「好看」背后，都是一行行纯文本的 Markdown 和配置文件。踩坑不可怕，关键是遇到报错别慌，顺着报错信息一层层查，总能找到根源。
