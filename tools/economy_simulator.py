"""Integrated event-driven Monte Carlo simulator for the Merge Cars economy."""

from __future__ import annotations

import math
import os
import sys
import time
from bisect import bisect_left
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Iterable

import numpy as np

from tools.economy_config import (
	BehaviorType,
	EconomyConfig,
	HORIZONS_SECONDS,
	MONEY_MILESTONES,
	PlayerType,
)


EXCLUSIVE_CAR_ID = 1001
EXCLUSIVE_CAR_INCOME = 150_000
EXCLUSIVE_CAR_SPEED = 83
MAX_UPGRADE_LEVEL = 10
AUTHORED_MAX_CAR_TIER = 40
ENDGAME_ROUTE = 7
ENDGAME_CAR_TIER = 40


def round_luau(value: float) -> int:
	"""Match math.round for the positive values used by this economy."""
	return math.floor(value + 0.5)


def round_to_tens(value: float) -> int:
	return math.floor((value + 5) / 10) * 10


def round_to_fives(value: float) -> int:
	return math.floor((value + 2.5) / 5) * 5


@lru_cache(maxsize=None)
def _base_regular_car_income(level: int) -> int:
	level = max(1, math.floor(level))
	return 10 * (level**3)


def regular_car_income(level: int, scale: float = 1.0) -> int:
	return max(1, round_luau(_base_regular_car_income(level) * scale))


def car_income(car_id: int, scale: float = 1.0, exclusive_scale: float = 1.0) -> int:
	if car_id == EXCLUSIVE_CAR_ID:
		return max(1, round_luau(EXCLUSIVE_CAR_INCOME * scale * exclusive_scale))
	return regular_car_income(car_id, scale)


@lru_cache(maxsize=None)
def _base_car_speed(car_id: int) -> int:
	if car_id == EXCLUSIVE_CAR_ID:
		return EXCLUSIVE_CAR_SPEED
	level = max(1, math.floor(car_id))
	return 8 + math.floor(((level - 1) ** 1.35) * 0.8)


def car_speed(car_id: int, speed_upgrade: int = 0) -> float:
	return _base_car_speed(car_id) * (1 + max(0, math.floor(speed_upgrade)) * 0.1)


@lru_cache(maxsize=None)
def _base_runner_price(purchase_number: int, growth: float = 1.08) -> int:
	prices = (0, 1, 3, 10, 15, 25, 35, 50, 70, 95, 130, 175, 235, 315, 420)
	purchase_number = max(1, math.floor(purchase_number))
	if purchase_number <= len(prices):
		return prices[purchase_number - 1]
	previous = _base_runner_price(purchase_number - 1, growth)
	formula = round_to_fives(420 * (growth ** (purchase_number - 15)))
	return max(formula, previous + 5)


def runner_price(purchase_number: int, scale: float = 1.0, growth: float = 1.08) -> int:
	return round_luau(_base_runner_price(purchase_number, growth) * scale)


def upgrade_cost(upgrade: str, next_level: int, scale: float = 1.0) -> int:
	if upgrade == "gates":
		if next_level == 1:
			base = 0
		elif next_level == 2:
			base = 50
		else:
			base = round_to_tens(5000 * (2.5 ** (next_level - 3)))
	elif upgrade == "runner_speed":
		base = round_to_tens(100 * (1.85 ** next_level))
	elif upgrade == "cash_bonus":
		base = round_to_tens(500 * (2.0 ** next_level))
	else:
		raise ValueError(f"Unknown upgrade: {upgrade}")
	return round_luau(base * scale)


def rebirth_cost(next_rebirth: int, scale: float = 1.0, growth: float = 10.0) -> int:
	route_prices = (1_000, 10_000, 100_000, 500_000, 2_000_000, 10_000_000)
	base = route_prices[next_rebirth - 1] if next_rebirth <= len(route_prices) else route_prices[-1] * (growth ** (next_rebirth - len(route_prices)))
	return round_luau(base * scale)


