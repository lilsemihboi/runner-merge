"""Run the Merge Cars economy simulator, analysis, optimizer, and report."""

from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from tools.balance_analysis import (
	car_diagnostics,
	overall_balance_score,
	pay_to_win_score,
	quantiles,
	route_diagnostics,
	sensitivity_analysis,
	summarize_results,
)
from tools.balance_optimizer import search
from tools.economy_config import (
	BehaviorType,
	EconomyConfig,
	HORIZONS_SECONDS,
	PAID_ADVANTAGE_TARGETS,
	PlayerType,
	default_config,
)
from tools.economy_simulator import EconomySimulator, SimulationResult, run_population


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--runs", type=int, default=10_000)
	parser.add_argument("--behavior-runs", type=int, default=500)
	parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
	parser.add_argument("--optimizer-runs", type=int, default=100)
	parser.add_argument("--optimizer-candidates", type=int, default=80)
	parser.add_argument("--duration", type=float, default=7 * 24 * 60 * 60)
	parser.add_argument("--seed", type=int, default=20260813)
	parser.add_argument("--output", type=Path, default=Path("balance_results"))
	parser.add_argument("--skip-optimizer", action="store_true")
	parser.add_argument("--no-progress", action="store_true", help="Disable terminal progress bars")
	parser.add_argument("--quick", action="store_true")
	return parser.parse_args()


def _run_cohorts(config: EconomyConfig, runs: int, behavior_runs: int, duration: float, seed: int, workers: int, progress: bool) -> dict[tuple[PlayerType, BehaviorType], list[SimulationResult]]:
	results = {}
	for player_type in PlayerType:
		for behavior in BehaviorType:
			configuration_runs = runs if behavior == BehaviorType.AVERAGE else behavior_runs
			label = f"{player_type.value} / {behavior.value}"
			results[(player_type, behavior)] = run_population(config, player_type, behavior, duration, configuration_runs, seed + list(PlayerType).index(player_type) * 100 + list(BehaviorType).index(behavior) * 10, workers, progress, label)
	return results


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
	if not rows:
		return
	path.parent.mkdir(parents=True, exist_ok=True)
	keys = sorted({key for row in rows for key in row})
	with path.open("w", newline="", encoding="utf-8") as handle:
		writer = csv.DictWriter(handle, fieldnames=keys)
		writer.writeheader()
		writer.writerows(rows)


def _plot_history(path: Path, cohort_results: dict[tuple[PlayerType, BehaviorType], list[SimulationResult]], field: str, title: str, ylabel: str) -> None:
	plt.figure(figsize=(11, 6))
	for (player_type, behavior), results in cohort_results.items():
		if behavior != BehaviorType.AVERAGE:
			continue
		series = [result.history for result in results[: min(500, len(results))]]
		if not series or not series[0]:
			continue
		times = [point["time"] / 3600 for point in series[0]]
		values = np.asarray([[point[field] for point in history] for history in series], dtype=float)
		plt.plot(times, np.median(values, axis=0), label=player_type.value)
	plt.title(title)
	plt.xlabel("Active play time (hours)")
	plt.ylabel(ylabel)
	plt.legend()
	plt.grid(alpha=0.25)
	plt.tight_layout()
	plt.savefig(path, dpi=140)
	plt.close()


def _plot_wealth(path: Path, cohort_results: dict[tuple[PlayerType, BehaviorType], list[SimulationResult]]) -> None:
	plt.figure(figsize=(11, 6))
	for player_type in PlayerType:
		results = cohort_results[(player_type, BehaviorType.AVERAGE)]
		plt.hist([result.final_cash for result in results], bins=50, alpha=0.35, label=player_type.value)
	plt.title("Final cash distribution by player type")
	plt.xlabel("Cash")
	plt.ylabel("Runs")
	plt.legend()
	plt.tight_layout()
	plt.savefig(path, dpi=140)
	plt.close()


def _plot_bars(path: Path, rows: list[dict[str, Any]], x: str, y: str, title: str, ylabel: str) -> None:
	plt.figure(figsize=(11, 6))
	labels = [str(row[x]) for row in rows]
	values = [row[y] for row in rows]
	plt.bar(labels, values)
	plt.title(title)
	plt.xlabel(x)
	plt.ylabel(ylabel)
	plt.xticks(rotation=35, ha="right")
	plt.tight_layout()
	plt.savefig(path, dpi=140)
	plt.close()


def _plot_cohort_metric(path: Path, summaries: dict[str, dict[str, Any]], metric: str, title: str, ylabel: str) -> None:
	rows = [(name, summary[metric]["median"]) for name, summary in summaries.items() if name.endswith("_average")]
	_plot_bars(path, [{"cohort": name, "value": value} for name, value in rows], "cohort", "value", title, ylabel)


