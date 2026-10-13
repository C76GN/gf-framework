# Spring 数值对照探针

这是制作期数学原型，不是公开 Spring API、替代算法或性能门禁。生产 `GFSpringMath` 不由探针改写。探针还没有运行结果时，只能描述输入与方法，不能把预期误差、静态推导或自检库存当作实际观察。

## 输入与独立参照

`tools/benchmarks/spring_math_oracle.gd` 独立积分连续方程：

```text
omega = TAU * frequency_hz
x'' + 2*zeta*omega*x' + omega^2*x
    = omega^2*g + response*zeta*omega*g'
```

欠阻尼、临界阻尼和过阻尼分别使用三角函数、临界闭式与两个实根，不调用生产步进或第三方 Spring 实现。目标在每一段线性前进，`g'` 为该段固定速度；特解是 `g + (response - 2)*zeta*g'/omega`，特解速度是 `g'`。零目标速度退化为固定平衡点。

频率固定为 `3 Hz`，阻尼比为 `0.5 / 1 / 2`，时长 `2` 秒。目标在精确的 `0.6 / 1.4` 秒改变，每个积分区间在事件点拆开，两种算法保留各自的 value 和 velocity 后再接收同一新输入。

- 主轨：分段固定目标 `1 / -0.5 / 0.25`，目标速度与 response 都为 `0`。
- 前馈轨：每段从相同目标值开始，速度为 `0.6 / -0.4 / 0.2`，response 为 `0.75`。生产方法接收区间起点目标与同段速度；解析参照积分同一分段线性目标。起点采样约定是探针输入的一部分。
- 每条轨比较 `20 / 30 / 60 / 120 Hz`。另在每种阻尼的 `60 Hz` 主轨，于 `0.9` 秒加入一次 `0.25` 秒步长，且不跨越目标事件。

当前生产代码通过 `stable_k2` 随 delta 抬高稳定下界；它的有效系数可能偏离连续方程。因此误差包含稳定策略和离散积分差异。误差不是默认测试失败，不能据此宣称生产 API 的输出“不正确”，也不能从数值误差推出 CPU、FPS、内存或观感收益。

## 自检与结果

探针先用三个独立性质验证参照：已知临界单位阶跃闭式、拆分积分的半群性质（第二段推进同一线性目标）、同值零速度静止。共 `13` 个固定自检。自检不读取生产结果，其绝对容差为 `1e-9`。

`spring_math_probe.gd` 默认产生 `27` 条完整正常对照记录，保存最大 value/velocity 绝对误差、按样本均方根 value 误差、最大步长及实际最终状态；`legacy_invalid_input_observations` 默认为空。显式传入 `--observe-invalid` 才对八个公开标量参数分别注入 `NaN / +Infinity`，保存 `16` 条当前生产观察。非有限数值用 `nan / +inf / -inf` 字符串保存，不让 JSON 静默变为 null。这些观察不建立未来非法输入返回合同，也不因旧传播自动拒绝数学计算；若生产入口对非法输入发出诊断，它们仍是真实诊断，不能把这次可选观察当作无错误验收。

历史生产源的最小传播案例是 `step_float(NAN, 0.0, 1.0, 0.016, 3.0, 1.0)`，必须绑定当时源 SHA。当前四入口拒绝非有限输入或结果，返回空字典并发出一次稳定诊断；标量与最终原生向量状态都做完整有限检查。可选观察对空结果保存 `result_field_count=0`、`result_is_empty=true`，value/velocity 缺字段明确为 `missing`；只有实际返回的非有限数字才分类为 `nan / +inf / -inf`，未知字段类型为 `unsupported_type`。空字典不能当作生产仍在传播 NaN 的证据。拒绝值、方法上下文、次数和无部分状态由 GUT 保护，数值对照不重新定义这项合同。只有实际 Godot 输出才能填入观察数据。

JSON 固定顶层字段包含 schema_version=1、execution_state=`executed`、ok、issues、引擎/平台、三个源内容 hash 的 before/after、方程/采样约定、oracle_self_checks、comparisons、legacy_invalid_input_observations。`ok` 只接受自检通过、全部有限对照完整和源 hash 稳定，不要求误差为零。

历史观察固定绑定各自的生产与探针 SHA，不因工具新增开关或生产合同变化而重写。非法输入的拒绝值和诊断次数由期望诊断的 GUT 回归测试验证，正常数学对照不承担这项门禁。

## 派发前提与 argv

必须由维护进程监督器在可信隔离 GF 工程中派发，不启动游戏工程或用户 Editor。先完成 import，固定这两个工具脚本及生产源的内容，创建 `res://ai_analysis/benchmarks/spring_math/` 下的独占输出父目录，并选择尚不存在的 `.json` 路径。探针拒绝重复参数、已有结果文件及该目录外的输出；父目录的物理身份/无链接、私有 userdata、deadline、日志与进程静止由外层监督器核验。

传给实际 Godot 进程的参数：

```text
--headless --path <trusted-isolated-GF-root>
--script res://tools/benchmarks/spring_math_probe.gd
--log-file <trusted-isolated-GF-root>/ai_analysis/godot_logs/spring-math-probe.log
-- --output=res://ai_analysis/benchmarks/spring_math/spring-math-probe.json
```

需要单独观测非法输入时，在用户参数中追加开关并使用另一个尚不存在的文件：

```text
-- --output=res://ai_analysis/benchmarks/spring_math/spring-math-invalid-observations.json --observe-invalid
```

正常对照成功必须同时有外层退出码 0、监督器静止证据、有效 JSON 和两条实际 marker：`SPRING_MATH_ORACLE_SELF_CHECK_EXECUTED_OK`、`SPRING_MATH_PROBE_EXECUTED_OK rows=27 invalid_observations=0`。启用观察后，第二条 marker 按实际数组数量报告 `invalid_observations=16`。仅文件存在或 marker 文本不能替代 raw exit、日志诊断和监督器收尾。报告不自证原生进程静止，不声称跨平台已执行。
