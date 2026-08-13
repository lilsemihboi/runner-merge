"""Statistical analysis, balance scoring, and report-ready diagnostics."""

from __future__ import annotations

import json
import math
from collections import Counter
from dataclasses import asdict
from pathlib import Path
from typing import Any, Iterable

import numpy as np

from tools.economy_config import (
	BehaviorType,
	EconomyConfig,
	EconomyScales,
	PAID_ADVANTAGE_TARGETS,
	PlayerType,
)
from tools.economy_simulator import EconomySimulator, SimulationResult, car_income, car_speed, upgrade_cost


def quantiles(values: Iterable[float]) -> dict[str, float]:
	array = np.asarray(list(values), dtype=float)
	if array.size == 0:
		return {key: 0.0 for key in ("average", "median", "p10", "p25", "p75", "p90", "variance")}
	return {
		"average": float(np.mean(array)),
		"median": float(np.median(array)),
		"p10": float(np.percentile(array, 10)),
		"p25": float(np.percentile(array, 25)),
		"p75": float(np.percentile(array, 75)),
		"p90": float(np.percentile(array, 90)),
		"variance": float(np.var(array)),
	}


def _milestone_values(results: list[SimulationResult], key: str) -> list[float]:
	return [result.milestones[key] for result in results if key in result.milestones]


def summarize_results(results: list[SimulationResult]) -> dict[str, Any]:
	if not results:
		return {}
	return {
		"runs": len(results),
		"player_type": results[0].player_type,
		"behavior": results[0].behavior,
		"duration": results[0].duration,
		"final_cash": quantiles(result.final_cash for result in results),
		"total_income": quantiles(result.total_income for result in results),
		"total_expenses": quantiles(result.total_expenses for result in results),
		"rebirths": quantiles(result.rebirths for result in results),
		"max_car_tier": quantiles(result.max_car_tier for result in results),
		"runner_count": quantiles(result.runner_count for result in results),
		"merges": quantiles(result.merges for result in results),
		"crates_opened": quantiles(result.crates_opened for result in results),
		"income_rate": quantiles(result.income_rate for result in results),
		"longest_progress_gap": quantiles(result.longest_progress_gap for result in results),
		"milestones": {
			key: quantiles(_milestone_values(results, key))
			for key in sorted({key for result in results for key in result.milestones})
		},
	}


def combine_cohort_summaries(summaries: dict[str, dict[str, Any]]) -> dict[str, Any]:
	return {
		name: summary
		for name, summary in summaries.items()
	}


def route_diagnostics(results: list[SimulationResult], config: EconomyConfig) -> list[dict[str, Any]]:
	rows = []
	for route_id, route in config.routes.items():
		seconds = sum(result.route_seconds.get(route_id, 0) for result in results)
		income = sum(result.route_income.get(route_id, 0) for result in results)
		average_length = float(np.mean(route.lane_lengths))
		rows.append({
			"route_id": route_id,
			"name": route.name,
			"cash_multiplier": route.cash_multiplier,
			"cash_gate_cap": route.cash_gate_cap,
			"gate_cap": route.gate_cap,
			"average_path_length": average_length,
			"selected_fraction": seconds / max(sum(result.duration for result in results), 1),
			"income_per_active_second": income / max(seconds, 1e-9),
			"income_per_hour": income / max(seconds, 1e-9) * 3600,
		})
	return rows


def car_diagnostics(config: EconomyConfig, max_tier: int = 40) -> list[dict[str, Any]]:
	rows = []
	for tier in range(1, max_tier + 1):
		rows.append({
			"tier": tier,
			"income_per_gate": car_income(tier),
			"speed": car_speed(tier),
			"two_car_income": 2 * car_income(tier) * car_speed(tier),
			"merged_income": car_income(tier + 1) * car_speed(tier + 1),
			"merge_throughput_ratio": car_income(tier + 1) * car_speed(tier + 1) / max(2 * car_income(tier) * car_speed(tier), 1),
			"base_equivalent_cars": 2 ** (tier - 1),
		})
	return rows


def upgrade_diagnostics(config: EconomyConfig) -> list[dict[str, Any]]:
	rows = []
	for upgrade, cap in (("gates", 25), ("runner_speed", 10), ("cash_bonus", 10)):
		for level in range(1, cap + 1):
			rows.append({
				"upgrade": upgrade,
				"level": level,
				"cost": upgrade_cost(upgrade, level, config.scales.upgrade_costs),
				"effect": (1 + level * 0.1) if upgrade != "gates" else level,
				"payback_unitless": "rate-dependent",
			})
	return rows