@dataclass
class PlayerState:
	time: float = 0.0
	cash: float = 0.0
	total_income: float = 0.0
	total_expenses: float = 0.0
	runners: list[int] = field(default_factory=list)
	runner_purchases: int = 0
	runner_spawn_level: int = 1
	rebirths: int = 0
	selected_route: int = 1
	gates: int = 0
	runner_speed: int = 0
	cash_bonus: int = 0
	extra_gates: int = 0
	trail_id: int | None = None
	owned_trails: Counter[int] = field(default_factory=Counter)
	crate_id: int = 1
	laps_left: float = 5.0
	merges: int = 0
	crates_opened: int = 0
	route_seconds: Counter[int] = field(default_factory=Counter)
	route_income: Counter[int] = field(default_factory=Counter)
	expenses: Counter[str] = field(default_factory=Counter)
	milestones: dict[str, float] = field(default_factory=dict)
	upgrade_purchases: Counter[str] = field(default_factory=Counter)
	paid_entitlements: set[str] = field(default_factory=set)
	custom_multiplier: float = 1.0
	vip: bool = False
	double_cash: bool = False
	double_speed: bool = False
	max_car_tier: int = 0
	max_income_rate: float = 0.0
	last_progress_time: float = 0.0
	next_route_review: float = 0.0


@dataclass(frozen=True)
class SimulationResult:
	player_type: str
	behavior: str
	duration: float
	final_cash: float
	total_income: float
	total_expenses: float
	rebirths: int
	selected_route: int
	runner_count: int
	max_car_tier: int
	merges: int
	crates_opened: int
	trail_multiplier: float
	gates: int
	runner_speed: int
	cash_bonus: int
	income_rate: float
	milestones: dict[str, float]
	route_seconds: dict[int, float]
	route_income: dict[int, float]
	expenses: dict[str, float]
	history: tuple[dict[str, float], ...]
	longest_progress_gap: float


@dataclass(frozen=True)
class Action:
	kind: str
	cost: float
	benefit: float
	payback: float