def _plot_milestone_times(path: Path, summaries: dict[str, dict[str, Any]]) -> None:
	rows = []
	for name, summary in summaries.items():
		if not name.endswith("_average"):
			continue
		value = summary.get("milestones", {}).get("campaign_end", {}).get("median")
		if value is not None:
			rows.append({"cohort": name, "hours": value / 3600})
	_plot_bars(path, rows, "cohort", "hours", "Free versus paid campaign completion", "Hours")


def _plot_upgrade_payback(path: Path, config: EconomyConfig) -> None:
	rows = []
	baseline_rate = 1_000.0
	for upgrade in ("runner_speed", "cash_bonus"):
		for level in range(1, 11):
			cost = __import__("economy_simulator").upgrade_cost(upgrade, level)
			additional = baseline_rate * 0.1 / (1 + 0.1 * (level - 1))
			rows.append({"label": f"{upgrade}_{level}", "minutes": cost / additional / 60})
	_plot_bars(path, rows, "label", "minutes", "Upgrade payback at $1,000/sec baseline", "Minutes")


def _plot_optimizer(path: Path, candidates: list[Any]) -> None:
	plt.figure(figsize=(11, 6))
	if candidates:
		plt.scatter([candidate.scales.car_income for candidate in candidates], [candidate.score for candidate in candidates], c=[candidate.scales.route_rewards for candidate in candidates], cmap="viridis")
		plt.colorbar(label="Route reward scale")
	plt.title("Balance score versus car income scale")
	plt.xlabel("Car income scale")
	plt.ylabel("Balance score")
	plt.tight_layout()
	plt.savefig(path, dpi=140)
	plt.close()


