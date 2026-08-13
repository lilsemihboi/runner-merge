"""Source-derived configuration for the Merge Cars economy simulator.

This module is deliberately independent from the Luau runtime. Scale factors are
simulation overlays used to evaluate recommendations; they never write to Studio
or modify game source.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace
from enum import Enum
from typing import Mapping


class PlayerType(str, Enum):
	FREE = "free"
	LIGHT = "light_spender"
	MEDIUM = "medium_spender"
	HEAVY = "heavy_premium"


class BehaviorType(str, Enum):
	CASUAL = "casual"
	AVERAGE = "average"
	OPTIMIZED = "optimized"
	HIGHLY_OPTIMIZED = "highly_optimized"


@dataclass(frozen=True)
class RouteConfig:
	id: int
	name: str
	rebirth_requirement: int
	cash_gate_cap: int
	gate_cap: int
	cash_multiplier: float
	lane_lengths: tuple[float, ...]
	gate_distances: tuple[tuple[float, ...], ...]


@dataclass(frozen=True)
class CrateConfig:
	id: int
	name: str
	laps_required: int
	queue_weight: float
	loot: Mapping[int, float]


@dataclass(frozen=True)
class BehaviorConfig:
	decision_efficiency: float
	route_efficiency: float
	merge_probability: float
	action_probability: float
	rebirth_patience: float
	decision_delay_seconds: tuple[float, float]


@dataclass(frozen=True)
class SpenderConfig:
	starter_pack: bool = False
	car_bundle: bool = False
	vip: bool = False
	double_cash: bool = False
	double_speed: bool = False
	exclusive_car: bool = False
	paid_crates: tuple[int, ...] = ()
	extra_gates: int = 0
	initial_skip_rebirths: int = 0
	initial_cash_packs: tuple[float, ...] = ()


@dataclass(frozen=True)
class BalanceTargets:
	route_unlock_seconds: float = 40 * 60
	endgame_seconds: float = 7 * 24 * 60 * 60
	paid_advantage: float = 1.25
	max_idle_milestone_seconds: float = 30 * 60
	soft_idle_milestone_seconds: float = 10 * 60
	max_free_paid_advantage: float = 2.0


@dataclass(frozen=True)
class EconomyScales:
	route_rewards: float = 1.0
	car_income: float = 1.0
	upgrade_costs: float = 1.0
	merge_costs: float = 1.0
	paid_boosts: float = 1.0
	runner_costs: float = 1.0
	runner_growth: float = 1.06
	rebirth_costs: float = 1.0
	rebirth_growth: float = 1.25
	trail_multipliers: float = 1.0
	exclusive_car_income: float = 1.0
	route_rebirth_requirements: tuple[int, ...] = (0, 1, 2, 3, 4, 5, 6)
	route_multipliers: tuple[float, ...] = (1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)


@dataclass(frozen=True)
class EconomyConfig:
	routes: Mapping[int, RouteConfig]
	trails: Mapping[int, float]
	crates: Mapping[int, CrateConfig]
	behaviors: Mapping[BehaviorType, BehaviorConfig]
	spenders: Mapping[PlayerType, SpenderConfig]
	targets: BalanceTargets = BalanceTargets()
	scales: EconomyScales = EconomyScales()
	friend_count: int = 0
	group_reward: bool = False
	seed: int = 20260813

	def with_scales(self, **changes: float | tuple[float, ...]) -> "EconomyConfig":
		return replace(self, scales=replace(self.scales, **changes))


# Extracted read-only from ReplicatedStorage.Assets.Runways in Studio using the
# exact PathData Catmull-Rom sampler (12 samples per segment), 2026-08-13.
ROUTES: dict[int, RouteConfig] = {
	1: RouteConfig(1, "Route 1", 0, 8, 10, 1.00, (189.292, 170.857), (
		(101.704, 3.606, 42.577, 141.351, 161.252, 62.414, 22.829, 82.499, 121.217, 173.666),
		(92.779, 2.894, 38.799, 128.020, 144.091, 55.915, 22.040, 73.568, 111.712, 154.566),
	)),
	2: RouteConfig(2, "Route 2", 1, 10, 12, 1.25, (162.139, 139.888), (
		(79.082, 158.194, 51.460, 106.196, 23.160, 134.687, 64.630, 93.099, 8.292, 149.621, 38.019, 119.981),
		(65.675, 134.049, 41.579, 89.769, 18.279, 112.708, 54.111, 77.453, 7.262, 123.760, 29.401, 101.848),
	)),
	3: RouteConfig(3, "Route 3", 2, 12, 14, 1.50, (158.287, 140.910), (
		(55.199, 132.270, 98.287, 21.036, 77.656, 29.527, 111.011, 154.754, 88.324, 8.218, 65.157, 44.083, 121.294, 144.959),
		(25.642, 96.643, 66.822, 135.722, 45.545, 6.477, 74.667, 117.083, 56.255, 126.586, 37.244, 15.373, 86.429, 105.489),
	)),
	4: RouteConfig(4, "Route 4", 3, 14, 16, 2.09, (211.781, 211.585), (
		(35.869, 75.696, 170.575, 141.086, 3.002, 104.038, 182.375, 131.740, 24.096, 85.021, 13.869, 94.568, 193.361, 122.352, 204.094, 113.640),
		(29.080, 68.970, 177.406, 147.830, 2.186, 103.456, 187.356, 137.023, 19.432, 80.310, 11.054, 91.959, 196.245, 125.734, 205.069, 115.113),
	)),
	5: RouteConfig(5, "Route 5", 4, 16, 18, 3.62, (373.118, 353.960), (
		(167.920, 367.360, 183.908, 351.960, 214.630, 337.400, 140.363, 17.289, 233.360, 309.887, 114.059, 40.017, 251.111, 288.745, 270.146, 56.856, 95.196, 75.477),
		(162.593, 352.538, 178.609, 337.133, 204.708, 322.790, 137.718, 20.404, 225.522, 301.941, 118.269, 40.480, 245.218, 283.230, 264.334, 60.751, 98.850, 79.028),
	)),
	6: RouteConfig(6, "Route 6", 5, 18, 20, 3.80, (373.833, 373.558), (
		(204.638, 239.984, 295.288, 333.321, 371.365, 34.170, 70.307, 104.687, 144.258, 339.712, 222.767, 258.394, 278.407, 315.184, 352.569, 15.962, 52.008, 90.202, 118.950, 168.683),
		(195.135, 230.437, 288.789, 334.133, 371.765, 30.810, 61.425, 90.328, 134.675, 177.315, 213.248, 248.846, 268.907, 312.916, 353.483, 15.453, 46.174, 81.348, 109.345, 159.972),
	)),
	7: RouteConfig(7, "Route 7", 6, 25, 27, 3.82, (463.625, 444.362), (
		(225.025, 2.238, 244.032, 449.363, 207.524, 21.302, 264.500, 431.821, 184.728, 38.572, 279.713, 406.981, 54.995, 166.148, 295.541, 390.392, 310.639, 343.076, 326.989, 359.620, 374.785, 118.465, 85.840, 70.615, 134.709, 149.792, 102.216),
		(216.958, 3.817, 235.959, 431.678, 199.457, 22.495, 252.266, 414.213, 182.716, 39.259, 270.940, 397.826, 55.838, 166.978, 286.777, 381.592, 301.858, 334.239, 318.108, 350.756, 365.987, 119.289, 86.593, 71.457, 135.556, 150.645, 103.144),
	)),
}

TRAILS = {
	1: 1.10, 2: 1.18, 3: 1.25, 4: 1.30, 5: 1.50, 6: 1.70,
	7: 1.90, 8: 2.20, 9: 2.40, 10: 2.60, 11: 2.80, 12: 3.50,
	13: 4.30, 14: 5.25, 15: 6.50, 16: 8.00, 17: 9.99,
}

CRATES = {
	1: CrateConfig(1, "Wood Crate", 5, 30, {1: 28, 2: 24, 3: 19, 5: 12, 6: 9, 8: 6, 12: 1.4, 14: 0.45, 16: 0.15}),
	2: CrateConfig(2, "Iron Crate", 10, 35, {1: 25, 2: 21, 3: 17, 5: 14, 6: 11, 8: 5.5, 9: 3.5, 12: 2, 14: 0.7, 16: 0.3}),
	3: CrateConfig(3, "Golden Crate", 25, 15, {1: 17, 2: 15, 3: 13, 4: 10, 5: 11, 6: 9, 7: 7, 8: 5, 9: 4, 10: 3, 12: 2.5, 13: 1.5, 14: 1, 15: 0.5, 16: 0.5}),
	4: CrateConfig(4, "Forest Crate", 50, 12.5, {1: 14, 2: 13, 3: 11, 4: 9, 5: 11, 6: 10, 7: 8, 8: 5, 9: 4, 10: 3.5, 11: 2.5, 12: 3.5, 13: 2.5, 14: 1.4, 15: 0.8, 16: 0.8}),
	5: CrateConfig(5, "Lucky Crate", 75, 5, {1: 12, 2: 11, 3: 9, 4: 8, 5: 11, 6: 10, 7: 9, 8: 5.5, 9: 5, 10: 4, 11: 3.5, 12: 4.5, 13: 3, 14: 2, 15: 1.3, 16: 1, 17: 0.2}),
	6: CrateConfig(6, "Saturn Crate", 100, 2, {1: 10, 2: 9, 3: 8, 4: 7, 5: 11, 6: 10, 7: 9, 8: 6, 9: 5.5, 10: 4.5, 11: 4, 12: 6, 13: 4, 14: 2.5, 15: 1.8, 16: 1.3, 17: 0.4}),
	7: CrateConfig(7, "Star Crate", 200, 0.25, {1: 8, 2: 8, 3: 7, 4: 6, 5: 11, 6: 10, 7: 9, 8: 6.5, 9: 6, 10: 5, 11: 4.5, 12: 6.5, 13: 5, 14: 3, 15: 2.3, 16: 1.6, 17: 0.6}),
	8: CrateConfig(8, "Grass Crate", 450, 0.15, {1: 7, 2: 7, 3: 6, 4: 5, 5: 10.5, 6: 9.5, 7: 9, 8: 7, 9: 6.5, 10: 5.5, 11: 5, 12: 7.5, 13: 5.5, 14: 3.6, 15: 2.8, 16: 1.8, 17: 0.8}),
	9: CrateConfig(9, "Void Crate", 500, 0.1, {1: 6, 2: 6, 3: 5, 4: 5, 5: 10, 6: 9, 7: 9, 8: 7, 9: 6.5, 10: 6, 11: 5.5, 12: 8, 13: 6.5, 14: 4.2, 15: 3.3, 16: 2, 17: 1}),
	10: CrateConfig(10, "Spike Crate", 200, 0, {8: 13, 9: 12, 10: 11, 11: 10, 12: 17, 13: 13, 14: 9, 15: 7, 16: 5.5, 17: 2.5}),
	11: CrateConfig(11, "Magma Crate", 200, 0, {8: 10, 9: 9.5, 10: 8.5, 11: 8, 12: 18.5, 13: 14.5, 14: 11, 15: 9, 16: 7, 17: 4}),
	12: CrateConfig(12, "Robux Crate", 200, 0, {12: 27, 13: 23, 14: 18, 15: 15, 16: 10, 17: 7}),
}

BEHAVIORS = {
	BehaviorType.CASUAL: BehaviorConfig(0.45, 0.45, 0.55, 0.62, 0.55, (20, 180)),
	BehaviorType.AVERAGE: BehaviorConfig(0.68, 0.72, 0.78, 0.80, 0.72, (8, 60)),
	BehaviorType.OPTIMIZED: BehaviorConfig(0.88, 0.92, 0.95, 0.94, 0.90, (2, 20)),
	BehaviorType.HIGHLY_OPTIMIZED: BehaviorConfig(0.98, 0.995, 1.0, 0.995, 0.98, (0.5, 5)),
}

# Entitlement presets are assumptions, kept configurable and reported as such.
SPENDERS = {
	PlayerType.FREE: SpenderConfig(),
	PlayerType.LIGHT: SpenderConfig(starter_pack=True),
	PlayerType.MEDIUM: SpenderConfig(starter_pack=True, vip=True, double_cash=True, paid_crates=(10,)),
	PlayerType.HEAVY: SpenderConfig(
		starter_pack=True, car_bundle=True, vip=True, double_cash=True,
		double_speed=True, exclusive_car=True, paid_crates=(12, 12, 12), extra_gates=2,
	),
}

HORIZONS_SECONDS = (5 * 60, 15 * 60, 30 * 60, 60 * 60, 2 * 60 * 60, 5 * 60 * 60, 10 * 60 * 60, 24 * 60 * 60, 7 * 24 * 60 * 60)
MONEY_MILESTONES = (1_000, 10_000, 100_000, 1_000_000, 100_000_000, 1_000_000_000)
PAID_ADVANTAGE_TARGETS = (1.10, 1.15, 1.20, 1.25, 1.30, 1.40, 1.50, 1.75, 2.00)


def default_config(seed: int = 20260813) -> EconomyConfig:
	return EconomyConfig(
		ROUTES,
		TRAILS,
		CRATES,
		BEHAVIORS,
		SPENDERS,
		scales=EconomyScales(
			paid_boosts=1.0,
			rebirth_growth=1.25,
			exclusive_car_income=1.0,
			route_rebirth_requirements=(0, 1, 2, 3, 4, 5, 6),
		),
		seed=seed,
	)
