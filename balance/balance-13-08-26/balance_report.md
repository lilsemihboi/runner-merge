# Merge Cars Economy Balance Report

This report is advisory. It does not modify Luau values, Studio assets, or player data. All recommended values are simulation overlays.

## Target and Method

- D7 target: reach route 7 and tier 40 within 7 active-play days.
- Default paid progression target: 1.25x.
- Primary cohorts exclude group rewards, friends, and unknown live redemption codes.
- Paid presets are entitlement assumptions, not Robux-price claims.

## Current Economy

### Routes

| Route | Avg path | Cash gates | Cash multiplier | Measured income/hour | Selection fraction |
|---:|---:|---:|---:|---:|---:|
| 1 | 180.07 | 8 | 1.00x | $2,290,259,885,392 | 1.0% |
| 2 | 151.01 | 10 | 1.25x | $5,192,429,080,458 | 13.2% |
| 3 | 149.60 | 12 | 1.50x | $11,517,067,598,011 | 52.9% |
| 4 | 211.68 | 14 | 1.75x | $16,849,048,121,796 | 22.2% |
| 5 | 363.54 | 16 | 2.00x | $13,972,455,223,004 | 2.2% |
| 6 | 373.70 | 18 | 2.25x | $19,596,426,900,949 | 4.9% |
| 7 | 453.99 | 25 | 2.50x | $37,609,547,466,339 | 3.6% |

Most profitable measured route: **Route 7**. Most problematic measured route: **Route 1** by active-play income rate.

### Car progression

Best merge throughput tier: **Tier 2** at 20.83x versus two source cars. Worst merge throughput tier: **Tier 40** at 0.55x.

## Simulation Results

### free_casual

Runs: 500. Final cash median: $38,979,459,874; P10/P90: $8,995,670,649/$86,473,182,513. Total income median: $73,609,572,347. Median tier: 10.0. Median rebirths: 8.0.

### free_average

Runs: 10,000. Final cash median: $73,056,503,378; P10/P90: $22,317,299,672/$367,608,289,938. Total income median: $1,778,252,922,717. Median tier: 11.0. Median rebirths: 9.0.

### free_optimized

Runs: 500. Final cash median: $110,453,238,833; P10/P90: $37,564,661,250/$598,704,877,204. Total income median: $2,516,005,074,736. Median tier: 11.0. Median rebirths: 9.0.

### free_highly_optimized

Runs: 500. Final cash median: $159,657,419,001; P10/P90: $35,223,905,097/$244,105,352,636. Total income median: $3,953,425,642,206. Median tier: 11.0. Median rebirths: 9.0.

### light_spender_casual

Runs: 500. Final cash median: $43,952,684,200; P10/P90: $19,824,020,798/$82,962,714,370. Total income median: $69,632,914,068. Median tier: 10.0. Median rebirths: 8.0.

### light_spender_average

Runs: 10,000. Final cash median: $93,886,119,633; P10/P90: $35,406,544,439/$445,094,729,438. Total income median: $1,802,836,528,480. Median tier: 12.0. Median rebirths: 9.0.

### light_spender_optimized

Runs: 500. Final cash median: $183,867,156,790; P10/P90: $44,379,587,664/$750,372,619,476. Total income median: $3,657,542,638,562. Median tier: 11.0. Median rebirths: 9.0.

### light_spender_highly_optimized

Runs: 500. Final cash median: $202,134,746,924; P10/P90: $41,028,032,232/$334,080,895,360. Total income median: $5,024,260,627,504. Median tier: 11.0. Median rebirths: 9.0.

### medium_spender_casual

Runs: 500. Final cash median: $165,545,684,589; P10/P90: $54,506,580,491/$760,727,031,692. Total income median: $443,620,409,492. Median tier: 12.0. Median rebirths: 9.0.

### medium_spender_average

Runs: 10,000. Final cash median: $432,648,117,469; P10/P90: $69,549,769,665/$897,780,960,966. Total income median: $9,920,149,506,380. Median tier: 12.0. Median rebirths: 9.0.

### medium_spender_optimized

Runs: 500. Final cash median: $252,927,717,069; P10/P90: $29,804,066,517/$834,162,971,632. Total income median: $15,933,670,262,017. Median tier: 12.0. Median rebirths: 10.0.

### medium_spender_highly_optimized

Runs: 500. Final cash median: $615,252,633,194; P10/P90: $184,728,830,248/$1,220,447,388,677. Total income median: $19,938,446,451,475. Median tier: 11.0. Median rebirths: 10.0.

### heavy_premium_casual

Runs: 500. Final cash median: $373,517,907,293,982; P10/P90: $219,883,320,902,470/$825,871,095,796,665. Total income median: $555,037,166,098,602. Median tier: 16.0. Median rebirths: 12.0.

### heavy_premium_average

Runs: 10,000. Final cash median: $483,876,833,918,470; P10/P90: $87,755,771,455,601/$898,500,765,223,084. Total income median: $9,314,068,509,657,304. Median tier: 17.0. Median rebirths: 12.0.

### heavy_premium_optimized

