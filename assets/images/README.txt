请将以下图片文件放入 assets/images/ 文件夹：

【背景图片】
qt-logo.png - 遥控器界面背景图片 (QTsteam Logo背景)

【格斗机器人轮播背景】
bg1.jpg - 格斗机器人背景1 (轮播第1张)
bg2.jpg - 格斗机器人背景2 (轮播第2张)

【HUB主界面需要的图片】
1. ble_debug.png - 通用BLE调试图片 (蓝牙调试相关)
2. car_series.png - 蓝牙小车系列图片 (各种小车)
3. robot_fighter.png - 蓝牙格斗机器人图片 (格斗机器人)
4. stacking_robot.png - 码垛搬运机器人图片 (工业机器人)

图片建议规格：
- 格式：PNG 或 JPG
- 大小：任意像素（代码会自动缩放）
- 建议比例：1:1 (正方形) 
- 建议分辨率：256x256 或 512x512
- 主界面图片会缩放到100x100
- 子页面图片会缩放到100x100

背景图片规格：
- 格式：PNG (支持透明度)
- 比例：任意比例 (会自动缩放填充)
- 建议分辨率：1920x1080 或更高
- 内容：QTsteam Logo或其他自定义背景

轮播背景图片规格：
- 格式：JPG (推荐，文件较小)
- 比例：16:9 或更宽的横屏比例
- 建议分辨率：1920x1080 或 2560x1440
- 内容：格斗机器人、科技感、红色主题背景
- 轮播：每6秒自动切换，支持2张图片循环
- 效果：平滑过渡动画 (800ms)
