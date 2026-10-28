# KohakUnlock 12FA 移植进度 — 2026-10-28 深夜档

## 已达成（本机卡 10de:1e07/10de:12fa，VBIOS 90.02.30.40.85，22G）

1. **PROM 捕获 ✓**：12fa 诊断变体（tu102_diag.c 新增 KOH_DIAG_NVIDIA_1E07_12FA 分支 + Makefile 变体 nvidia-1e07-12fa）→ 独立 initramfs → grub-reboot 两次重启 → /run 快照 1MiB 完整（prom.bin sha256 68e97782...）
2. **FWSEC 提取 ✓**：native-fwsec.bin 39968B（sha256 794edf21...）——第三种固件变体，但 descriptor 布局与 historical(Loadtek) 族同构（15 words 仅 [14] 0x6618 vs 0x6638 差异）
3. **12FA profile ✓**：profiles/nvidia-tu102-300a-12fa-22g.json（check_assets ALL_VALID 五件闭环）
4. **12FA 协议分支 ✓**：tu102_profile.h + tests/test_core_port.c 各加 #elif 分支
5. **决定性：协议 loader 模拟 happy path 双 PASS**（build/test_core_12fa 合成+真实固件都过 257 行 TX_OK/unlocked/quiescent）——本卡固件在事务模型中完整走通解锁序列

## 当前卡点（非缺陷，参数化待办）

- test:341 负例失败：12FA 借用 12A4 selector 对（0x20500060/5 假设值）与 historical 风格负例冲突——真实 selector 对**未采集**（需 selector capture 重启，PR4 initramfs-selector-capture.example 流程）

## 剩余步骤（续作战清单）

1. selector capture 重启（读采样 5 次）→ 回填 profile SS0/SS1 + test 负例参数化 → test_core_12fa 全绿
2. make module ENABLE_EXPERIMENT=1 DIAG_PROFILE/EXEC_PROFILE=nvidia-1e07-12fa
3. trial initramfs + GRUB + 重启执行（stage=11/unlocked=1/safe 判据）
4. 基准复测对比 BASELINE-locked.md（FP16→FP32 55.60 → 预期 ~95-110）

## 资产位置

- 全部：/mnt/s790/kohak_unlock/local/（prom.bin/capture/assets 五件/rom-analysis.json/profile-assessment.json）
- 基线：BASELINE-locked.md；profile：profiles/nvidia-tu102-300a-12fa-22g.json
- 改动文件（仓库工作树未提交）：kernel/tu102_profile.h、kernel/tu102_diag.c、kernel/Makefile、tests/test_core_port.c

## 追加（08:50）：selector 采集已就绪

诊断 initramfs 已重建为 selectors_only=1 模式（五次采样 0x409664/0x40966c → dmesg dev_info），同一 GRUB 条目复用。B15 训练完成后：grub-reboot → 重启 → journalctl 取 'tu102_diag selectors' 五组 ss0/ss1 → 回填 profile SS0/SS1 与 test 负例参数化 → test_core_12fa 全绿 → ENABLE_EXPERIMENT trial。

## 追加（09:45）：trial 执行就绪（最终步）

- selector 实采完成：ss0=0x6001/ss1=0x4（五采样一致）→ profile/test 回填 → test_core_12fa 合成+真实固件 462×2 全 PASS
- tu102_execute.ko 12FA trial 编译（身份烙印 69:00.0/12fa-trial/observed-pair 验证）
- trial initramfs：模块+五件资产（tu102-lab）+ 无头 gate（失败继续正常启动变体）
- GRUB 条目 'Kohak TU102 12fa one-shot trial (execute)'（双 cmdline 开关）
- 待用户最终确认重启执行；成功判据 /run/kohak-tu102-trial/status=UNLOCKED + stage=11/unlocked=1 + 基准 55.6→~95-110
