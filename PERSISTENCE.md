# 解锁固化实现经验（每 boot 自动重解锁）

> 端到端验证：温启动 boot 自动解锁，实测 87.59 TFLOPS（+57%），启动耗时增加 ~2s。
> commit 链：gate v2（watchdog+防循环）→ 坑9 修复（温启 selector 双对）→ 本文档。

## 一、为什么"固化"不是开机会自动有的

解锁态是 **易失寄存器态**（volatile selector/权限寄存器），任何 reset（重启/断电）清零。
持久化唯一路径 = **每次 boot 早期（NVIDIA 驱动绑定前）自动重做一次解锁事务**——
这正是上游刻意不做的（"NOT made persistent / Never loop automatic retries"），
所以固化 = 自动化 + 安全网，两者缺一不可。

## 二、固化的三个部件

1. **GRUB_DEFAULT 指向解锁条目**（不是 grub-reboot 一次性）：
   `GRUB_DEFAULT="Kohak TU102 12fa one-shot trial (execute)"` → update-grub。
   stock 条目保留第二位，随时可手选回退。
2. **gate v2**（init-top/kohak-trial）：每次 boot 自动跑，成功/失败都继续正常启动。
3. **模块双对 selector 接受**（坑9）：冷启动初值 (0x6001,4) / 温启动 (0,0)，
   精确匹配两者之一即放行事务——这是固化成败的关键修复。

## 三、两道安全网（对齐上游"禁自动循环重试"）

1. **softdog watchdog 60s**：gate 开喂狗后台循环（每 10s `echo V > /dev/watchdog`），
   事务完成 kill 喂狗。若 gate/模块挂死→无人喂→60s 整机重启——无头机不会永久卡死。
2. **根分区挂死标志防循环**：事务前 `/kohak.bootflag=1`（挂根分区写+sync），
   完成（成功或安全拒绝）写回 0。若 boot 被 watchdog/断电打断→标志留 1
   →**下次 boot gate 读到 1 直接跳过解锁**正常启动——绝不在异常态上自动重试。
   人工恢复：`sudo rm /kohak.bootflag && sudo reboot`。

## 四、boot 类型敏感点（实测教训）

- selector 初值：冷启动（断电上电）与温启动（reboot）**不同**——固化必须支持双对，
  否则温启动 boot 全部 guard 拒绝（首次固化验证就栽在这，见 PORTING 坑9）
- 上游提醒过 "A warm-reboot pre-driver snapshot is not automatically a power-on-cold
  snapshot"——任何 pre-driver 采集/校验都要区分冷/温口径

## 五、固化后的验收方法（每次怀疑时）

```
sudo cat /run/kohak-tu102-trial/status        # 期望 result=UNLOCKED
dmesg | grep 'unlocked=1'                     # 期望 stage=11 unlocked=1 quiescent=1
LD_LIBRARY_PATH=$CU13/lib gemmsustained 0000:69:00.0 3 2048 fp16   # 期望 ~87 TFLOPS
cat /kohak.bootflag                           # 期望 0
```

## 六、长期风险（如实）

每次 boot 一次固件事务的长期稳定性**上游未认证、我们只有 N≈3 次成功样本**；
watchdog+防循环保的是"系统能起来"，不保 GPU 寿命。观察指标：若某次 boot 后
status=check-logs 频率上升，考虑回退固化（GRUB_DEFAULT 改回原条目即可）。