class EconomySimulator:
	def __init__(self, config: EconomyConfig):
		self.config = config
		self._crate_rolls: dict[int, tuple[tuple[int, ...], tuple[float, ...], float]] = {}
		for crate_id, crate in config.crates.items():
			trail_ids = tuple(crate.loot)
			cumulative = []
			total = 0.0
			for weight in crate.loot.values():
				total += weight
				cumulative.append(total)
			self._crate_rolls[crate_id] = trail_ids, tuple(cumulative), total
		self._free_crates = tuple(entry for entry in config.crates.values() if entry.queue_weight > 0)
		total = 0.0
		cumulative = []
		for crate in self._free_crates:
			total += crate.queue_weight
			cumulative.append(total)
		self._free_crate_cumulative = tuple(cumulative)
		self._free_crate_total = total

	def simulate(
		self,
		player_type: PlayerType,
		behavior_type: BehaviorType,
		duration: float,
		seed: int,
		history_points: Iterable[float] = HORIZONS_SECONDS,
	) -> SimulationResult:
		rng = np.random.default_rng(seed)
		behavior = self.config.behaviors[behavior_type]
		state = PlayerState()
		self._apply_initial_entitlements(state, player_type, rng)
		self._record_initial_free_actions(state)
		self._update_milestones(state)

		checkpoints = sorted({float(point) for point in history_points if 0 < point <= duration} | {float(duration)})
		history: list[dict[str, float]] = []
		checkpoint_index = 0
		longest_progress_gap = 0.0

		while state.time < duration:
			if state.time >= state.next_route_review:
				self._select_route(state, behavior_type, rng)
				state.next_route_review = state.time + self._route_review_interval(behavior_type)
			acted = self._take_actions(state, behavior_type, rng)
			if acted:
				state.last_progress_time = state.time
				self._update_milestones(state)

			next_checkpoint = checkpoints[checkpoint_index] if checkpoint_index < len(checkpoints) else duration
			delta = self._next_event_delta(state, behavior_type, next_checkpoint, duration)
			if delta <= 1e-8:
				delta = min(1.0, duration - state.time)
			self._advance(state, delta, rng)
			if "campaign_end" not in state.milestones:
				longest_progress_gap = max(longest_progress_gap, state.time - state.last_progress_time)
			self._update_milestones(state)

			while checkpoint_index < len(checkpoints) and state.time >= checkpoints[checkpoint_index] - 1e-6:
				history.append(self._snapshot(state, checkpoints[checkpoint_index]))
				checkpoint_index += 1

		income_rate, _ = self._rates(state)
		return SimulationResult(
			player_type.value,
			behavior_type.value,
			duration,
			state.cash,
			state.total_income,
			state.total_expenses,
			state.rebirths,
			state.selected_route,
			len(state.runners),
			state.max_car_tier,
			state.merges,
			state.crates_opened,
			self._trail_multiplier(state),
			state.gates,
			state.runner_speed,
			state.cash_bonus,
			income_rate,
			dict(state.milestones),
			dict(state.route_seconds),
			dict(state.route_income),
			dict(state.expenses),
			tuple(history),
			longest_progress_gap,
		)

	def _apply_initial_entitlements(self, state: PlayerState, player_type: PlayerType, rng: np.random.Generator) -> None:
		spender = self.config.spenders[player_type]
		paid_scale = self.config.scales.paid_boosts
		if self.config.group_reward:
			self._give_cash(state, 15_000)
			self._give_runner(state, 4, counts_as_purchase=True)
			state.custom_multiplier += 0.05
		if spender.starter_pack:
			state.paid_entitlements.add("starter_pack")
			self._give_cash(state, 50_000)
			self._give_runner(state, 6, counts_as_purchase=True)
			state.custom_multiplier += 0.2 * paid_scale
		if spender.car_bundle:
			state.paid_entitlements.add("car_bundle")
			for level in (14, 15, 16):
				self._give_runner(state, level, counts_as_purchase=True)
		if spender.exclusive_car:
			state.paid_entitlements.add("exclusive_car")
			self._give_runner(state, EXCLUSIVE_CAR_ID, counts_as_purchase=False)
		state.vip = spender.vip
		state.double_cash = spender.double_cash
		state.double_speed = spender.double_speed
		state.extra_gates = spender.extra_gates
		for _ in range(spender.initial_skip_rebirths):
			self._paid_rebirth(state)
		for percent in spender.initial_cash_packs:
			self._give_cash(state, math.floor(max(state.cash, 10_000) * percent))
		for crate_id in spender.paid_crates:
			self._open_crate(state, crate_id, rng, queue_roll=False)

	def _record_initial_free_actions(self, state: PlayerState) -> None:
		if state.gates == 0:
			state.gates = 1
			state.upgrade_purchases["gates"] += 1
		if not state.runners:
			self._give_runner(state, state.runner_spawn_level, counts_as_purchase=True)

	def _paid_multiplier(self, base: float) -> float:
		return 1 + (base - 1) * self.config.scales.paid_boosts

	def _trail_multiplier(self, state: PlayerState) -> float:
		if state.trail_id is None:
			return 1.0
		base = self.config.trails[state.trail_id]
		return 1 + (base - 1) * self.config.scales.trail_multipliers

	def _active_gates(self, state: PlayerState, route_id: int | None = None) -> int:
		route = self.config.routes[route_id or state.selected_route]
		cash_gates = min(state.gates, route.cash_gate_cap)
		extra = min(state.extra_gates, route.gate_cap - route.cash_gate_cap) if cash_gates >= route.cash_gate_cap else 0
		return cash_gates + extra

	def _route_requirement(self, route_id: int) -> int:
		return self.config.scales.route_rebirth_requirements[route_id - 1]

	def _route_factor(self, route_id: int) -> float:
		route = self.config.routes[route_id]
		base = 1 + (route.cash_multiplier - 1) * self.config.scales.route_rewards
		return base * self.config.scales.route_multipliers[route_id - 1]

	def _rates(self, state: PlayerState, route_id: int | None = None) -> tuple[float, float]:
		route_id = route_id or state.selected_route
		route = self.config.routes[route_id]
		active_gates = self._active_gates(state, route_id)
		if active_gates <= 0 or not state.runners:
			return 0.0, 0.0

		cash_factor = (
			(1 + 0.1 * state.cash_bonus)
			* (1 + self.config.friend_count * 0.1)
			* (1 + state.rebirths * 0.05)
			* state.custom_multiplier
			* (self._paid_multiplier(1.5) if state.vip else 1.0)
			* (self._paid_multiplier(2.0) if state.double_cash else 1.0)
			* self._trail_multiplier(state)
			* self._route_factor(route_id)
		)
		speed_pass = self._paid_multiplier(2.0) if state.double_speed else 1.0
		cash_rate = 0.0
		lap_rate = 0.0
		lane_count = len(route.lane_lengths)
		for index, runner in enumerate(state.runners, start=1):
			# Runtime lane hashing is effectively balanced across two lanes over a roster.
			lane = (index - 1) % lane_count
			length = route.lane_lengths[lane]
			speed = car_speed(runner, state.runner_speed) * speed_pass
			per_gate = max(1, round_luau(car_income(runner, self.config.scales.car_income, self.config.scales.exclusive_car_income) * cash_factor))
			cash_rate += per_gate * active_gates * speed / length
			lap_rate += speed / length
		return cash_rate, lap_rate

	def _select_route(self, state: PlayerState, behavior_type: BehaviorType, rng: np.random.Generator) -> None:
		unlocked = [route.id for route in self.config.routes.values() if self._route_requirement(route.id) <= state.rebirths]
		if len(unlocked) == 1:
			state.selected_route = unlocked[0]
			return
		rates = np.array([self._rates(state, route_id)[0] for route_id in unlocked], dtype=float)
		behavior = self.config.behaviors[behavior_type]
		if behavior.route_efficiency >= 0.99 or rates.max() <= 0:
			state.selected_route = unlocked[int(np.argmax(rates))]
			return
		normalized = rates / max(rates.max(), 1e-9)
		weights = np.power(np.maximum(normalized, 0.02), 1 + 8 * behavior.route_efficiency)
		state.selected_route = int(rng.choice(unlocked, p=weights / weights.sum()))

	def _route_review_interval(self, behavior_type: BehaviorType) -> float:
		return {
			BehaviorType.CASUAL: 30 * 60,
			BehaviorType.AVERAGE: 15 * 60,
			BehaviorType.OPTIMIZED: 5 * 60,
			BehaviorType.HIGHLY_OPTIMIZED: 60,
		}[behavior_type]

	def _take_actions(self, state: PlayerState, behavior_type: BehaviorType, rng: np.random.Generator) -> bool:
		behavior = self.config.behaviors[behavior_type]
		acted = False
		for _ in range(32):
			if len(state.runners) >= 20:
				acted = self._merge_all(state) or acted
			if self._has_merge(state) and rng.random() <= behavior.merge_probability:
				if self._merge_value_ratio(state) > (1.15 - behavior.decision_efficiency * 0.2):
					acted = self._merge_all(state) or acted

			next_rebirth = state.rebirths + 1
			cost = rebirth_cost(next_rebirth, self.config.scales.rebirth_costs, self.config.scales.rebirth_growth)
			rebirth_threshold = cost * (1 + (1 - behavior.rebirth_patience) * 0.6)
			if state.cash >= rebirth_threshold and rng.random() <= behavior.action_probability:
				self._normal_rebirth(state, cost)
				acted = True
				continue

			actions = self._available_actions(state)
			affordable = [action for action in actions if action.cost <= state.cash + 1e-8]
			if not affordable or rng.random() > behavior.action_probability:
				break
			affordable.sort(key=lambda action: (action.payback, -action.benefit))
			if behavior.decision_efficiency >= 0.97:
				choice = affordable[0]
			else:
				candidate_count = min(len(affordable), 1 + round((1 - behavior.decision_efficiency) * 4))
				choice = affordable[int(rng.integers(0, candidate_count))]
			self._execute_action(state, choice)
			acted = True
		return acted

	def _available_actions(self, state: PlayerState) -> list[Action]:
		current_rate, _ = self._rates(state)
		actions: list[Action] = []
		route = self.config.routes[state.selected_route]

		if state.gates < route.cash_gate_cap:
			cost = upgrade_cost("gates", state.gates + 1, self.config.scales.upgrade_costs)
			new_gates = state.gates + 1
			old_gates = max(1, self._active_gates(state))
			benefit = current_rate * (new_gates / old_gates - 1)
			actions.append(Action("gates", cost, benefit, cost / max(benefit, 1e-9)))

		if state.runner_speed < MAX_UPGRADE_LEVEL:
			cost = upgrade_cost("runner_speed", state.runner_speed + 1, self.config.scales.upgrade_costs)
			benefit = current_rate * (0.1 / (1 + 0.1 * state.runner_speed))
			actions.append(Action("runner_speed", cost, benefit, cost / max(benefit, 1e-9)))

		if state.cash_bonus < MAX_UPGRADE_LEVEL:
			cost = upgrade_cost("cash_bonus", state.cash_bonus + 1, self.config.scales.upgrade_costs)
			benefit = current_rate * (0.1 / (1 + 0.1 * state.cash_bonus))
			actions.append(Action("cash_bonus", cost, benefit, cost / max(benefit, 1e-9)))

		cost = runner_price(state.runner_purchases + 1, self.config.scales.runner_costs, self.config.scales.runner_growth)
		temporary = PlayerState(**{**state.__dict__, "runners": state.runners + [state.runner_spawn_level]})
		benefit = max(0.0, self._rates(temporary)[0] - current_rate)
		actions.append(Action("runner", cost, benefit, cost / max(benefit, 1e-9)))
		return actions

	def _execute_action(self, state: PlayerState, action: Action) -> None:
		self._spend(state, action.cost, action.kind)
		if action.kind == "runner":
			self._give_runner(state, state.runner_spawn_level, counts_as_purchase=True)
		elif action.kind == "gates":
			state.gates += 1
			state.upgrade_purchases["gates"] += 1
			state.milestones.setdefault(f"upgrade_gates_{state.gates}", state.time)
		elif action.kind == "runner_speed":
			state.runner_speed += 1
			state.upgrade_purchases["runner_speed"] += 1
			state.milestones.setdefault(f"upgrade_runner_speed_{state.runner_speed}", state.time)
		elif action.kind == "cash_bonus":
			state.cash_bonus += 1
			state.upgrade_purchases["cash_bonus"] += 1
			state.milestones.setdefault(f"upgrade_cash_bonus_{state.cash_bonus}", state.time)

	def _next_event_delta(self, state: PlayerState, behavior_type: BehaviorType, checkpoint: float, duration: float) -> float:
		behavior = self.config.behaviors[behavior_type]
		cash_rate, _ = self._rates(state)
		candidates = [duration - state.time, checkpoint - state.time]
		actions = self._available_actions(state)
		if cash_rate > 0:
			unaffordable_costs = [action.cost for action in actions if action.cost > state.cash]
			next_rebirth = rebirth_cost(state.rebirths + 1, self.config.scales.rebirth_costs, self.config.scales.rebirth_growth)
			unaffordable_costs.append(next_rebirth)
			if unaffordable_costs:
				candidates.append(max(0.1, (min(unaffordable_costs) - state.cash) / cash_rate))
		minimum_delay, _ = behavior.decision_delay_seconds
		return max(minimum_delay, min(value for value in candidates if value > 1e-8))

	def _advance(self, state: PlayerState, delta: float, rng: np.random.Generator) -> None:
		cash_rate, lap_rate = self._rates(state)
		income = cash_rate * delta
		state.cash += income
		state.total_income += income
		state.route_seconds[state.selected_route] += delta
		state.route_income[state.selected_route] += income
		state.max_income_rate = max(state.max_income_rate, cash_rate)
		state.time += delta

		laps = lap_rate * delta
		if state.trail_id == max(self.config.trails, key=self.config.trails.get):
			# Once the best trail is equipped, later crate identities and duplicates do
			# not affect this economy model. Use expected queue lap cost to retain the
			# crate-count/resource metric without thousands of irrelevant rolls.
			expected_laps = sum(crate.laps_required * crate.queue_weight for crate in self._free_crates) / self._free_crate_total
			available_laps = max(0.0, laps - state.laps_left)
			if laps >= state.laps_left:
				completed = 1 + math.floor(available_laps / expected_laps)
				state.crates_opened += completed
				remaining = available_laps % expected_laps
				state.laps_left = expected_laps - remaining
			return
		# Batch crate progress between economic decisions. Each crate still receives
		# an independent roll; only event scheduling is coalesced.
		while laps + 1e-9 >= state.laps_left and state.laps_left > 0:
			laps -= state.laps_left
			self._open_crate(state, state.crate_id, rng, queue_roll=True)
		if state.laps_left > 0:
			state.laps_left = max(0.0, state.laps_left - laps)

	def _open_crate(self, state: PlayerState, crate_id: int, rng: np.random.Generator, queue_roll: bool) -> None:
		trail_ids, cumulative, total = self._crate_rolls[crate_id]
		trail_id = trail_ids[min(bisect_left(cumulative, rng.random() * total), len(trail_ids) - 1)]
		state.owned_trails[trail_id] += 1
		if state.trail_id is None or self.config.trails[trail_id] > self.config.trails[state.trail_id]:
			state.trail_id = trail_id
		state.crates_opened += 1
		state.milestones.setdefault("first_crate", state.time)
		if queue_roll:
			index = min(bisect_left(self._free_crate_cumulative, rng.random() * self._free_crate_total), len(self._free_crates) - 1)
			next_crate = self._free_crates[index]
			state.crate_id = next_crate.id
			state.laps_left = float(next_crate.laps_required)

	def _give_cash(self, state: PlayerState, amount: float) -> None:
		state.cash += amount
		state.total_income += max(0, amount)

	def _spend(self, state: PlayerState, amount: float, category: str) -> None:
		state.cash -= amount
		state.total_expenses += amount
		state.expenses[category] += amount

	def _give_runner(self, state: PlayerState, level: int, counts_as_purchase: bool) -> None:
		state.runners.append(level)
		if counts_as_purchase:
			state.runner_purchases += 1
		if level != EXCLUSIVE_CAR_ID:
			state.max_car_tier = max(state.max_car_tier, level)
			state.milestones.setdefault(f"car_tier_{level}", state.time)

	def _normal_rebirth(self, state: PlayerState, cost: float) -> None:
		# Runtime resets the entire balance, not only the threshold.
		state.total_expenses += state.cash
		state.expenses["rebirth"] += state.cash
		state.cash = 0
		state.gates = 0
		state.runner_speed = 0
		state.cash_bonus = 0
		state.extra_gates = 0
		state.rebirths += 1
		if state.rebirths <= 80 and state.rebirths % 2 == 0:
			state.runner_spawn_level += 1
			state.runners = [max(level, state.runner_spawn_level) if level != EXCLUSIVE_CAR_ID else level for level in state.runners]
			self._merge_all(state)
		state.milestones.setdefault(f"rebirth_{state.rebirths}", state.time)
		self._select_best_unlocked_route(state)
		# The free gate must be repurchased after each reset.
		state.gates = 1
		state.upgrade_purchases["gates"] += 1

	def _paid_rebirth(self, state: PlayerState) -> None:
		state.rebirths += 1
		if state.rebirths <= 80 and state.rebirths % 2 == 0:
			state.runner_spawn_level += 1
		state.milestones.setdefault(f"rebirth_{state.rebirths}", state.time)
		self._select_best_unlocked_route(state)

	def _select_best_unlocked_route(self, state: PlayerState) -> None:
		state.selected_route = max(route.id for route in self.config.routes.values() if self._route_requirement(route.id) <= state.rebirths)
		state.next_route_review = state.time

	def _has_merge(self, state: PlayerState) -> bool:
		counts = Counter(level for level in state.runners if level != EXCLUSIVE_CAR_ID)
		return any(count >= 2 for count in counts.values())

	def _merge_value_ratio(self, state: PlayerState) -> float:
		counts = Counter(level for level in state.runners if level != EXCLUSIVE_CAR_ID)
		ratios = []
		for level, count in counts.items():
			if count >= 2:
				before = 2 * car_income(level) * car_speed(level)
				after = car_income(level + 1) * car_speed(level + 1)
				ratios.append(after / max(before, 1))
		return max(ratios, default=0.0)

	def _merge_all(self, state: PlayerState) -> bool:
		regular = sorted(level for level in state.runners if level != EXCLUSIVE_CAR_ID)
		exclusive = [level for level in state.runners if level == EXCLUSIVE_CAR_ID]
		changed = False
		while True:
			counts = Counter(regular)
			merge_level = next((level for level in sorted(counts) if counts[level] >= 2), None)
			if merge_level is None:
				break
			regular.remove(merge_level)
			regular.remove(merge_level)
			regular.append(merge_level + 1)
			regular.sort()
			state.merges += 1
			state.max_car_tier = max(state.max_car_tier, merge_level + 1)
			state.milestones.setdefault(f"car_tier_{merge_level + 1}", state.time)
			changed = True
		state.runners = regular + exclusive
		return changed

	def _update_milestones(self, state: PlayerState) -> None:
		before = len(state.milestones)
		for amount in MONEY_MILESTONES:
			if state.total_income >= amount:
				state.milestones.setdefault(f"earned_{amount}", state.time)
		for tier in (2, 3, 4, 5, 10, 20, 30, 40):
			if state.max_car_tier >= tier:
				state.milestones.setdefault(f"car_tier_{tier}", state.time)
		if state.rebirths >= self._route_requirement(ENDGAME_ROUTE):
			state.milestones.setdefault("best_route", state.time)
			state.milestones.setdefault("campaign_end", state.time)
		if state.rebirths >= self._route_requirement(ENDGAME_ROUTE) and state.max_car_tier >= ENDGAME_CAR_TIER:
			state.milestones.setdefault("endgame", state.time)
		if len(state.milestones) > before:
			state.last_progress_time = state.time

	def _snapshot(self, state: PlayerState, requested_time: float) -> dict[str, float]:
		income_rate, _ = self._rates(state)
		return {
			"time": requested_time,
			"cash": state.cash,
			"total_income": state.total_income,
			"expenses": state.total_expenses,
			"income_rate": income_rate,
			"rebirths": float(state.rebirths),
			"route": float(state.selected_route),
			"max_car_tier": float(state.max_car_tier),
			"runner_count": float(len(state.runners)),
			"trail_multiplier": self._trail_multiplier(state),
		}


