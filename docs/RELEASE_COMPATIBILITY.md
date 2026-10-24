# 当前客户端配套

游戏客户端 0.1.5，独立登录器 0.1.6，Docker 服务端 0.1.4，资源集合 assets-ca77a19cb580。协议依赖见 compatibility.json；关键实现与资源索引散列见 contracts.lock.json。

当前文档和打包组织不修改 Delphi 游戏源码或两个 Windows EXE，也不改变协议、编码、物品实例、地图、技能或保存恢复。源码中的内部兼容标识保留。客户端程序和资源分别下载，Check-Client.cmd 核对真实散列。

源码契约、隐私、资源及打包离线检查不等于实机验收。完整服务端/PC/GM/bot 组合保持 pending_runtime_validation。无存档迁移；安装变更前正常退出并备份程序和本机配置，回退时恢复匹配程序与资源集合。
