# 应用图标设置指南

## 📱 Android 图标设置

### 图标文件放置位置
将你的JPG图标文件转换为PNG格式后，放置到以下目录：

```
android/app/src/main/res/
├── mipmap-mdpi/ic_launcher.png     (48x48 px)
├── mipmap-hdpi/ic_launcher.png     (72x72 px)
├── mipmap-xhdpi/ic_launcher.png    (96x96 px)
├── mipmap-xxhdpi/ic_launcher.png   (144x144 px)
└── mipmap-xxxhdpi/ic_launcher.png  (192x192 px)
```

### 图标尺寸要求
- **mdpi**: 48x48 像素
- **hdpi**: 72x72 像素
- **xhdpi**: 96x96 像素
- **xxhdpi**: 144x144 像素
- **xxxhdpi**: 192x192 像素

## 🖥️ Windows 图标设置

### 图标文件放置位置
将你的JPG图标转换为ICO格式后，替换以下文件：

```
windows/runner/resources/app_icon.ico
```

### 图标尺寸要求
ICO文件应包含以下尺寸：
- 16x16 像素
- 32x32 像素
- 48x48 像素
- 64x64 像素
- 128x128 像素
- 256x256 像素

## 🔧 图标转换工具推荐

### JPG/PNG 转换为多尺寸 PNG
1. **在线工具**: 
   - https://icon.kitchen/
   - https://appicon.co/
   - https://easyappicon.com/

2. **本地工具**:
   - Photoshop
   - GIMP (免费)
   - Paint.NET (Windows)

### JPG/PNG 转换为 ICO
1. **在线工具**:
   - https://convertio.co/jpg-ico/
   - https://icoconvert.com/
   - https://favicon.io/favicon-converter/

2. **本地工具**:
   - IcoFX
   - GIMP (免费)

## 📋 设置步骤

1. **准备原始图标**
   - 使用JPG、PNG或其他格式的高质量图标
   - 建议至少512x512像素的正方形图片

2. **生成Android图标**
   - 使用在线工具生成不同尺寸的PNG文件
   - 将生成的PNG文件重命名为`ic_launcher.png`
   - 分别放置到对应的mipmap目录中

3. **生成Windows图标**
   - 使用工具将图片转换为ICO格式
   - 确保ICO文件包含多种尺寸
   - 重命名为`app_icon.ico`并替换原文件

4. **重新构建应用**
   ```bash
   # 清理构建缓存
   flutter clean
   
   # 重新构建
   flutter build apk --release    # Android
   flutter build windows --release # Windows
   ```

## ⚠️ 注意事项

- **文件格式**: Android使用PNG，Windows使用ICO
- **文件名**: 必须保持原有的文件名不变
- **权限**: 确保有写入权限到对应目录
- **缓存**: 修改图标后需要清理构建缓存并重新构建

## 🎨 图标设计建议

- 使用简洁、易识别的设计
- 确保在小尺寸下仍然清晰可见
- 避免使用过多细节
- 考虑不同背景下的对比度
- 遵循各平台的设计规范

---

修改完图标文件后，请重新运行以下命令来应用更改：

```bash
flutter clean
flutter pub get
flutter run
``` 