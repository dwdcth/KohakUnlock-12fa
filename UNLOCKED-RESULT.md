# ✅ KohakUnlock 12FA 解锁成功 — 2026-10-28 10:5x

## 实机证据（/run/kohak-tu102-trial/events.log + dmesg）
- core=0 stage=11 mutated=1 unlocked=1 quiescent=1（全部判据）
- result=0 handoff_safe=1; resources released（安全交接，NVIDIA 正常绑定）

## 基准对比（compute_sustained 2048³，correctness 全 PASS）
| 模式 | 锁定 | 解锁后 | 变化 |
|---|---|---|---|
| FP16→FP32 | 55.60 | **87.25** | **+57%** |
| FP16→FP16（对照） | 95.68 | 94.73 | 持平 |
| INT8（对照） | 42.14 | 41.60 | 持平 |

## 排障史（8 次重启，全部零硬件损伤）
1-2 组件打包（etc 不入镜像/哈希路径格式）→ 3 哈希失同步 → 4 pre_udev+vfat journal 模块硬要求 → 5 诊断打印定位 → 6 vfat.ko 缺 → 7 descriptor 转录错 0x6618→0x6628（guard 硬件实测纠错）→ **8 成功**

## 重要提醒
- **解锁态易失**：重启即清零（本次活到下次重启）
- 持久化未做（作者明示 NOT persistent；每 boot 重做固件事务的长期稳定性未验证）
- 需再次解锁：走本仓 trial initramfs + grub-reboot 流程（events.img 每次需换新——per-image marker 防重试）
