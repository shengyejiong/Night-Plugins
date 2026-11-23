# 音乐文件放置目录

把后续准备的 MP3 放在本目录，例如 `music_01.mp3`、`music_02.mp3`。

当前已有 `rainloveDJ.mp3`，时长约 197.2 秒，采样率 44.1 kHz，主要音频帧为 128 kbps；已加入曲库。

推荐格式：MP3、44.1 kHz 采样率、128～192 kbps 恒定比特率、双声道。

该目录部署到服务器后，对应 `left4dead2/sound/night_laststand/`。音乐文件还需要同步到 FastDL（资源快速下载服务）的相同相对目录。

在 `addons/sourcemod/configs/l4d2_last_survivor_music.cfg` 中填写歌曲列表。不要将此 README 添加到下载表；插件只加载列表中配置的 MP3/WAV。

曲目中的 `duration` 填实际时长（秒），供自然结束前淡出使用。替换歌曲内容后要重新核对时长。
