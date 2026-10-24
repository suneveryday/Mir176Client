# Mir176Client 维护规则

- 本仓库维护 Windows PC 源码、编译/协议适配、资源索引及发行包。服务端与独立登录器源码由 Mir176 维护。
- 源码入口 client/current-source/。资源二进制只在 Release 中交付，清单记录每个文件的真实散列。
- 保留原有第三方许可与署名；恢复资源不认证为官方原始素材，不因本仓库保存而获得新许可。
- 修改前阅读 compatibility.json、contracts.lock.json 与 docs/RELEASE_COMPATIBILITY.md。协议、编码、物品、技能、地图或恢复变化须审查服务端、GM 与 bot；先提交子项目再更新主项目组合锁。
- 提交和推送前运行 tools/check-privacy.py 及 --history、tools/check-contract.py。CI 检查保持启用，提交使用中性维护身份。
- 凭据、现用连接、账号、角色、日志、玩家库、工具链或本机路径不得进入 Git 或发行包。
- 代码、Git 和离线检查不授予真实游戏、Docker 部署、GM 修改或 bot 运行权限。完整运行组合验收前保持 pending_runtime_validation。