def _write_report(
	path: Path,
	config: EconomyConfig,
	summaries: dict[str, dict[str, Any]],
	routes: list[dict[str, Any]],
	cars: list[dict[str, Any]],
	p2w: dict[str, float],
	balance: dict[str, float],
	optimizer_results: list[Any],
	sensitivity: list[dict[str, Any]],
) -> None:
	best_route = max(routes, key=lambda row: row["income_per_hour"])
	worst_route = min(routes, key=lambda row: row["income_per_hour"])
	best_merge = max(cars, key=lambda row: row["merge_throughput_ratio"])
	worst_merge = min(cars, key=lambda row: row["merge_throughput_ratio"])
	with path.open("w", encoding="utf-8") as report:
		report.write("# Merge Cars Economy Balance Report\n\n")
		report.write("This report is advisory. It does not modify Luau values, Studio assets, or player data. All recommended values are simulation overlays.\n\n")
		report.write("## Target and Method\n\n")
		report.write(f"- D7 target: reach route 7 and tier 40 within {config.targets.endgame_seconds / 86400:.0f} active-play days.\n")
		report.write(f"- Default paid progression target: {config.targets.paid_advantage:.2f}x.\n")
		report.write("- Primary cohorts exclude group rewards, friends, and unknown live redemption codes.\n")
		report.write("- Paid presets are entitlement assumptions, not Robux-price claims.\n\n")
		report.write("## Current Economy\n\n")
		report.write("### Routes\n\n| Route | Avg path | Cash gates | Cash multiplier | Measured income/hour | Selection fraction |\n|---:|---:|---:|---:|---:|---:|\n")
		for row in routes:
			report.write(f"| {row['route_id']} | {row['average_path_length']:.2f} | {row['cash_gate_cap']} | {row['cash_multiplier']:.2f}x | ${row['income_per_hour']:,.0f} | {row['selected_fraction']:.1%} |\n")
		report.write(f"\nMost profitable measured route: **Route {best_route['route_id']}**. Most problematic measured route: **Route {worst_route['route_id']}** by active-play income rate.\n\n")
		report.write("### Car progression\n\n")
		report.write(f"Best merge throughput tier: **Tier {best_merge['tier']}** at {best_merge['merge_throughput_ratio']:.2f}x versus two source cars. Worst merge throughput tier: **Tier {worst_merge['tier']}** at {worst_merge['merge_throughput_ratio']:.2f}x.\n\n")
		report.write("## Simulation Results\n\n")
		for name, summary in summaries.items():
			income = summary["total_income"]
			cash = summary["final_cash"]
			report.write(f"### {name}\n\n")
			report.write(f"Runs: {summary['runs']:,}. Final cash median: ${cash['median']:,.0f}; P10/P90: ${cash['p10']:,.0f}/${cash['p90']:,.0f}. Total income median: ${income['median']:,.0f}. Median tier: {summary['max_car_tier']['median']:.1f}. Median rebirths: {summary['rebirths']['median']:.1f}.\n\n")
		report.write("## Free Versus Paid\n\n")
		report.write(f"Current heavy-versus-free pay-to-win score: **{p2w['score']:.1f}/100**. Median endgame-time multiplier: **{p2w['endgame_time_ratio']:.2f}x**. Configured target: **{p2w['target_advantage']:.2f}x**.\n\n")
		report.write("## Problems\n\n")
		problems = [
			f"Route {worst_route['route_id']} has the lowest measured active-play income rate despite later progression requirements.",
			f"Route {best_route['route_id']} is the measured route-rate leader, so automatic highest-unlocked route selection may be suboptimal.",
			f"Tier {worst_merge['tier']} has the weakest merge throughput ratio ({worst_merge['merge_throughput_ratio']:.2f}x).",
			"Normal rebirth resets all cash upgrades, making every rebirth a potential pacing valley.",
			"Paid exclusive car and paid trail crates can dominate the income distribution rather than merely shorten progression.",
			"Offline earnings omit route, x2 cash, x2 speed, and friends, so the offline loop is not equivalent to active play.",
			"Free crate progression has a long tail because high-tier crate queue weights are very small.",
			"Duplicate trails have no source-visible sink or salvage value.",
			"Spins have no source-visible consumer, so paid spin value is undefined.",
			"Regular car formulas continue past authored tier 40, which can create an unbounded endgame curve.",
		]
		for index, problem in enumerate(problems, 1):
			report.write(f"{index}. {problem}\n")
		report.write("\n## Recommendations\n\n")
		report.write("No game values were changed. The following are analysis-only candidates to test in a future controlled balance patch.\n\n")
		report.write(f"1. CURRENT: route registry multiplier and geometry. RECOMMENDED: evaluate route reward normalization around Route {best_route['route_id']} throughput. EXPECTED EFFECT: restore meaningful route choices. EVIDENCE: measured income/hour leader Route {best_route['route_id']} versus lowest Route {worst_route['route_id']}.\n")
		report.write("2. CURRENT: free player progression. RECOMMENDED: reduce only the longest measured idle milestone gaps, using the optimizer candidate rather than a blind global multiplier. EXPECTED EFFECT: D7 viability without flattening paid differentiation.\n")
		report.write("3. CURRENT: paid advantages stack multiplicatively. RECOMMENDED: test paid boost scale candidates against the configured target. EXPECTED EFFECT: preserve meaningful advantage while reducing pay-to-win pressure.\n")
		report.write("4. CURRENT: duplicate trails and spins have no source-visible sink. RECOMMENDED: add a separately designed salvage/spin consumer after economy review. EXPECTED EFFECT: reduce dead resources.\n")
		report.write("5. CURRENT: normal rebirth clears cash upgrades. RECOMMENDED: test pacing compensation only if D7 idle metrics fail; do not change reset behavior based on this report alone. EXPECTED EFFECT: fewer post-rebirth dead periods.\n\n")
		report.write("## Optimization\n\n")
		for candidate in optimizer_results[:10]:
			report.write(f"- Score {candidate.score:.1f}; route rewards {candidate.scales.route_rewards:.2f}x; car income {candidate.scales.car_income:.2f}x; upgrade costs {candidate.scales.upgrade_costs:.2f}x; paid boosts {candidate.scales.paid_boosts:.2f}x; paid advantage {candidate.paid_advantage:.2f}x.\n")
		report.write("\n## Sensitivity\n\n")
		for row in sorted(sensitivity, key=lambda item: abs(item["wealth_change_fraction"]), reverse=True):
			report.write(f"- {row['parameter']} at {row['value']:.2f}x changed mean wealth by {row['wealth_change_fraction']:+.1%}.\n")
		report.write("\n## Overall Balance\n\n")
		report.write(f"Overall score: **{balance['score']:.1f}/100**. Components: free viability {balance['free_viability']:.2f}, paid target fit {balance['paid_advantage_target']:.2f}, pacing {balance['activity_pacing']:.2f}, route choice {balance['route_choice']:.2f}, pay-to-win pressure {balance['pay_to_win_pressure']:.2f}.\n")


