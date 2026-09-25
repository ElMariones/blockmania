# System requirements (Steamworks > Store page > System requirements)

Based on Godot 4.7's requirements for exported games with the Forward+ renderer (Direct3D 12 on Windows,
Metal on Apple Silicon, Vulkan on Intel Macs through MoltenVK and on Linux). BLOCKMANIA is a 2D game, and the swirl background and the CRT filter are its only
heavy effects (both can be lowered in Options). The measured install size is 135 MB (Windows), 196 MB (macOS, universal) and 101 MB
(Linux); "300 MB" leaves room for updates. **Provisional**: not yet measured on low-end hardware. Recheck them on the
weakest machine you can find before release.

Steamworks has one form per OS, with Minimum and Recommended columns. Fields not listed here stay empty.

## Windows

| Field | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 64-bit | Windows 10 / 11 64-bit |
| Processor | x86-64 CPU with SSE4.2, 2 cores (Intel Core i3 / AMD Ryzen 3) | 4 cores (Intel Core i5 / AMD Ryzen 5) |
| Memory | 2 GB RAM | 4 GB RAM |
| Graphics | Direct3D 12 (feature level 12_0) or Vulkan 1.0 GPU, e.g. Intel HD Graphics 510 / AMD Radeon R5 | NVIDIA GeForce GTX 1050 / AMD Radeon RX 460 |
| DirectX | Version 12 | Version 12 |
| Storage | 300 MB available space | 300 MB available space |
| Additional notes | Mouse required; keyboard supported. | |

## macOS

| Field | Minimum | Recommended |
|---|---|---|
| OS | macOS 11 Big Sur (Apple Silicon) or macOS 10.15 Catalina (Intel) | macOS 13 Ventura or later |
| Processor | Apple M1, or Intel Core i5 | Apple M1 or later |
| Memory | 2 GB RAM | 4 GB RAM |
| Graphics | Metal-capable GPU (Apple Silicon, or Intel Iris / AMD Radeon on Intel Macs) | Apple Silicon GPU |
| Storage | 300 MB available space | 300 MB available space |
| Additional notes | Mouse or trackpad required. Universal app (Apple Silicon and Intel). | |

## Linux + SteamOS

| Field | Minimum | Recommended |
|---|---|---|
| OS | 64-bit Linux, Ubuntu 20.04 or equivalent, or SteamOS | Ubuntu 22.04 or later / SteamOS 3 |
| Processor | x86-64 CPU with SSE4.2, 2 cores | 4 cores |
| Memory | 2 GB RAM | 4 GB RAM |
| Graphics | GPU with a Vulkan 1.0 driver (Mesa 22+ or current NVIDIA driver) | Vulkan 1.2, e.g. GeForce GTX 1050 / Radeon RX 460 |
| Storage | 300 MB available space | 300 MB available space |
| Additional notes | Mouse required; keyboard supported. | |

Do not claim Steam Deck compatibility or controller support: the game is mouse-first and has no full controller support yet.

## Translations (paste in the Spanish and Chinese store pages)

Steamworks keeps system requirements per language. Hardware names and version numbers stay the same; only these words change.

| English | Español | 简体中文 |
|---|---|---|
| Windows 10 64-bit | Windows 10 de 64 bits | Windows 10 64 位 |
| x86-64 CPU with SSE4.2, 2 cores | CPU x86-64 con SSE4.2, 2 núcleos | 支持 SSE4.2 的 x86-64 双核处理器 |
| 4 cores | 4 núcleos | 四核处理器 |
| 2 GB RAM / 4 GB RAM | 2 GB de RAM / 4 GB de RAM | 2 GB 内存 / 4 GB 内存 |
| Direct3D 12 (feature level 12_0) or Vulkan 1.0 GPU | GPU compatible con Direct3D 12 (nivel 12_0) o Vulkan 1.0 | 支持 Direct3D 12（功能级别 12_0）或 Vulkan 1.0 的显卡 |
| Metal-capable GPU | GPU compatible con Metal | 支持 Metal 的显卡 |
| GPU with a Vulkan 1.0 driver | GPU con controlador Vulkan 1.0 | 支持 Vulkan 1.0 驱动的显卡 |
| 300 MB available space | 300 MB de espacio disponible | 300 MB 可用空间 |
| Mouse required; keyboard supported. | Requiere ratón; compatible con teclado. | 需要鼠标；支持键盘操作。 |
| Mouse or trackpad required. Universal app (Apple Silicon and Intel). | Requiere ratón o trackpad. App universal (Apple Silicon e Intel). | 需要鼠标或触控板。通用应用（支持 Apple 芯片和 Intel）。 |
