# Voice Input

macOS 语音输入工具 - 按住快捷键说话，松开后自动识别并复制到剪贴板。

## 功能

- 支持中/英/日语混合语音识别
- 本地 Whisper 模型（默认）或 OpenAI API
- 全局快捷键监听（Right Option）
- 自动复制到剪贴板

## 安装

### 1. 系统依赖

```bash
brew install portaudio ffmpeg
```

### 2. 克隆项目

```bash
git clone https://github.com/yourusername/voice-input.git ~/bin/voice-input
cd ~/bin/voice-input
```

### 3. 创建虚拟环境并安装依赖

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4. 添加 alias（可选）

```bash
echo 'alias voice="~/bin/voice-input/start.sh"' >> ~/.zshrc
source ~/.zshrc
```

## 使用

```bash
voice          # 本地模型（默认）
voice --api    # 使用 OpenAI API（需设置 OPENAI_API_KEY）
```

- 按住 **Right Option** 说话
- 松开后自动识别并复制到剪贴板
- 按 **ESC** 退出

## 开机自启动

复制 LaunchAgent 配置：

```bash
cp com.user.voice-input.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.voice-input.plist
```

## macOS 权限

需要授予以下权限：

1. **麦克风权限**：系统设置 > 隐私与安全性 > 麦克风
2. **辅助功能权限**：系统设置 > 隐私与安全性 > 辅助功能（添加你的终端应用）

## 配置

编辑 `voice_input.py` 顶部的配置：

```python
HOTKEY = keyboard.Key.alt_r  # 快捷键
BACKEND = "local"            # "local" 或 "api"
LOCAL_MODEL_SIZE = "small"   # tiny, base, small, medium, large-v3
```

## License

MIT