def main() -> None:
	args = parse_args()
	config = default_config(args.seed)
	if args.quick:
		args.runs = min(args.runs, 100)
		args.behavior_runs = min(args.behavior_runs, 20)
		args.optimizer_runs = min(args.optimizer_runs, 10)
		args.optimizer_candidates = min(args.optimizer_candidates, 4)
	output = args.output
	output.mkdir(parents=True, exist_ok=True)
	config = default_config(args.seed)
	progress = not args.no_progress
	print(f"Starting balance run: {args.runs:,} average-profile runs per player type, {args.behavior_runs:,} runs for each other behavior, {args.workers} workers.")
	print(f"Simulation horizon: {args.duration / 3600:,.1f} active-play hours. Output: {output}")
	print("\n[Stage 1/6] Simulating player cohorts")
	cohort_results = _run_cohorts(config, args.runs, args.behavior_runs, args.duration, args.seed, args.workers, progress)
	print("[Stage 2/6] Aggregating distributions and balance scores")
	summaries = {f"{player.value}_{behavior.value}": summarize_results(results) for (player, behavior), results in cohort_results.items()}
	average_results = [result for (player, behavior), results in cohort_results.items() if behavior == BehaviorType.AVERAGE for result in results]
	routes = route_diagnostics(average_results, config)
	cars = car_diagnostics(config)
	free_summary = summaries["free_average"]
	paid_summary = summaries["heavy_premium_average"]
	p2w = pay_to_win_score(free_summary, paid_summary, config)
	balance = overall_balance_score(config, free_summary, paid_summary, average_results)
	print("[Stage 3/6] Running sensitivity analysis")
	sensitivity = sensitivity_analysis(config, PlayerType.FREE, BehaviorType.AVERAGE, min(args.duration, 24 * 60 * 60), max(20, min(args.optimizer_runs, 100)), args.seed)
	if args.skip_optimizer:
		print("[Stage 4/6] Optimizer skipped by --skip-optimizer")
		optimizer_results = []
	else:
		print(f"[Stage 4/6] Searching {args.optimizer_candidates:,} parameter candidates")
		optimizer_results = search(config, args.optimizer_runs, args.duration, args.seed, args.optimizer_candidates, progress=progress)
	print("[Stage 5/6] Writing report and machine-readable results")
	_write_report(output.parent / "balance_report.md", config, summaries, routes, cars, p2w, balance, optimizer_results, sensitivity)
	(output / "summaries.json").write_text(json.dumps(summaries, indent=2), encoding="utf-8")
	(output / "routes.json").write_text(json.dumps(routes, indent=2), encoding="utf-8")
	(output / "cars.json").write_text(json.dumps(cars, indent=2), encoding="utf-8")
	(output / "scores.json").write_text(json.dumps({"pay_to_win": p2w, "balance": balance}, indent=2), encoding="utf-8")
	(output / "sensitivity.json").write_text(json.dumps(sensitivity, indent=2), encoding="utf-8")
	(output / "optimizer.json").write_text(json.dumps([candidate.__dict__ for candidate in optimizer_results], indent=2, default=str), encoding="utf-8")
	_write_csv(output / "route_diagnostics.csv", routes)
	_write_csv(output / "sensitivity.csv", sensitivity)
	print("[Stage 6/6] Rendering graphs")
	_plot_history(output / "money_over_time.png", cohort_results, "cash", "Money over active play time", "Cash")
	_plot_history(output / "income_over_time.png", cohort_results, "total_income", "Income over active play time", "Cumulative income")
	_plot_history(output / "expenses_over_time.png", cohort_results, "expenses", "Expenses over active play time", "Cumulative expenses")
	_plot_history(output / "progression_over_time.png", cohort_results, "max_car_tier", "Car progression over active play time", "Highest car tier")
	_plot_wealth(output / "wealth_distribution.png", cohort_results)
	_plot_bars(output / "route_income_per_hour.png", routes, "route_id", "income_per_hour", "Measured route income/hour", "Income/hour")
	_plot_cohort_metric(output / "free_vs_paid_wealth.png", summaries, "total_income", "Free versus paid wealth", "Median cumulative income")
	_plot_milestone_times(output / "free_vs_paid_progression_time.png", summaries)
	_plot_bars(output / "route_selection_frequency.png", routes, "route_id", "selected_fraction", "Route selection frequency", "Fraction")
	_plot_upgrade_payback(output / "upgrade_payback_time.png", config)
	_plot_optimizer(output / "balance_score_vs_parameter.png", optimizer_results)
	_plot_bars(output / "pay_to_win_score.png", [{"metric": key, "value": value} for key, value in p2w.items() if key != "target_advantage"], "metric", "value", "Pay-to-win score components", "Value")
	_plot_cohort_metric(output / "player_progression_distribution.png", summaries, "max_car_tier", "Player progression distribution", "Median car tier")
	_plot_bars(output / "sensitivity_analysis.png", sensitivity, "parameter", "wealth_change_fraction", "Sensitivity analysis", "Wealth change")
	print(f"Wrote report: {output.parent / 'balance_report.md'}")
	print(f"Wrote results: {output}")
	print(f"Balance score: {balance['score']:.1f}/100")
	print(f"Pay-to-win score: {p2w['score']:.1f}/100")


if __name__ == "__main__":
	main()
