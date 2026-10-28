# KohakUnlock 解锁前基线（锁定态）— 2026-10-28 08:05
# 机器：2080Ti 22G（10de:1e07/12fa，VBIOS 90.02.30.40.85，驱动 580.142）
# 工具：PR4 compute_sustained.cu（cuBLAS 13.1.01，n=2048，CUDA event 计时，correctness=PASS）
# BDF=0000:69:00.0  kernel=6.18.18.c1126-trim

| 模式 | TFLOPS |
|---|---|
| **FP16→FP32（解锁目标）** | **55.598** |
| FP16→FP16（对照，预期不变） | 95.678 |
| INT8→INT32（对照，预期不变） | 42.143 TOPs |

# 预期解锁后：FP16→FP32 跳至 ~95-110（贴近 FP16→FP16 档=半速限制解除特征）；对照组持平。
# 复测命令：LD_LIBRARY_PATH=$CU13/lib /mnt/s790/b15_work/gemmsustained 0000:69:00.0 5 2048 fp16
