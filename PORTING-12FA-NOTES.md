# KohakUnlock 12FA 移植全记录（第三张卡实机解锁成功版）

> 2026-10-28 实机验证：`core=0 stage=11 mutated=1 unlocked=1 quiescent=1`，
> FP16→FP32 55.60→**87.25 TFLOPS（+57%）**，对照组持平。本 fork（tag
> `linux-turing-12fa-v1`）是 Linux/Turing 路径最全实现——**上游 main 已删除
> Linux 路径转向 Windows/Ada**（PR#10 为 EFI auto-attempt），勿向上合并。

## 一、目标卡与两个先例的差异定位（移植第一步）

| 维度 | 主 profile（Leadtek） | PR4（ChenYFan 300A） | **本卡（12FA）** |
|---|---|---|---|
| device | 10de:1e04 | 10de:1e07 | 10de:1e07 |
| subsystem | 107d:1e04 | 10de:12a4 | **10de:12fa** |
| VBIOS | 90.02.33.00.3F | 90.02.0B.00.0E | **90.02.30.40.85** |
| FWSEC bytes | 39968 | 39440 | 39968 |
| descriptor | …0x6638 | …0x6618 | **…0x6628** |
| selector 对 | （profile 有） | 0x20500060/5 | **0x6001/4（实测）** |

结论模式：**先跑 `tools/inventory.py` + `check_profile.py` 差异评估**——布局寄存器
（容量 0x100ce0/workspace 0x625f04/framebuffer 22GiB）全一致=“新 profile 移植”，
而非重新逆向。

## 二、移植改动面（本 fork 相对 pr/4 的 6 个文件）

1. `kernel/tu102_diag.c`：`KOH_DIAG_NVIDIA_1E07_12FA` 分支（PCI 三元组+BDF 0x69）
2. `kernel/tu102_identity.h`：12FA 分支（TX_TARGET 0000:69:00.0/SUBDEVICE 0x12fa）
3. `kernel/tu102_profile.h`：12FA 分支（FWSEC sha256/DESC_WORDS[14]=0x6628/SS0=0x6001/SS1=4）
4. `kernel/Makefile`：DIAG_PROFILE=nvidia-1e07-12fa、EXEC_PROFILE=nvidia-1e07-12fa-trial
   （trial 分支带 `-DKOH_UNLOCK_REVIEWED_PROFILE`=操作者审查声明）
5. `tests/test_core_port.c`：12FA observed_desc/pair 分支
6. `profiles/nvidia-tu102-300a-12fa-22g.json`：本卡 profile（check_assets ALL_VALID）

## 三、8 次重启排障坑全录（每条都是「安全拒绝」，GPU 零损伤）

| # | 现象 | 根因与修复 |
|---|---|---|
| 1 | sha256 文件不存在 | **mkinitramfs 不打包 confdir/etc/**——hook 里显式 `copy_file config` |
| 2 | 哈希不匹配 | sha256sum 输出内嵌**构建机绝对路径**——必须 printf 成镜像内路径 `/lib/modules/$ver/extra/xx.ko` |
| 3 | modprobe rc=1 静默 | trial 模块硬要求 **`pre_udev=1` 模块参数**（gate 断言） |
| 4 | 同上 | journal 硬要求 **vfat 文件系统**（MSDOS_SUPER_MAGIC 校验）：预生成 events.img 随镜像携带 + gate 里 loop 挂载到 `/run/kohak-tu102-trial` |
| 5 | 同上 | 静默 return 定位法：给嫌疑检查行加 `pr_err` 打印实值（一次重启定一位） |
| 6 | vfat mount 失败但提示丢失 | **initramfs 没打 fat/vfat.ko**（modules 列表）；mount 失败提示别吞——重定向到 gate.log 而非 console（无头丢失） |
| 7 | guard-mismatch 0x33edd0 | **十进制→十六进制转录错误**（26152=0x6628 非 0x6618）——guard 用硬件实测纠错，此类常量以 rom_analyze 原始输出复核 |
| 8 | — | 成功（全判据+安全交接） |

**哈希失同步暗坑**（出现两次）：改模块后必须“重算 hash→tee 文件→重建镜像”三步原子做；
管道里 `printf|sudo tee` 偶发未落——**分步执行并在重建前 `cut -c1-16` 双向核对**。

## 四、QEMU 预检（见 qemu-preflight.sh）——initramfs 层排障免物理重启

8 次重启里 1-6 全是 initramfs 组装/环境问题——**QEMU 可全部代跑**：
`qemu-system-x86_64 -kernel vmlinuz -initrd kohak-trial.img -append "kohak.trial=… tu102_execute.execute=1"` + serial stdio。模块会在设备缺失/透传前失败（预期），
但 gate 每一步（哈希/挂载/journal/参数）的通过与否直接可见。
**边界**：最终解锁必须物理重启（解锁态易失+需主机侧归属，透传 reset 反而清态）。

## 五、操作流程（下次解锁照抄）

1. 新 events.img（mkfs.fat + 空_events.log）→ trial-build/
2. `make module ENABLE_EXPERIMENT=1 EXEC_PROFILE=nvidia-1e07-12fa-trial DIAG_PROFILE=nvidia-1e07-12fa`
3. hash 三步原子同步（见坑表）→ `mkinitramfs`（env: KOH_EXEC_MODULE/KOH_FW_DIR/KOH_MODULE_HASH_FILE/KOH_EVENTS_IMG）
4. `grub-reboot "Kohak TU102 12fa one-shot trial (execute)"` → 手动 reboot
5. 回来查 `/run/kohak-tu102-trial/status`=UNLOCKED + events.log `stage=11 unlocked=1`
6. 基准复测：`LD_LIBRARY_PATH=$CU13/lib gemmsustained 0000:69:00.0 5 2048 fp16`（对照 pure-fp16/int8 应持平）

## 六、重要边界

- 解锁**易失**：重启清零；持久化未做（上游亦明示 NOT persistent，每次 boot 固件事务的长期稳定性无认证）
- 本卡 selector 对 (0x6001,4) 为五采样实测——**selector 是每卡个体值**，换卡必须重新 selectors_only 采集
- 上游 main 已删 Linux 路径：本 fork 即 Linux/Turing 的延续，重大改动前先打 tag

## 七、持久化固化（2026-10-28 追加，所有者指令）

GRUB_DEFAULT 已指向解锁条目——**每次 boot 自动重解锁**（gate v2）。双保险：
1. **watchdog**：softdog 60s，gate 挂死则整机重启（防卡死锁死无头机）
2. **失败标志防循环**：事务前在根分区写 `/kohak.bootflag=1`，完成（成功或安全拒绝）写回 0；
   若 boot 因挂死被 watchdog/断电打断，标志留 1 → **下次 boot 自动跳过解锁**直接正常启动
   （对齐上游"Never loop automatic retries"纪律）。恢复解锁：`sudo rm /kohak.bootflag` 再重启。
注意：每次 boot 一次固件事务的长期稳定性上游未认证（自担）；解锁耗时 ~2s 对启动无可感影响。