Runs: 500. Final cash median: $270,560,437,096,027; P10/P90: $65,562,015,648,254/$924,380,360,934,256. Total income median: $15,669,164,310,599,168. Median tier: 17.0. Median rebirths: 13.0.

### heavy_premium_highly_optimized

Runs: 500. Final cash median: $510,564,836,137,580; P10/P90: $152,974,328,422,360/$935,079,851,507,164. Total income median: $18,833,710,014,286,616. Median tier: 17.0. Median rebirths: 13.0.

## Free Versus Paid

Current heavy-versus-free pay-to-win score: **100.0/100**. Median endgame-time multiplier: **179.81x**. Configured target: **1.25x**.

## Problems

1. Route 1 has the lowest measured active-play income rate despite later progression requirements.
2. Route 7 is the measured route-rate leader, so automatic highest-unlocked route selection may be suboptimal.
3. Tier 40 has the weakest merge throughput ratio (0.55x).
4. Normal rebirth resets all cash upgrades, making every rebirth a potential pacing valley.
5. Paid exclusive car and paid trail crates can dominate the income distribution rather than merely shorten progression.
6. Offline earnings omit route, x2 cash, x2 speed, and friends, so the offline loop is not equivalent to active play.
7. Free crate progression has a long tail because high-tier crate queue weights are very small.
8. Duplicate trails have no source-visible sink or salvage value.
9. Spins have no source-visible consumer, so paid spin value is undefined.
10. Regular car formulas continue past authored tier 40, which can create an unbounded endgame curve.

## Recommendations

No game values were changed. The following are analysis-only candidates to test in a future controlled balance patch.

1. CURRENT: route registry multiplier and geometry. RECOMMENDED: evaluate route reward normalization around Route 7 throughput. EXPECTED EFFECT: restore meaningful route choices. EVIDENCE: measured income/hour leader Route 7 versus lowest Route 1.
2. CURRENT: free player progression. RECOMMENDED: reduce only the longest measured idle milestone gaps, using the optimizer candidate rather than a blind global multiplier. EXPECTED EFFECT: D7 viability without flattening paid differentiation.
3. CURRENT: paid advantages stack multiplicatively. RECOMMENDED: test paid boost scale candidates against the configured target. EXPECTED EFFECT: preserve meaningful advantage while reducing pay-to-win pressure.
4. CURRENT: duplicate trails and spins have no source-visible sink. RECOMMENDED: add a separately designed salvage/spin consumer after economy review. EXPECTED EFFECT: reduce dead resources.
5. CURRENT: normal rebirth clears cash upgrades. RECOMMENDED: test pacing compensation only if D7 idle metrics fail; do not change reset behavior based on this report alone. EXPECTED EFFECT: fewer post-rebirth dead periods.

## Optimization

- Score 40.0; route rewards 1.20x; car income 2.00x; upgrade costs 1.00x; paid boosts 1.20x; paid advantage 132.35x.
- Score 40.0; route rewards 0.70x; car income 0.60x; upgrade costs 1.30x; paid boosts 1.20x; paid advantage 186.66x.
- Score 40.0; route rewards 0.90x; car income 0.50x; upgrade costs 0.90x; paid boosts 1.30x; paid advantage 215.60x.
- Score 40.0; route rewards 1.30x; car income 1.75x; upgrade costs 1.10x; paid boosts 2.00x; paid advantage 123.60x.
- Score 40.0; route rewards 0.60x; car income 1.00x; upgrade costs 0.90x; paid boosts 1.75x; paid advantage 194.82x.
- Score 40.0; route rewards 1.00x; car income 0.80x; upgrade costs 0.60x; paid boosts 2.00x; paid advantage 199.92x.
- Score 40.0; route rewards 1.10x; car income 0.50x; upgrade costs 0.80x; paid boosts 1.00x; paid advantage 208.92x.
- Score 40.0; route rewards 0.60x; car income 1.75x; upgrade costs 1.20x; paid boosts 2.00x; paid advantage 131.20x.
- Score 40.0; route rewards 1.50x; car income 2.00x; upgrade costs 1.75x; paid boosts 1.10x; paid advantage 109.07x.
- Score 40.0; route rewards 1.75x; car income 0.70x; upgrade costs 1.20x; paid boosts 1.50x; paid advantage 194.34x.

## Sensitivity

- route_rewards at 1.10x changed mean wealth by +11.9%.
- upgrade_costs at 1.10x changed mean wealth by +9.7%.
- car_income at 1.10x changed mean wealth by +5.2%.
- upgrade_costs at 0.90x changed mean wealth by +4.4%.
- car_income at 0.90x changed mean wealth by -1.9%.
- route_rewards at 0.90x changed mean wealth by -0.2%.
- paid_boosts at 0.90x changed mean wealth by +0.0%.
- paid_boosts at 1.10x changed mean wealth by +0.0%.

## Overall Balance

Overall score: **40.0/100**. Components: free viability 1.00, paid target fit 0.00, pacing 0.00, route choice 1.00, pay-to-win pressure 0.00.