def milestone_speed_comparison(
	summaries: dict[tuple[PlayerType, BehaviorType], dict[str, Any]],
	free_behavior: BehaviorType = BehaviorType.AVERAGE,
	paid_behavior: BehaviorType = BehaviorType.AVERAGE,
) -> list[dict[str, Any]]:
	free = summaries.get((PlayerType.FREE, free_behavior), {})
	rows = []
	for player_type in PlayerType:
		paid = summaries.get((player_type, paid_behavior), {})
		for milestone, stats in paid.get("milestones", {}).items():
			free_stats = free.get("milestones", {}).get(milestone)
			if not free_stats or stats["median"] <= 0:
				continue
			rows.append({
				"player_type": player_type.value,
				"milestone": milestone,
				"free_median_seconds": free_stats["median"],
				"paid_median_seconds": stats["median"],
				"speed_multiplier": free_stats["median"] / stats["median"],
			})
	return rows


def pay_to_win_score(
	free_summary: dict[str, Any],
	paid_summary: dict[str, Any],
	config: EconomyConfig,
) -> dict[str, float]:
	def ratio(field: str) -> float:
		free = max(free_summary.get(field, {}).get("median", 0.0), 1e-9)
		paid = paid_summary.get(field, {}).get("median", 0.0)
		return max(0.0, paid / free)

	progression = ratio("max_car_tier")
	income = ratio("total_income")
	route = ratio("rebirths")
	resource = ratio("crates_opened")
	paid_endgame = paid_summary.get("milestones", {}).get("campaign_end", {}).get("median", config.targets.endgame_seconds)
	free_endgame = free_summary.get("milestones", {}).get("campaign_end", {}).get("median", config.targets.endgame_seconds)
	time_pressure = max(1.0, free_endgame / max(paid_endgame, 1.0))
	# Compare ratios in log space so one runaway currency value cannot erase all
	# information from progression, route, resource, and completion metrics.
	ratios = np.maximum([progression, income, route, resource, time_pressure], 1.0)
	log_advantage = np.average(np.log2(ratios), weights=[0.25, 0.25, 0.15, 0.10, 0.25])
	advantage = 2**log_advantage
	return {
		"score": float(max(0.0, min(100.0, math.log2(max(advantage, 1.0)) / math.log2(4.0) * 100))),
		"progression_ratio": progression,
		"income_ratio": income,
		"route_ratio": route,
		"resource_ratio": resource,
		"endgame_time_ratio": time_pressure,
		"target_advantage": config.targets.paid_advantage,
	}


def overall_balance_score(
	config: EconomyConfig,
	free_summary: dict[str, Any],
	paid_summary: dict[str, Any],
	all_results: list[SimulationResult],
) -> dict[str, float]:
	p2w = pay_to_win_score(free_summary, paid_summary, config)
	advantage_error = abs(math.log(max(p2w["endgame_time_ratio"], 1e-9) / config.targets.paid_advantage))
	free_endgame = free_summary.get("milestones", {}).get("campaign_end", {}).get("median", config.targets.endgame_seconds * 2)
	endgame_penalty = math.exp(-abs(math.log(max(free_endgame, 1.0) / config.targets.endgame_seconds)) * 1.5)
	idle = free_summary.get("longest_progress_gap", {}).get("median", config.targets.max_idle_milestone_seconds * 2)
	idle_score = math.exp(-max(0.0, idle - config.targets.soft_idle_milestone_seconds) / config.targets.max_idle_milestone_seconds)
	route_counts = Counter(result.selected_route for result in all_results)
	route_diversity = min(1.0, len(route_counts) / len(config.routes))
	components = {
		"free_viability": endgame_penalty,
		"paid_advantage_target": math.exp(-advantage_error * 2),
		"activity_pacing": idle_score,
		"route_choice": route_diversity,
		"pay_to_win_pressure": max(0.0, 1 - p2w["score"] / 100),
	}
	return {**components, "score": float(np.mean(list(components.values())) * 100)}


def sensitivity_analysis(
	config: EconomyConfig,
	player_type: PlayerType,
	behavior: BehaviorType,
	duration: float,
	runs: int,
	seed: int,
) -> list[dict[str, Any]]:
	simulator = EconomySimulator(config)
	baseline_results = [simulator.simulate(player_type, behavior, duration, seed + index + 1) for index in range(runs)]
	base_wealth = max(float(np.mean([result.final_cash + result.total_expenses for result in baseline_results])), 1.0)
	rows = []
	for parameter, values in {
		"route_rewards": (0.9, 1.1),
		"car_income": (0.9, 1.1),
		"upgrade_costs": (0.9, 1.1),
		"paid_boosts": (0.9, 1.1),
	}.items():
		for value in values:
			changed = config.with_scales(**{parameter: value})
			results = [EconomySimulator(changed).simulate(player_type, behavior, duration, seed + index + 1) for index in range(runs)]
			wealth = float(np.mean([result.final_cash + result.total_expenses for result in results]))
			rows.append({
				"parameter": parameter,
				"value": value,
				"wealth_change_fraction": wealth / base_wealth - 1,
				"mean_wealth": wealth,
			})
	return rows


def write_json(path: Path, value: Any) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(json.dumps(value, indent=2, default=str), encoding="utf-8")
