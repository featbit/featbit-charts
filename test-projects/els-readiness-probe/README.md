# ELS readiness probe

独立的 .NET 10 ASP.NET Core 测试服务，直接执行与 FeatBit ELS 相同方式的
PostgreSQL / Redis readiness 检查，用于后续观察依赖检查失败率和耗时。

本项目不通过 HTTP 调用线上 ELS，不依赖整个 FeatBit 源码，不包含 Azure SDK、
OpenTelemetry、Collector 或 Kubernetes 部署配置。本次只创建项目并本地验证。

## 与 ELS 的对应关系

参考 [featbit/featbit](https://github.com/featbit/featbit) 的 ELS 源码，基准提交
[`37b4b81371b1d228a29970633201a6969f2a6264`](https://github.com/featbit/featbit/tree/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server)：

- [HealthCheckBuilderExtensions.cs](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Infrastructure/HealthCheckBuilderExtensions.cs)：注册 PG / Redis 检查。
- [MiddlewaresRegister.cs](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Api/Setup/MiddlewaresRegister.cs)：按 `Readiness` tag 执行检查，保留默认健康状态和 HTTP 状态码映射。
- [RedisClient.cs](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Infrastructure/Caches/Redis/RedisClient.cs)：复用 Lazy `ConnectionMultiplexer`，保留显式 Redis 参数，以及未指定时的连接恢复/超时默认值。
- [Infrastructure.csproj](https://github.com/featbit/featbit/blob/37b4b81371b1d228a29970633201a6969f2a6264/modules/evaluation-server/src/Infrastructure/Infrastructure.csproj)：核对依赖版本。

| 项目 | 本项目的方式 |
| --- | --- |
| Runtime | .NET 10，与已知线上 ELS 相同的大版本；无需 .NET 11 |
| PostgreSQL | `AspNetCore.HealthChecks.NpgSql 9.0.0` + `Npgsql 10.0.2`；singleton `NpgsqlDataSource`，复用连接池，打开连接并执行库默认的 `SELECT 1` 检查 |
| PostgreSQL 超时 | 与 ELS 一样不额外指定 health-check timeout；沿用连接字符串中的连接/命令超时 |
| Redis | `AspNetCore.HealthChecks.Redis 9.0.0` + `StackExchange.Redis 2.13.1`；共享 Lazy multiplexer，由库执行 PING / Cluster 健康检查 |
| Redis 检查超时 | 与 ELS 一样注册为 5 秒；底层连接/命令仍受驱动自身超时和取消支持影响 |
| Redis 默认参数 | 未显式指定时补 `abortConnect=false`、`connectTimeout=1500`、`syncTimeout=1500`，支持 `Redis__ConnectTimeoutMs` / `Redis__SyncTimeoutMs` |

这些版本来自源码核对，不代表已经核对生产镜像内每个依赖的实际版本。
本项目只提取 PG/Redis readiness 部分，不加载 ELS 的 store、消息消费、业务请求、
MongoDB、Kafka 或控制面检查。

## 运行

需要 .NET 10 SDK。目录内 `global.json` 允许已安装的稳定 .NET 10 SDK feature band。
从本目录执行：

```powershell
dotnet restore Els.ReadinessProbe.slnx --configfile NuGet.Config
dotnet build Els.ReadinessProbe.slnx --no-restore
dotnet test Els.ReadinessProbe.slnx --no-restore
```

连接配置使用与 ELS 相同的键，密码可以单独覆盖。配置好需要测试的目标之后再启动：

```powershell
$env:Postgres__ConnectionString = 'Host=<postgres-host>;Port=5432;Database=featbit;Username=<user>;Timeout=15;SSL Mode=VerifyFull'
$env:Postgres__Password = '<password>'
$env:Redis__ConnectionString = '<redis-host>:6380,ssl=true'
$env:Redis__Password = '<password>'

dotnet run --project src/Els.ReadinessProbe --no-launch-profile
```

上面的地址/凭据都是占位符。缺少连接字符串时服务启动失败，避免依赖未配置却返回 Healthy。
不要把真实连接字符串写进受 Git 跟踪的文件。

也可以将 `src/Els.ReadinessProbe/appsettings.Local.example.json` 复制为同目录下的
`appsettings.Local.json` 后修改。本地文件已被 `.gitignore` 排除；环境变量和命令行
优先于本地文件。连接字符串内的池、TLS、GSS 等参数默认保持驱动行为，程序不做
针对某个根因的连接参数调整。

默认仅监听 `http://localhost:5080`。访问接口：

```powershell
Invoke-WebRequest http://localhost:5080/health/liveness
Invoke-WebRequest http://localhost:5080/health/readiness
Invoke-RestMethod http://localhost:5080/diagnostics/stats | ConvertTo-Json -Depth 10
```

也可使用仓库中的 [requests.http](requests.http)。服务是本地诊断工具，接口未加入认证；
若之后需要对外访问，应先明确其访问范围。

## 接口与统计

| 接口 | 行为 |
| --- | --- |
| `GET /health/liveness` | 仅检查服务存活，返回 `200 Healthy`，不请求 PG/Redis，不计入样本 |
| `GET /health/readiness` | 并行执行带 `Readiness` tag 的 PG/Redis 检查；默认映射为 `200 Healthy` / `200 Degraded` / `503 Unhealthy`，每次完整报告记录一个样本 |
| `GET /diagnostics/stats` | 只读快照，不触发依赖请求；返回累计次数、分依赖错误率、平均/最大耗时、最近结果和有上限的最近失败记录 |

统计以**健康检查调用**为单位，不是 TCP 包、驱动重试或底层 Redis 命令数：

- `completedRuns`：进程内记录的完整 readiness 报告数。
- `readinessFailureRate`：Unhealthy 报告数 / 完整报告数，范围 0–1，对应默认 HTTP 503 比例。
- `checks.npgsql` / `checks.redis`：各依赖独立的完成次数、Healthy/Degraded/Unhealthy 次数、耗时与最近结果。
- 每个依赖的 `errorRate`：(Degraded + Unhealthy) / 该依赖的完成次数，范围 0–1。
- `runsBySource`：区分手动 HTTP 检查与后台采样；如果两者都启用，两者都会进入总统计。
- `recentFailures`：最近非 Healthy 报告，默认最多保留 100 条，新的在前。

统计线程安全，但仅在本进程内累计，重启清零；多个实例的计数不自动聚合。
请求取消且未形成完整报告的执行不计入这些分母，因此不能把它直接当作生产 HTTP 499/500 错误率。

控制台使用 JSON 日志记录采样编号、UTC 时间、来源、状态、耗时，以及失败的异常类型链、
SQLSTATE / SocketError（若存在）。统计和应用采样日志不输出连接字符串、密码、
原始异常消息或 stack trace。为避免框架重复输出原始异常，默认抑制框架 health-check
错误日志；需要更多驱动诊断时应单独安排日志配置。

## 可选定时采样

后台采样默认关闭。关闭时，只有请求 readiness 接口才会触发依赖访问。
需要持续观察时，在启动前显式设置：

```powershell
$env:Probe__Enabled = 'true'
$env:Probe__IntervalSeconds = '10'
$env:Probe__RecentFailureLimit = '100'
dotnet run --project src/Els.ReadinessProbe --no-launch-profile
```

启用后启动一次采样，之后每次检查结束再等待指定间隔，不重叠发起后台检查。
外部并发请求 `/health/readiness` 仍可与后台检查并发执行。参数变更通过重启生效。
初次创建项目时不会自动开始针对任何实际环境的长期采样。

## 已验证与边界

本地测试覆盖 HTTP 状态、无 I/O 的 liveness/stats、分依赖错误率、并发计数、
有界失败记录、敏感消息不进入统计、连接配置及可选后台采样。
另有一个测试使用真实 Npgsql/Redis 驱动访问关闭的本机临时端口，验证失败报告和分别计数；
它不连接已有数据库，也不能证明真实 PG/Redis 的正常请求已验证。

目前未使用实际 PG/Redis 凭据，未采集生产失败率，未部署 AKS。
Windows 本地测试也不代表 Linux/AKS 网络条件已经复现。

readiness 的低负载检查与 `/evaluate` 业务请求不同。PG 连接池可能复用已有物理连接，
Redis 也复用 multiplexer；检查成功不代表每次都完成了新的 DNS/TCP/TLS 建连。
如之后要比较冷连接，可单独做带 `Pooling=false` 的受控对照，但不要混合两类样本，
也不要把这种对照当作默认 ELS 行为。

这个服务不会为了产生请求而修改业务数据，也不保证捕获 Npgsql 协商回退前已被覆盖的第一次异常。
