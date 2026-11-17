# A1 人口学描述性分析质控

2026-11-17。本轮已实际运行独立描述性分析。冻结文件、原主分析脚本和主稿保持原状。未运行 A1 主分析。

## 输入与设计

- 2017–March 2020 使用 `public_nhanes/2017/P_DEMO.xpt`、`P_BMX.xpt`、`P_LUX.xpt`，权重为 WTMECPRP。
- August 2021–August 2023 使用 `public_nhanes/2021/DEMO_L.xpt`、`BMX_L.xpt`、`LUX_L.xpt`，权重为 WTMEC2YR。
- 六个 XPT 的 SHA-256、文件字节数和行数与项目下载清单相符。读取完整文件，验证各模块 SEQN 唯一、无缺失，按 SEQN 对接。
- 各期分别在 MEC 权重为正且 SDMVSTRA、SDMVPSU 有效的全部样本上建立 survey 设计，使用 `nest=TRUE`。完整设计样本数分别为 14,300 和 8,860，设计自由度为 25 和 15。
- D 采用年龄 ≥20 岁、LUAXSTAT 为 1 或 2、BMI 可用且 ≥18.5 kg/m²。BMI 分层为 18.5–<30 和 ≥30 kg/m²。是否有 LSM 不参与筛选，符合 D 定义的部分检查者均保留。
- 在完整设计内取各域，使用 `svymean()` 计算连续变量均值及 Taylor 线性化标准误，并计算 RIAGENDR 和 RIDRETH3 各类的加权百分比。分类百分比按同一时期、同一域的权重总量计算。各域无缺失，各类别未加权人数之和等于本域人数，加权比例在舍入前合计 100%。未开展组间检验或生成 P 值。

## 冻结对照和缺失核查

| 时期 | D | BMI 18.5–<30 | BMI ≥30 | BMI 筛选前人数 | BMI 筛选前缺失 |
|---|---:|---:|---:|---:|---:|
| 2017–March 2020 | 7,792 | 4,439 | 3,353 | 7,989 | 84 |
| August 2021–August 2023 | 5,580 | 3,275 | 2,305 | 5,704 | 47 |

D 与两个分层人数全部匹配 `A1_results/A1_design.csv` 及预期值。年龄、性别、种族/族裔在两期 BMI 筛选前均无缺失，与 `A1_Demographic_Data_Availability_Audit.md` 一致。两期 D 及其各自 BMI 分层中，年龄、BMI、性别和种族/族裔的缺失人数均为 0。BMI 缺失者未进入 D。

## 变量解释与交付核对

- 年龄使用公开 RIDAGEYR，单位为岁。80 岁及以上统一编码为 80，均值基于公开顶码值。BMI 使用 BMXBMI，单位为 kg/m²。
- 性别保留 RIAGENDR 的 Male 和 Female。种族/族裔保留 RIDRETH3 的全部六个官方类别（代码 1、2、3、4、6、7）。[CDC P_DEMO](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_DEMO.htm)；[CDC DEMO_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/DEMO_L.htm)。
- CSV 包含 90 条聚合记录，提供未加权人数、加权均值、均值 SE 或加权百分比。Excel 含并排展示及精确聚合数据两个工作表，已重新打开并核对展示项目。展示层将估计舍入至两位小数。
- 实际运行环境为 Windows、R 4.6.1、survey 4.5 和 foreign 0.8-91。从项目根目录调用 `Rscript --vanilla A1_Demographic_Analysis/A1_Demographic_Analysis.R`。如 CSV 已存在，可在末尾传入一个新的输出路径。只有通过输入、缺失和人数检查后才写出结果。

建议在作者审核后将人口学表纳入 PLOS ONE Supporting Information，并从正文样本描述和 STROBE 14a 清单指向该表。正文可保留两期目标域及 BMI 分层的人数。
