export type ConfigurationSchema = {
	PLOT_COUNT: number,
	RUNNER_BOUNDS_PADDING: number,
	FRIENDS_PER_TICK: number,
}

return {
	PLOT_COUNT = 1,
	-- extra studs around a plot's runway bounding box that still count as
	-- "inside" for runner replication culling (see RunnerManager)
	RUNNER_BOUNDS_PADDING = 12,
	FRIENDS_PER_TICK = 10,
} :: ConfigurationSchema
