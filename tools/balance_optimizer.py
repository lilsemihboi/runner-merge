"""Search simulation-only economy overlays for a healthier D7 progression."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from tools.balance_analysis import overall_balance_score, pay_to_win_score
from tools.economy_config import EconomyConfig, EconomyScales, PlayerType, BehaviorType
from tools.economy_simulator import EconomySimulator, ProgressBar, SimulationResult


@dataclass(frozen=True)
class Candidate:
	scales: EconomyScales
	score: float
	free_endgame_median: float
	paid_endgame_median: float
	paid_advantage: float
	free_completion_rate: float
	paid_completion_rate: float


def _median_milestone(results: list[SimulationResult], key: str, fallback: float) -> float:
	values = [result.milestones[key] for result in results if key in result.milestones]
	return float(np.median(values)) if values else fallback


def evaluate_candidate(
	config: EconomyConfig,
	scales: EconomyScales,
	runs: int,
	duration: float,
	seed: int,
) -> Candidate:
	changed = config.with_scales(**scales.__dict__)
	simulator = EconomySimulator(changed)
	free = [simulator.simulate(PlayerType.FREE, BehaviorType.AVERAGE, duration, seed + index) for index in range(runs)]
	paid = [simulator.simulate(PlayerType.HEAVY, BehaviorType.AVERAGE, duration, seed + runs + index) for index in range(runs)]
	free_completion_rate = sum("campaign_end" in result.milestones for result in free) / len(free)
	paid_completion_rate = sum("campaign_end" in result.milestones for result in paid) / len(paid)
	free_summary = {
		"total_income": {"median": float(np.median([result.total_income for result in free]))},
		"max_car_tier": {"median": float(np.median([result.max_car_tier for result in free]))},
		"rebirths": {"median": float(np.median([result.rebirths for result in free]))},
		"crates_opened": {"median": float(np.median([result.crates_opened for result in free]))},
		"milestones": {"campaign_end": {"median": _median_milestone(free, "campaign_end", duration)}},
		"longest_progress_gap": {"median": float(np.median([result.longest_progress_gap for result in free]))},
	}
	paid_summary = {
		"total_income": {"median": float(np.median([result.total_income for result in paid]))},
		"max_car_tier": {"median": float(np.median([result.max_car_tier for result in paid]))},
		"rebirths": {"median": float(np.median([result.rebirths for result in paid]))},
		"crates_opened": {"median": float(np.median([result.crates_opened for result in paid]))},
		"milestones": {"campaign_end": {"median": _median_milestone(paid, "campaign_end", duration)}},
	}
	score = overall_balance_score(changed, free_summary, paid_summary, free + paid)
	p2w = pay_to_win_score(free_summary, paid_summary, changed)
	return Candidate(
		scales,
		score["score"],
		free_summary["milestones"]["campaign_end"]["median"],
		paid_summary["milestones"]["campaign_end"]["median"],
		p2w["endgame_time_ratio"],
		free_completion_rate,
		paid_completion_rate,
	)


def search(
	config: EconomyConfig,
	runs: int = 100,
	duration: float = 7 * 24 * 60 * 60,
	seed: int | None = None,
	candidates: int = 80,
	progress: bool = False,
) -> list[Candidate]:
	rng = np.random.default_rng(config.seed if seed is None else seed)
	values = np.array([0.8, 0.9, 1.0, 1.1, 1.2])
	results = []
	progress_bar = ProgressBar(candidates, "parameter search") if progress else None
	for index in range(candidates):
		scales = EconomyScales(
			route_rewards=float(rng.choice(values)),
			car_income=float(rng.choice(values)),
			upgrade_costs=float(rng.choice(values)),
			merge_costs=1.0,
			paid_boosts=float(rng.choice((0.04, 0.06, 0.08, 0.10, 0.12, 0.15))),
			runner_costs=1.0,
			rebirth_costs=1.0,
			rebirth_growth=float(rng.choice((1.370, 1.375, 1.380, 1.385, 1.390))),
			trail_multipliers=1.0,
			exclusive_car_income=float(rng.choice((0.003, 0.005, 0.0075, 0.010))),
			route_rebirth_requirements=(0, 10, 24, 38, 52, 66, 78),
			route_multipliers=(1.0,) * 7,
		)
		results.append(evaluate_candidate(config, scales, runs, duration, int(rng.integers(0, 2**31 - 1))))
		if progress_bar:
			progress_bar.update(index + 1)
	if progress_bar:
		progress_bar.finish()
	return sorted(results, key=lambda candidate: candidate.score, reverse=True)