def run_population(
	config: EconomyConfig,
	player_type: PlayerType,
	behavior: BehaviorType,
	duration: float,
	runs: int,
	seed: int | None = None,
	workers: int = 1,
	progress: bool = False,
	label: str = "Simulation",
) -> list[SimulationResult]:
	seed_sequence = np.random.SeedSequence(config.seed if seed is None else seed)
	seeds = [int(child.generate_state(1)[0]) for child in seed_sequence.spawn(runs)]
	progress_bar = ProgressBar(runs, label) if progress else None
	if workers <= 1 or runs < 2:
		results = []
		chunk_size = max(1, min(100, runs // 100 or 1))
		for start in range(0, runs, chunk_size):
			chunk = _run_chunk((config, player_type, behavior, duration, seeds[start : start + chunk_size]))
			results.extend(chunk)
			if progress_bar:
				progress_bar.update(len(results))
		if progress_bar:
			progress_bar.finish()
		return results
	worker_count = min(workers, runs)
	chunk_count = min(runs, max(worker_count * 8, 100))
	chunks = [list(chunk) for chunk in np.array_split(np.asarray(seeds, dtype=np.uint32), chunk_count) if len(chunk)]
	arguments = [(config, player_type, behavior, duration, [int(value) for value in chunk]) for chunk in chunks]
	with ProcessPoolExecutor(max_workers=worker_count) as executor:
		futures = [executor.submit(_run_chunk, argument) for argument in arguments]
		results = []
		for future in as_completed(futures):
			results.extend(future.result())
			if progress_bar:
				progress_bar.update(len(results))
	if progress_bar:
		progress_bar.finish()
	return results


def _run_chunk(arguments: tuple[EconomyConfig, PlayerType, BehaviorType, float, list[int]]) -> list[SimulationResult]:
	config, player_type, behavior, duration, seeds = arguments
	simulator = EconomySimulator(config)
	return [simulator.simulate(player_type, behavior, duration, seed) for seed in seeds]


class ProgressBar:
	"""Small cross-platform progress bar with elapsed time and ETA."""

	def __init__(self, total: int, label: str, width: int = 28):
		self.total = max(1, total)
		self.label = label
		self.width = width
		self.started_at = time.perf_counter()
		self.last_rendered_at = 0.0
		self.completed = 0
		self.update(0, force=True)

	def update(self, completed: int, force: bool = False) -> None:
		now = time.perf_counter()
		self.completed = min(max(0, completed), self.total)
		if not force and self.completed < self.total and now - self.last_rendered_at < 0.2:
			return
		self.last_rendered_at = now
		elapsed = max(0.0, now - self.started_at)
		rate = self.completed / elapsed if elapsed > 0 and self.completed else 0.0
		remaining = self.total - self.completed
		eta = remaining / rate if rate > 0 else math.inf
		fraction = self.completed / self.total
		filled = min(self.width, round(self.width * fraction))
		bar = "#" * filled + "-" * (self.width - filled)
		line = (
			f"\r[{bar}] {fraction:6.2%}  {self.completed:,}/{self.total:,}  "
			f"{rate:,.1f} runs/s  elapsed {_format_duration(elapsed)}  "
			f"ETA {_format_duration(eta)}  {self.label}"
		)
		sys.stdout.write(line)
		sys.stdout.flush()

	def finish(self) -> None:
		if self.completed < self.total:
			self.update(self.total, force=True)
		sys.stdout.write("\n")
		sys.stdout.flush()


def _format_duration(seconds: float) -> str:
	if not math.isfinite(seconds):
		return "--:--"
	seconds = max(0, round(seconds))
	hours, remainder = divmod(seconds, 3600)
	minutes, seconds = divmod(remainder, 60)
	if hours:
		return f"{hours:d}:{minutes:02d}:{seconds:02d}"
	return f"{minutes:02d}:{seconds:02d}"
