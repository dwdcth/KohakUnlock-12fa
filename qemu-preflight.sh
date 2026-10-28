#!/bin/sh
# QEMU 预检：initramfs 层排障免物理重启（gate/哈希/挂载/参数——不含真实 GPU 事务）
# 用法: ./qemu-preflight.sh [kohak-diag|kohak-trial]
# 模块将在设备缺失处失败（预期）；看 gate 日志判断各环节是否通过。
MODE="${1:-kohak-trial}"
KVER=$(uname -r)
case "$MODE" in
  kohak-diag)  INITRD=/boot/kohak-diag-$KVER.img;  CMD="kohak.diag=read-only-1e07-12fa" ;;
  kohak-trial) INITRD=/boot/kohak-trial-$KVER.img; CMD="kohak.trial=nvidia-1e07-12fa-once tu102_execute.execute=1" ;;
  *) echo "usage: $0 [kohak-diag|kohak-trial]"; exit 2 ;;
esac
[ -f "$INITRD" ] || { echo "initrd 不存在: $INITRD"; exit 2; }
echo "== QEMU preflight: $MODE ($INITRD) — Ctrl-A x 退出 =="
qemu-system-x86_64 -m 512 -nographic -no-reboot \
  -kernel /boot/vmlinuz-$KVER -initrd "$INITRD" \
  -append "console=ttyS0 $CMD" 2>&1 | tee /tmp/qemu-preflight-last.log
echo "== 日志: /tmp/qemu-preflight-last.log（grep REFUSED/mount/failed/sha 定位环节）=="
